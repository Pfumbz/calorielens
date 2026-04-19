import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const FREE_SCAN_LIMIT = 10

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

    const { data: { user }, error: authError } = await supabase.auth.getUser()
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized. Please sign in.' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const { data: profile } = await supabase
      .from('profiles')
      .select('is_premium')
      .eq('id', user.id)
      .single()

    const isPremium = profile?.is_premium ?? false
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
            error: `You've used all ${FREE_SCAN_LIMIT} free scans for today. Upgrade to Pro for unlimited scanning.`,
            code: 'SCAN_LIMIT_REACHED',
          }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    const { description } = await req.json()
    if (!description) {
      return new Response(JSON.stringify({ error: 'Missing description' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY not set in environment')

    const prompt = `You are a professional nutritionist. Estimate the nutritional content for this meal description: "${description}"
Respond ONLY in this exact JSON (no markdown):
{"meal_name":"<short name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<size>","calories":<int>,"note":"<brief>"}],"overall_notes":"<2-3 sentences>"}`

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': anthropicKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-haiku-4-5-20251001',
        max_tokens: 1024,
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
        chat_count: 0,
      },
      { onConflict: 'user_id,date' }
    )

    return new Response(clean, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('scan-text error:', err)
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
