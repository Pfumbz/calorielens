import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const FREE_CHAT_LIMIT = 15 // messages per day for free users

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

    // Atomically check + increment chat count (prevents race conditions)
    // Pro users get effectively unlimited (999999), free users get FREE_CHAT_LIMIT
    const chatLimit = isPremium ? 999999 : FREE_CHAT_LIMIT

    const { data: newCount, error: rpcError } = await supabase.rpc(
      'increment_chat_if_allowed',
      { p_user_id: user.id, p_date: today, p_limit: chatLimit }
    )

    if (rpcError) throw new Error(`Usage check failed: ${rpcError.message}`)

    if (newCount === -1) {
      return new Response(
        JSON.stringify({
          error: `You've used all ${FREE_CHAT_LIMIT} free coach messages for today. Upgrade to Pro for unlimited AI coaching.`,
          code: 'CHAT_LIMIT_REACHED',
        }),
        { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { history, userMessage, systemPrompt } = await req.json()
    if (!userMessage) {
      return new Response(JSON.stringify({ error: 'Missing userMessage' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const anthropicKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!anthropicKey) throw new Error('ANTHROPIC_API_KEY not set in environment')

    const messages = [
      ...(history ?? []),
      { role: 'user', content: userMessage },
    ]

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
        system: systemPrompt ?? '',
        messages,
      }),
    })

    if (!anthropicRes.ok) {
      const err = await anthropicRes.json()
      throw new Error(err.error?.message ?? `Anthropic error ${anthropicRes.status}`)
    }

    const anthropicData = await anthropicRes.json()
    const response = anthropicData.content
      .map((b: { text?: string }) => b.text ?? '')
      .join('')

    // Usage already incremented atomically above — just return the result
    return new Response(JSON.stringify({ response }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    console.error('chat error:', err)
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})
