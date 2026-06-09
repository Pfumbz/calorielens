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
    // ── Authenticate the calling user (anon key + their JWT) ────────────────
    const authClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: req.headers.get('Authorization')! } } }
    )
    const { data: { user }, error: authError } = await authClient.auth.getUser()
    if (authError || !user) {
      return json({ error: 'Unauthorized. Please sign in.' }, 401)
    }

    // ── Service-role client: the ONLY path allowed to write entitlement ──────
    const admin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { persistSession: false } }
    )

    const body = await req.json().catch(() => ({}))
    const { purchaseToken, productId } = body as { purchaseToken?: string; productId?: string }

    // Token-less call = "what's my current entitlement?" (used on app launch).
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

    // ── Token uniqueness: a purchase token may back only one account ─────────
    const { data: existing } = await admin
      .from('profiles')
      .select('id')
      .eq('pro_purchase_token', purchaseToken)
      .maybeSingle()
    if (existing && existing.id !== user.id) {
      return json({ error: 'This purchase is already linked to another account.' }, 409)
    }

    // ── Validate the token directly with Google Play ─────────────────────────
    const sub = await getSubscriptionStatus(purchaseToken)
    // sub.transient === true means we could not reach/authenticate Google.
    // Do NOT change entitlement on a transient failure — ask the client to retry.
    if (sub.transient) {
      return json({ error: 'Could not verify with Google right now. Please try again.' }, 503)
    }

    if (!sub.active) {
      // Google says this subscription is not active (expired, on hold, paused,
      // refunded, or the token is invalid). Revoke any premium for this user.
      await admin
        .from('profiles')
        .update({
          is_premium: false,
          pro_verified: true,
          pro_expires_at: sub.expiresAt,
          pro_updated_at: new Date().toISOString(),
        })
        .eq('id', user.id)
      return json({ isPremium: false, verified: true }, 200)
    }

    // Active & verified — grant Pro.
    const { error: updateError } = await admin
      .from('profiles')
      .update({
        is_premium: true,
        pro_purchase_token: purchaseToken,
        pro_verified: true,
        pro_expires_at: sub.expiresAt,
        pro_updated_at: new Date().toISOString(),
      })
      .eq('id', user.id)

    if (updateError) {
      console.error('verify-purchase update error:', updateError)
      return json({ error: 'Could not record purchase. Please try again.' }, 500)
    }

    return json({ isPremium: true, verified: true, expiresAt: sub.expiresAt }, 200)
  } catch (err) {
    console.error('verify-purchase error:', err)
    return json({ error: 'Purchase verification failed. Please try again.' }, 500)
  }
})

// ─────────────────────────────────────────────────────────────────────────────
// Google Play subscription validation
// ─────────────────────────────────────────────────────────────────────────────
type SubStatus = { active: boolean; expiresAt: string | null; transient: boolean }

async function getSubscriptionStatus(purchaseToken: string): Promise<SubStatus> {
  let accessToken: string
  try {
    accessToken = await getGoogleAccessToken()
  } catch (e) {
    console.error('Google auth failed:', e)
    return { active: false, expiresAt: null, transient: true }
  }

  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${PACKAGE_NAME}/purchases/subscriptionsv2/tokens/${encodeURIComponent(purchaseToken)}`

  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } })

  if (res.status === 404 || res.status === 410) {
    // Token unknown to Google → definitively not entitled (likely fabricated).
    return { active: false, expiresAt: null, transient: false }
  }
  if (!res.ok) {
    // 401/403 (permission/setup) or 5xx → transient; don't change entitlement.
    console.error('Play API error', res.status, await res.text())
    return { active: false, expiresAt: null, transient: true }
  }

  const data = await res.json()
  const state: string = data.subscriptionState ?? ''
  const expiry: string | null = data?.lineItems?.[0]?.expiryTime ?? null
  const notExpired = expiry ? Date.parse(expiry) > Date.now() : false

  // Grant for active / grace-period subscriptions, and for cancelled-but-not-
  // yet-expired (auto-renew off, access remains until period end).
  const active =
    state === 'SUBSCRIPTION_STATE_ACTIVE' ||
    state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD' ||
    (state === 'SUBSCRIPTION_STATE_CANCELED' && notExpired)

  return { active, expiresAt: expiry, transient: false }
}

// Mints a short-lived Google OAuth2 access token from the service account
// using the JWT-bearer grant (RS256), via the Web Crypto API.
async function getGoogleAccessToken(): Promise<string> {
  const raw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON')
  if (!raw) throw new Error('GOOGLE_SERVICE_ACCOUNT_JSON not set')
  const sa = JSON.parse(raw) as {
    client_email: string
    private_key: string
    token_uri?: string
  }

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
  const sigBuf = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned)
  )
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
    throw new Error(`Token endpoint ${tokenRes.status}: ${await tokenRes.text()}`)
  }
  const tok = await tokenRes.json()
  if (!tok.access_token) throw new Error('No access_token returned')
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
