import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GUEST_SCAN_LIMIT = 3 // scans per day for anonymous guests
const FREE_SCAN_LIMIT = 5  // scans per day for free users
const PRO_SCAN_LIMIT = 50  // scans per day for Pro users

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
    const isAnonymous = user.is_anonymous ?? false
    const today = new Date().toISOString().split('T')[0]
    const scanLimit = isPremium ? PRO_SCAN_LIMIT : isAnonymous ? GUEST_SCAN_LIMIT : FREE_SCAN_LIMIT

    const body = await req.json()
    const { description, is_correction, original_context } = body

    // Corrections (re-analysis after "Correct" button) are free — skip the counter
    if (!is_correction) {
      // Atomically check + increment scan count (prevents race conditions)
      const { data: newCount, error: rpcError } = await supabase.rpc(
        'increment_scan_if_allowed',
        { p_user_id: user.id, p_date: today, p_limit: scanLimit }
      )

      if (rpcError) throw new Error(`Usage check failed: ${rpcError.message}`)

      if (newCount === -1) {
        const message = isPremium
          ? `You've reached your daily limit of ${PRO_SCAN_LIMIT} scans. Limit resets at midnight.`
          : isAnonymous
            ? `You've used all ${GUEST_SCAN_LIMIT} free guest scans for today. Sign up for more scans!`
            : `You've used all ${FREE_SCAN_LIMIT} free scans for today. Upgrade to Pro for up to ${PRO_SCAN_LIMIT} scans/day.`
        return new Response(
          JSON.stringify({ error: message, code: 'SCAN_LIMIT_REACHED' }),
          { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }
    if (!description) {
      return new Response(JSON.stringify({ error: 'Missing description' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY not set in environment')

    let prompt: string

    if (is_correction && original_context) {
      // Correction mode: reference the original scan so the AI adjusts
      // proportionally instead of estimating from scratch.
      const oc = original_context
      prompt = `You are an expert nutritionist. The user previously scanned a meal and is now correcting it.

ORIGINAL ANALYSIS:
- Meal name: ${oc.name ?? 'Unknown'}
- Calories: ${oc.calories ?? '?'} kcal
- Protein: ${oc.protein ?? '?'}g | Carbs: ${oc.carbs ?? '?'}g | Fat: ${oc.fat ?? '?'}g | Fiber: ${oc.fiber ?? '?'}g

The user says the meal should actually be: "${description}"

INSTRUCTIONS:
1. Compare the user's corrected description to the original analysis above.
2. Adjust the nutrition proportionally based on what changed (e.g. if the original had 5 items but the user says there were only 3, scale down accordingly).
3. Use the original analysis as your baseline — do NOT estimate from scratch.
4. Be conservative. Round calories to the nearest 5.
5. Give a concise but descriptive meal_name based on the corrected description.

Respond ONLY in this exact JSON format (no markdown, no backticks):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<estimated size>","calories":<int>,"note":"<brief>"}],"overall_notes":"<2-3 sentences>"}`
    } else {
      prompt = `You are a professional nutritionist specialising in South African cuisine. Estimate the nutritional content for this meal description: "${description}"

INSTRUCTIONS:
1. Identify each food component mentioned.
2. Use standard adult portion sizes unless the user specifies otherwise.
3. For EACH item, estimate the weight in grams (weight_g). This is critical for accuracy.
4. For EACH item, provide a "usda_query" — a simple, generic English food name for USDA database lookup (e.g. "rice white cooked", "chicken breast grilled").
5. Round calories to the nearest 5. Be conservative.

Respond ONLY in this exact JSON (no markdown):
{"meal_name":"<short name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<size>","calories":<int>,"weight_g":<number>,"usda_query":"<generic USDA search term>","note":"<brief>"}],"overall_notes":"<2-3 sentences>"}`
    }

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

    // Usage already incremented atomically above — just return the result
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
