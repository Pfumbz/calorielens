import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GUEST_SCAN_LIMIT = 3 // scans per day for anonymous guests
const FREE_SCAN_LIMIT = 5  // scans per day for free users
const PRO_SCAN_LIMIT = 50  // scans per day for Pro users
// Corrections (re-analyses) have their own, more generous daily allowance so
// fixing an AI mistake never consumes the user's scan quota.
const GUEST_CORRECTION_LIMIT = 5
const FREE_CORRECTION_LIMIT = 10
const PRO_CORRECTION_LIMIT = 100
const MAX_IMAGE_BYTES = 10 * 1024 * 1024  // 10 MB cap for image payloads

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client authenticated as the calling user
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )

    // Verify the user is authenticated
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

    const today = new Date().toISOString().split('T')[0]
    const scanLimit = isPremium ? PRO_SCAN_LIMIT : isAnonymous ? GUEST_SCAN_LIMIT : FREE_SCAN_LIMIT

    // Parse request body (supports optional second image and correction metadata)
    const body = await req.json()
    const { imageBase64, mediaType, imageBase64_2, mediaType_2, correction_hint, original_context } = body
    if (!imageBase64 || !mediaType) {
      return new Response(JSON.stringify({ error: 'Missing imageBase64 or mediaType' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Validate image size(s) (base64 is ~4/3 of raw bytes)
    const estimatedBytes = Math.ceil(imageBase64.length * 3 / 4)
    if (estimatedBytes > MAX_IMAGE_BYTES) {
      return new Response(
        JSON.stringify({ error: 'Image is too large. Please use a smaller photo (max 10 MB).' }),
        { status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    if (imageBase64_2) {
      const estimatedBytes2 = Math.ceil(imageBase64_2.length * 3 / 4)
      if (estimatedBytes2 > MAX_IMAGE_BYTES) {
        return new Response(
          JSON.stringify({ error: 'Second image is too large. Please use a smaller photo (max 10 MB).' }),
          { status: 413, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }
    }

    // Validate media type(s)
    const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif']
    if (!allowedTypes.includes(mediaType)) {
      return new Response(
        JSON.stringify({ error: 'Unsupported image format. Use JPEG, PNG, WebP, or GIF.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const hasSecondImage = !!(imageBase64_2 && mediaType_2)
    const isCorrection = !!correction_hint

    // ── Rate limiting ─────────────────────────────────────────────────────────
    // Scans and corrections (re-analyses) have SEPARATE daily allowances, metered
    // atomically BEFORE the model call. This keeps the H1/H2 fixes (no concurrency
    // over-spend; client-controlled correction_hint can't grant unlimited free AI)
    // while ensuring a correction never consumes the user's scan quota.
    const meterRpc = isCorrection ? 'increment_correction_if_allowed' : 'increment_scan_if_allowed'
    const meterColumn = isCorrection ? 'correction_count' : 'scan_count'
    const meterLimit = isCorrection
      ? (isPremium ? PRO_CORRECTION_LIMIT : isAnonymous ? GUEST_CORRECTION_LIMIT : FREE_CORRECTION_LIMIT)
      : scanLimit

    const { data: newCount, error: rpcError } = await supabase.rpc(
      meterRpc,
      { p_user_id: user.id, p_date: today, p_limit: meterLimit }
    )
    if (rpcError) throw new Error(`Usage check failed: ${rpcError.message}`)
    if (newCount === -1) {
      const message = isCorrection
        ? `You've reached today's limit for re-analysing meals. Your daily scans are unaffected.`
        : isPremium
          ? `You've reached your daily limit of ${PRO_SCAN_LIMIT} scans. Limit resets at midnight.`
          : isAnonymous
            ? `You've used all ${GUEST_SCAN_LIMIT} free guest scans for today. Sign up for more scans!`
            : `You've used all ${FREE_SCAN_LIMIT} free scans for today. Upgrade to Pro for up to ${PRO_SCAN_LIMIT} scans/day.`
      return new Response(
        JSON.stringify({ error: message, code: isCorrection ? 'CORRECTION_LIMIT_REACHED' : 'SCAN_LIMIT_REACHED' }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Best-effort refund of the metered slot if the model call fails, so users
    // are not charged for an error (important on poor networks).
    const refundScan = async () => {
      try {
        await supabase
          .from('usage')
          .update({ [meterColumn]: Math.max(0, (newCount as number) - 1) })
          .eq('user_id', user.id)
          .eq('date', today)
      } catch (_) {
        // ignore refund failure — metering integrity is preserved either way
      }
    }

    // Call Anthropic API (key stored securely in Supabase vault)
    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) {
      await refundScan()
      throw new Error('ANTHROPIC_API_KEY not set in environment')
    }

    const jsonFormat = `{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<specific food>","portion":"<estimated size with unit>","calories":<int>,"weight_g":<number>,"usda_query":"<generic USDA search term>","note":"<brief observation or uncertainty>"}],"overall_notes":"<2-3 sentences: nutritional highlights, balance assessment, any concerns>"}`

    const promptSingle = `You are an expert nutritionist specialising in South African cuisine. Analyse this meal photo and estimate its nutritional content.

INSTRUCTIONS:
1. Identify every distinct food item visible in the photo. Look carefully — don't miss sides, sauces, or drinks.
2. Estimate realistic portion sizes based on the plate/bowl size and food volume. Use standard portion references (a fist ≈ 1 cup, palm ≈ 100g meat, thumb ≈ 1 tbsp).
3. For EACH item, estimate the weight in grams (weight_g). This is critical — be as accurate as possible.
4. For EACH item, provide a "usda_query" — a simple, generic English food name suitable for searching the USDA database (e.g. "rice white cooked", "chicken breast grilled", "cheddar cheese"). Avoid brand names.
5. For South African dishes (e.g. pap, chakalaka, bunny chow, boerewors, vetkoek, samp & beans, mogodu, morogo), use nutrition data specific to those foods — do NOT substitute with generic Western equivalents.
6. When uncertain about a food item, name your best guess and note the uncertainty in that item's "note" field.
7. Round calories to the nearest 5. Be conservative rather than over-estimating.
8. The meal_name should be concise but descriptive (e.g. "Grilled Chicken with Pap & Chakalaka" not just "Plate of food").

Respond ONLY in this exact JSON format (no markdown, no backticks, no explanation):
${jsonFormat}`

    const promptMulti = `You are an expert nutritionist specialising in South African cuisine. You are given TWO photos of the SAME meal taken from different angles. Use BOTH images together to accurately identify food items and estimate portion sizes.

INSTRUCTIONS:
1. The first image is typically a top-down view. The second image shows a different angle (side, 45°, etc.) revealing depth and volume that the top view cannot show.
2. Cross-reference both images: use the top view to identify foods and the side/angle view to gauge how deep or tall portions are — bowls, cups, and plates often hold much more than they appear from above.
3. For EACH item, estimate the weight in grams (weight_g). Use BOTH angles to judge volume accurately. This is critical — the second angle exists specifically to improve your weight estimate.
4. For EACH item, provide a "usda_query" — a simple, generic English food name suitable for searching the USDA database (e.g. "rice white cooked", "chicken breast grilled", "cheddar cheese"). Avoid brand names.
5. For South African dishes (e.g. pap, chakalaka, bunny chow, boerewors, vetkoek, samp & beans, mogodu, morogo), use nutrition data specific to those foods — do NOT substitute with generic Western equivalents.
6. When uncertain about a food item, name your best guess and note the uncertainty in that item's "note" field.
7. Round calories to the nearest 5. Be conservative rather than over-estimating.
8. The meal_name should be concise but descriptive (e.g. "Grilled Chicken with Pap & Chakalaka" not just "Plate of food").

Respond ONLY in this exact JSON format (no markdown, no backticks, no explanation):
${jsonFormat}`

    const ctx = original_context
    const promptCorrection = `You are an expert nutritionist. The user has CORRECTED a food identification mistake made by the AI.

⚠️ OVERRIDE IN EFFECT — THE USER'S CORRECTION IS THE GROUND TRUTH ⚠️
The AI previously misidentified the food. The user is now telling you what it actually is.
You MUST trust the user's correction completely. Do NOT use the photo to re-identify the food — the photo is ONLY for estimating portion size (weight in grams).

CORRECTED FOOD NAME(S): "${correction_hint}"

WHAT THE AI PREVIOUSLY (WRONGLY) CALLED IT: ${ctx?.name ?? 'Unknown'}
— Ignore this. The user says it is wrong.

RULE 1 — FOOD IDENTITY: The corrected name above is what the food IS. Accept it without question. Never revert to the old name or let the photo override it.
RULE 2 — SINGLE UNIT: Return nutrition for EXACTLY ONE unit/serving. Ignore any quantity numbers in the corrected name — the app handles scaling in code.
RULE 3 — PHOTO USE: Use the photo ONLY to estimate the weight in grams of one unit/serving of the corrected food. Nothing else.

INSTRUCTIONS:
1. Look up nutrition data for "${correction_hint}" — this is the food, full stop.
2. Use the photo to estimate weight_g of ONE serving of that food as it appears on the plate.
3. Calculate calories and macros from the corrected food's nutrition data × estimated weight.
4. For EACH item, provide a usda_query — a simple generic English name for USDA lookup.
5. For South African dishes (pap, chakalaka, boerewors, vetkoek, samp, mogodu, morogo, pork trotters) use SA-specific nutrition data.
6. Round calories to the nearest 5.
7. The portion field describes ONE unit only (e.g. "1 pork trotter (~200g)").

Respond ONLY in this exact JSON format (no markdown, no backticks):
${jsonFormat}`

    const prompt = isCorrection ? promptCorrection : hasSecondImage ? promptMulti : promptSingle

    // Build content array — one or two images followed by prompt
    const contentArray: Array<Record<string, unknown>> = [
      {
        type: 'image',
        source: { type: 'base64', media_type: mediaType, data: imageBase64 },
      },
    ]
    if (hasSecondImage) {
      contentArray.push({
        type: 'image',
        source: { type: 'base64', media_type: mediaType_2, data: imageBase64_2 },
      })
    }
    contentArray.push({ type: 'text', text: prompt })

    let anthropicData
    try {
      const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': anthropicKey,
          'anthropic-version': '2023-06-01',
        },
        body: JSON.stringify({
          model: 'claude-sonnet-4-6',
          max_tokens: 2048, // headroom so large meals don't truncate the JSON
          messages: [{
            role: 'user',
            content: contentArray,
          }],
        }),
      })

      if (!anthropicRes.ok) {
        const err = await anthropicRes.json()
        throw new Error(err.error?.message ?? `Anthropic error ${anthropicRes.status}`)
      }

      anthropicData = await anthropicRes.json()
    } catch (e) {
      // Model call failed — refund the metered slot, then surface a generic error.
      await refundScan()
      throw e
    }

    const raw = anthropicData.content.map((b: { text?: string }) => b.text ?? '').join('')
    const clean = raw.replace(/```json/g, '').replace(/```/g, '').trim()

    return new Response(clean, {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('scan-image error:', err)
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
