import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const FREE_SCAN_LIMIT = 10 // shared with scans — generating a plan costs 1 scan credit

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Verify authentication
    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized. Please sign in.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Check premium status
    const { data: profile } = await supabase
      .from('profiles')
      .select('is_premium')
      .eq('id', user.id)
      .single()

    const isPremium = profile?.is_premium ?? false

    // Check daily usage (shared scan credits)
    const today = new Date().toISOString().split('T')[0]
    if (!isPremium) {
      const { data: usage } = await supabase
        .from('usage')
        .select('scan_count')
        .eq('user_id', user.id)
        .eq('date', today)
        .single()

      const scanCount = usage?.scan_count ?? 0
      if (scanCount >= FREE_SCAN_LIMIT) {
        return new Response(
          JSON.stringify({
            error: `You've used all ${FREE_SCAN_LIMIT} free AI credits for today. Upgrade to Pro for unlimited meal plan generation.`,
            code: 'SCAN_LIMIT_REACHED',
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Parse request
    const { calorieGoal, budgetTier, dietaryPreference, profileContext } = await req.json()
    if (!calorieGoal || !budgetTier) {
      return new Response(JSON.stringify({ error: 'Missing calorieGoal or budgetTier' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Build the prompt (same as AnthropicService.generateMealPlan)
    const budgetLabel = budgetTier === 'r50'
      ? 'under R50 (budget, use Shoprite/Checkers ingredients)'
      : budgetTier === 'r100'
        ? 'around R100 (mid-range, use Pick n Pay/Checkers ingredients)'
        : 'up to R150 (premium, can use Woolworths ingredients)'

    const dietNote = dietaryPreference
      ? `\nDietary preference: ${dietaryPreference}.`
      : ''

    const profileNote = profileContext
      ? `\nUser context: ${profileContext}`
      : ''

    const prompt = `You are a South African nutritionist and meal planner. Create a personalised one-day meal plan.

Requirements:
- Target: ${calorieGoal} kcal for the day
- Budget: ${budgetLabel} per day (prices in South African Rand)${dietNote}${profileNote}
- Include 4 meals: breakfast, lunch, dinner, snack
- Use South African foods, brands, and ingredients available at local supermarkets
- Include realistic ZAR prices for each ingredient (2025/2026 prices)

Respond ONLY in this exact JSON (no markdown, no explanation):
{"plan_name":"<creative name>","description":"<1-2 sentences>","category":"<budget|balanced|high-protein|vegetarian|bulk-cook>","budget_tier":"${budgetTier}","estimated_cost_zar":<total number>,"total_calories":<int>,"total_protein":<int>,"total_carbs":<int>,"total_fat":<int>,"prep_time_min":<int>,"emoji":"<single emoji>","meals":[{"name":"<meal name>","meal_type":"<breakfast|lunch|dinner|snack>","calories":<int>,"protein":<int>,"carbs":<int>,"fat":<int>,"emoji":"<single emoji>","recipe":"<brief instructions>","ingredients":[{"name":"<ingredient>","quantity":"<amount>","estimated_price_zar":<number>,"category":"<protein|produce|grain|dairy|spice|pantry>"}]}]}`

    // Call Anthropic
    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY not set in environment')

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 2048,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!anthropicRes.ok) {
      const err = await anthropicRes.json()
      throw new Error(err.error?.message ?? `Anthropic error ${anthropicRes.status}`)
    }

    const anthropicData = await anthropicRes.json()
    const raw = anthropicData.content.map((b: { text?: string }) => b.text ?? '').join('')
    const clean = raw.replace(/```json/g, '').replace(/```/g, '').trim()

    // Validate it's valid JSON before returning
    JSON.parse(clean)

    // Increment scan count
    const { data: currentUsage } = await supabase
      .from('usage')
      .select('scan_count')
      .eq('user_id', user.id)
      .eq('date', today)
      .single()

    await supabase.from('usage').upsert(
      {
        user_id: user.id,
        date: today,
        scan_count: (currentUsage?.scan_count ?? 0) + 1,
        chat_count: currentUsage?.chat_count ?? 0,
      },
      { onConflict: 'user_id,date' }
    )

    return new Response(clean, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('generate-plan error:', err)
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
