import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const PRO_PRODUCT_ID = 'calorielens_pro_monthly'
const PACKAGE_NAME = 'com.pcmacstudios.calorielens'

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    const { data: { user }, error: authError } = await authClient.auth.getUser()
    if (authError || !user) {
      return json({ error: 'Unauthorized. Please sign in.' }, 401)
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    const body = await req.json().catch(() => ({}))
    const { purchaseToken, productId } = body as { purchaseToken?: string; productId?: string }
    const nowIso = new Date().toISOString()

    if (!purchaseToken) {
      const { data } = await admin
        .from('profiles')
        .select('is_premium, pro_verified, pro_expires_at')
        .eq('id', user.id)
        .single()
      return json({
        isPremium: data?.is_premium ?? false,
        verified: data?.pro_verified ?? false,
        expiresAt: data?.pro_expires_at ?? null,
      }, 200)
    }

    if (productId && productId !== PRO_PRODUCT_ID) {
      return json({ error: 'Unknown product.' }, 400)
    }

    // If this purchase token is bound to a DIFFERENT app account, move it to the
    // current one (the Play account owner switched app logins). Only one account
    // holds the entitlement at a time — the previous one is cleared.
    const { data: existing } = await admin
      .from('profiles')
      .select('id')
      .eq('pro_purchase_token', purchaseToken)
      .maybeSingle()
    if (existing && existing.id !== user.id) {
      await admin.from('profiles').update({
        is_premium: false,
        pro_purchase_token: null,
        pro_verified: false,
        pro_updated_at: nowIso,
      }).eq('id', existing.id)
    }

    const sub = await getSubscriptionStatus(purchaseToken)

    await admin.from('purchase_debug').insert({
      user_id: user.id,
      stage: sub.transient ? 'transient' : (sub.active ? 'active' : 'inactive'),
      detail: sub.detail ?? null,
    })

    if (sub.transient) {
      // Could not reach/authenticate Google. Grant PROVISIONALLY so a paying
      // user isn't blocked by a Google API hiccup or permission propagation.
      await admin.from('profiles').update({
        is_premium: true,
        pro_purchase_token: purchaseToken,
        pro_verified: false,
        pro_updated_at: nowIso,
      }).eq('id', user.id)
      return json({ isPremium: true, verified: false, provisional: true }, 200)
    }

    if (!sub.active) {
      await admin.from('profiles').update({
        is_premium: false,
        pro_verified: true,
        pro_expires_at: sub.expiresAt,
        pro_updated_at: nowIso,
      }).eq('id', user.id)
      return json({ isPremium: false, verified: true }, 200)
    }

    await admin.from('profiles').update({
      is_premium: true,
      pro_purchase_token: purchaseToken,
      pro_verified: true,
      pro_expires_at: sub.expiresAt,
      pro_updated_at: nowIso,
    }).eq('id', user.id)
    return json({ isPremium: true, verified: true, expiresAt: sub.expiresAt }, 200)
  } catch (err) {
    console.error('verify-purchase error:', err)
    return json({ error: 'Purchase verification failed. Please try again.' }, 500)
  }
})

type SubStatus = { active: boolean; expiresAt: string | null; transient: boolean; detail?: string }

async function getSubscriptionStatus(purchaseToken: string): Promise<SubStatus> {
  let accessToken: string
  try {
    accessToken = await getGoogleAccessToken()
  } catch (e) {
    return { active: false, expiresAt: null, transient: true, detail: 'auth:' + ((e as Error).message ?? String(e)) }
  }

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`

  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } })

  if (res.status === 404 || res.status === 410) {
    return { active: false, expiresAt: null, transient: false, detail: 'play_notfound_' + res.status }
  }
  if (!res.ok) {
    const t = await res.text()
    return { active: false, expiresAt: null, transient: true, detail: `play_${res.status}:${t.slice(0, 400)}` }
  }

  const data = await res.json()
  const state: string = data.subscriptionState ?? ''
  const expiry: string | null = data?.lineItems?.[0]?.expiryTime ?? null
  const notExpired = expiry ? Date.parse(expiry) > Date.now() : false
  const active =
    state === 'SUBSCRIPTION_STATE_ACTIVE' ||
    state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
    (state === 'SUBSCRIPTION_STATE_CANCELED' && notExpired)

  return { active, expiresAt: expiry, transient: false, detail: 'state=' + state }
}

async function getGoogleAccessToken(): Promise<string> {
  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
  if (!raw) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON not set')
  const sa = JSON.parse(raw) as { client_email: string; private_key: string; token_uri?: string }

  const now = Math.floor(Date.now() / 1000)
  const header = { alg: 'RS256', typ: 'JWT' }
  const claims = {
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: sa.token_uri ?? 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const unsigned = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToBuffer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  const sigBuf = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned))
  const jwt = `${unsigned}.${b64urlBytes(new Uint8Array(sigBuf))}`

  const tokenRes = await fetch(claims.aud, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  if (!tokenRes.ok) {
    throw new Error(`token_${tokenRes.status}:${(await tokenRes.text()).slice(0, 300)}`)
  }
  const tok = await tokenRes.json()
  if (!tok.access_token) throw new Error('no_access_token')
  return tok.access_token as string
}

function b64url(str: string): string {
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
function b64urlBytes(bytes: Uint8Array): string {
  let s = ''
  for (const b of bytes) s += String.fromCharCode(b)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
function pemToBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '')
  const bin = atob(b64)
  const buf = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) buf[i] = bin.charCodeAt(i)
  return buf.buffer
}

function json(payload: unknown, status: number): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
