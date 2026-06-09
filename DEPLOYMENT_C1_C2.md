# C1/C2 Rollout — Server-side Entitlement + Forced Update

This change makes **Pro entitlement server-owned**. Clients can no longer set
`is_premium`; only the `verify-purchase` Edge Function (service role) can. A
forced-update gate retires the old app version whose purchase flow predates this.

## What's already done (applied to the live project via connector)

- **DB migration `002_premium_lock_and_config.sql`** — applied.
  - `profiles.is_premium` (+ new `pro_purchase_token`, `pro_verified`,
    `pro_expires_at`, `pro_updated_at`) are now writable **only** by the service
    role. A guard trigger reverts any client attempt. Verified: a simulated
    authenticated self-grant was reverted to `false`. Existing 3 premium users
    preserved.
  - `app_config` table created, seeded `min_supported_build = 12` (forces no one
    yet).
- **Edge Functions deployed:** `scan-image` (v16), `scan-text` (v12),
  `verify-purchase` (v1).

## Client changes in this repo (need a build)

- `backend_service.dart` — `verifyPurchase()` posts the token to the function.
- `purchase_service.dart` — grants Pro **only** after the server confirms; on
  failure the purchase is left pending so Play re-delivers it for retry.
- `app_state.dart` — wires the verifier; no longer writes `is_premium` to cloud.
- `main.dart` — `ForceUpdateScreen` + min-build check (fails open offline).
- `pubspec.yaml` — version `1.5.0+13`, added `package_info_plus`.

## Release steps (in order)

1. **`flutter pub get`** (picks up `package_info_plus`).
2. **Build & smoke-test** a debug build:
   - Make a test purchase → confirm Pro is granted and survives a relaunch
     (server `is_premium` read back via cloud refresh).
   - Confirm scan/chat limits still work; corrections now count toward quota.
3. **Release build 13** (Codemagic) and roll out on Google Play.
4. **WAIT until build 13 is live** on the Store and reasonably adopted.
5. **Then** force old versions to update by raising the config:
   ```sql
   update public.app_config set value = '13' where key = 'min_supported_build';
   ```
   (Do NOT do this before build 13 is downloadable, or build-12 users get stuck
   on the update screen with nowhere to go.)

## Security state: Google validation is LIVE ✅

`verify-purchase` (v3) now validates every purchase token directly with Google
before granting Pro:
- Service account `calnova-purchase-check@refined-legend-330812.iam.gserviceaccount.com`
  created, granted "View financial data…" in Play Console.
- Secret `GOOGLE_SERVICE_ACCOUNT_JSON` stored in Supabase.
- The function mints an OAuth2 token and calls
  `purchases.subscriptionsv2`. It grants Pro only for ACTIVE /
  IN_GRACE_PERIOD (or cancelled-but-not-yet-expired) subscriptions, sets
  `pro_verified = true` + `pro_expires_at`, and **revokes** `is_premium` if
  Google reports the sub is not active. Transient Google errors never change
  entitlement (client is asked to retry).

Combined with the C1 lock, the paywall bypass is now fully closed: clients
cannot write `is_premium`, and the only grant path requires a Google-verified
purchase token.

### Optional follow-ups (not blocking release)
1. **Expiry/cancellation in near-real-time:** add Play **Real-time Developer
   Notifications** (Pub/Sub) → a webhook that flips `is_premium` when a sub
   lapses. Today, lapses are caught the next time the client calls
   verify-purchase (purchase/restore events).
2. **Launch revalidation:** optionally have the app call `restorePurchases()` (or
   the token-less verify endpoint) on launch so expiries are caught promptly.

## Notes / residual items

- **Existing 3 premium users**: keep Pro (value preserved); their token is
  backfilled on next purchase/restore event.
- **Cancellations/expiry** are not yet enforced server-side (no Google check) —
  Pro persists until the validation step above is added.
- **Corrections now consume a scan** (H1 fix). If you want them free without the
  exploit, gate them to a verified recent scan server-side.
