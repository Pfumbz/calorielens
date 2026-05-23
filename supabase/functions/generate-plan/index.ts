import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GUEST_SCAN_LIMIT = 3  // scans per day for anonymous guests
const FREE_SCAN_LIMIT = 5   // shared with scans — generating a plan costs 1 scan credit

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
    const isAnonymous = user.is_anonymous ?? false

    // Atomically check + increment scan count (prevents race conditions)
    const today = new Date().toISOString().split('T')[0]
    const scanLimit = isPremium ? 999999 : isAnonymous ? GUEST_SCAN_LIMIT : FREE_SCAN_LIMIT

    const { data: newCount, error: rpcError } = await supabase.rpc(
      'increment_scan_if_allowed',
      { p_user_id: user.id, p_date: today, p_limit: scanLimit }
    )

    if (rpcError) throw new Error(`Usage check failed: ${rpcError.message}`)

    if (newCount === -1) {
      return new Response(
        JSON.stringify({
          error: `You've used all ${FREE_SCAN_LIMIT} free AI credits for today. Upgrade to Pro for unlimited meal plan generation.`,
          code: 'SCAN_LIMIT_REACHED',
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Parse request
    const { calorieGoal, budgetTier, dietaryPreference, profileContext } = await req.json()
    if (!calorieGoal || !budgetTier) {
      return new Response(JSON.stringify({ error: 'Missing calorieGoal or budgetTier' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Detect country from profileContext (e.g. "Country code: ZA")
    const countryMatch = profileContext?.match(/Country code:\s*(\w+)/i)
    const countryCode = countryMatch?.[1]?.toUpperCase() ?? 'US'
    const currencyMatch = profileContext?.match(/Currency:\s*(\w+)\s*\(([^)]+)\)/i)
    const currency = currencyMatch?.[1] ?? 'USD'
    const currencySymbol = currencyMatch?.[2] ?? '$'

    // Locale-aware context
    const countryContext: Record<string, { name: string, foods: string, stores: string, budgetLow: string, budgetMid: string, budgetHigh: string }> = {
      'ZA': { name: 'South Africa', foods: 'South African foods (pap, chakalaka, boerewors, biltong, butternut, spinach, braai chicken, samp and beans, etc.)', stores: 'Shoprite, Checkers, Pick n Pay, Woolworths', budgetLow: '50', budgetMid: '100', budgetHigh: '150' },
      'NG': { name: 'Nigeria', foods: 'Nigerian foods (jollof rice, plantain, beans, yam, egusi soup, pepper soup, suya, moi moi, etc.)', stores: 'Shoprite, local markets, Spar', budgetLow: '3000', budgetMid: '5000', budgetHigh: '8000' },
      'KE': { name: 'Kenya', foods: 'Kenyan foods (ugali, sukuma wiki, nyama choma, githeri, chapati, tilapia, pilau, etc.)', stores: 'Naivas, Carrefour, local markets', budgetLow: '500', budgetMid: '800', budgetHigh: '1200' },
      'GH': { name: 'Ghana', foods: 'Ghanaian foods (fufu, banku, groundnut soup, jollof rice, waakye, kelewele, etc.)', stores: 'Shoprite, Melcom, local markets', budgetLow: '50', budgetMid: '80', budgetHigh: '120' },
      'GB': { name: 'United Kingdom', foods: 'UK foods and ingredients from British supermarkets', stores: 'Tesco, Sainsbury\'s, Aldi, Asda', budgetLow: '5', budgetMid: '10', budgetHigh: '15' },
      'US': { name: 'United States', foods: 'American foods and common supermarket ingredients', stores: 'Walmart, Trader Joe\'s, Kroger, Whole Foods', budgetLow: '8', budgetMid: '15', budgetHigh: '25' },
      'IN': { name: 'India', foods: 'Indian foods (dal, roti, paneer, biryani, idli, dosa, sabzi, curd rice, etc.)', stores: 'DMart, Big Bazaar, local markets', budgetLow: '200', budgetMid: '400', budgetHigh: '600' },
      'BR': { name: 'Brazil', foods: 'Brazilian foods (arroz e feijão, frango, mandioca, farofa, açaí, coxinha, etc.)', stores: 'Pão de Açúcar, Carrefour, local markets', budgetLow: '30', budgetMid: '50', budgetHigh: '80' },
      'AU': { name: 'Australia', foods: 'Australian foods and supermarket ingredients', stores: 'Coles, Woolworths, Aldi', budgetLow: '10', budgetMid: '20', budgetHigh: '30' },
      'DE': { name: 'Germany', foods: 'German foods and common European ingredients', stores: 'Aldi, Lidl, Edeka, REWE', budgetLow: '5', budgetMid: '10', budgetHigh: '15' },
      'MX': { name: 'Mexico', foods: 'Mexican foods (frijoles, tortillas, pollo, arroz, aguacate, nopales, chilaquiles, etc.)', stores: 'Walmart, Soriana, Bodega Aurrera', budgetLow: '100', budgetMid: '200', budgetHigh: '350' },
      'AE': { name: 'UAE', foods: 'Middle Eastern foods (hummus, shawarma, falafel, rice, lamb, lentils, fattoush, etc.)', stores: 'Carrefour, Lulu, Spinneys', budgetLow: '25', budgetMid: '50', budgetHigh: '80' },
    }

    const ctx = countryContext[countryCode] ?? { name: 'the user\'s country', foods: 'locally available foods and ingredients', stores: 'local supermarkets', budgetLow: '8', budgetMid: '15', budgetHigh: '25' }

    const budgetLabel = budgetTier === 'r50'
      ? `under ${currencySymbol}${ctx.budgetLow} (budget, use ${ctx.stores} ingredients)`
      : budgetTier === 'r100'
        ? `around ${currencySymbol}${ctx.budgetMid} (mid-range, use ${ctx.stores} ingredients)`
        : `up to ${currencySymbol}${ctx.budgetHigh} (premium, use quality store-bought ingredients)`

    const dietNote = dietaryPreference
      ? `\nDietary preference: ${dietaryPreference}.`
      : ''

    const profileNote = profileContext
      ? `\nUser context: ${profileContext}`
      : ''

    const prompt = `You are a nutritionist and meal planner based in ${ctx.name}. Create a personalised one-day meal plan.

Requirements:
- Target: ${calorieGoal} kcal for the day
- Budget: ${budgetLabel} per day (prices in ${currency})${dietNote}${profileNote}
- Include 4 meals: breakfast, lunch, dinner, snack
- Use ${ctx.foods} available at ${ctx.stores}
- Include realistic ${currency} prices for each ingredient (2025/2026 prices)

Respond ONLY in this exact JSON (no markdown, no explanation):
{"plan_name":"<creative name>","description":"<1-2 sentences>","category":"<budget|balanced|high-protein|vegetarian|bulk-cook>","budget_tier":"${budgetTier}","estimated_cost":<total number>,"total_calories":<int>,"total_protein":<int>,"total_carbs":<int>,"total_fat":<int>,"prep_time_min":<int>,"emoji":"<single emoji>","meals":[{"name":"<meal name>","meal_type":"<breakfast|lunch|dinner|snack>","calories":<int>,"protein":<int>,"carbs":<int>,"fat":<int>,"emoji":"<single emoji>","recipe":"<brief instructions>","ingredients":[{"name":"<ingredient>","quantity":"<amount>","estimated_price":<number>,"category":"<protein|produce|grain|dairy|spice|pantry>"}]}]}`

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

    // Usage already incremented atomically above — just return the result
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
