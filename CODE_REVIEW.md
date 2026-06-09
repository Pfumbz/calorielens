# CalNova — Security & Stability Review

**Scope:** Flutter client (`lib/`) + Supabase Edge Functions (`supabase/functions/`) + schema.
**Context:** Live on Play Store; crash-prevention and abuse-prevention are the priorities.
**Verdict:** Architecturally sound (good offline-first design, server-side rate limits, secure-storage for keys), but there is a **critical monetization/cost bypass** in how Pro status is trusted, plus a confirmed crash bug and several real abuse vectors. Fix the Critical/High items before the next billing cycle.

---

## CRITICAL

### C1 — Any user can grant themselves Pro (paywall + API-cost bypass)
**Where:** `supabase/schema.sql` RLS policy (lines 76–77) + `supabase/functions/scan-image/index.ts` (37–43) + `chat/index.ts` (32–38) + `lib/services/supabase_service.dart` `updateProfile` (71–77).

**Issue:** The Edge Functions decide the tier by reading `profiles.is_premium`:
```ts
const { data: profile } = await supabase.from('profiles').select('is_premium').eq('id', user.id).single()
const isPremium = profile?.is_premium ?? false
```
But RLS lets the user write that same column:
```sql
create policy "Users can update their own profile"
  on public.profiles for update using (auth.uid() = id);   -- no WITH CHECK, no column restriction
```
The app even ships a code path that writes it (`updateProfile({'is_premium': true})`). So any user — using the public anon key + their own JWT and any HTTP client — can run `update profiles set is_premium = true where id = <self>` and immediately receive **50 scans/day + unlimited chat for free**. This is a complete subscription bypass and an uncapped Anthropic-cost exposure.

**Why it matters (mobile):** Clients are fully untrusted. Anything the device can write, an attacker can write. The anon key is shipped in the APK (`SupabaseConfig.supabaseAnonKey`) and trivially extracted.

**Fix:**
1. Make `is_premium` server-writable only. Restrict the update policy so users cannot change privileged columns, e.g. a trigger that blocks `is_premium` changes from non-service-role:
```sql
create or replace function public.prevent_premium_self_grant()
returns trigger language plpgsql security definer as $$
begin
  if new.is_premium is distinct from old.is_premium then
    -- only the service role (Edge Functions) may change this
    if current_setting('request.jwt.claims', true)::jsonb->>'role' <> 'service_role' then
      new.is_premium := old.is_premium;
    end if;
  end if;
  return new;
end; $$;

create trigger trg_prevent_premium_self_grant
  before update on public.profiles
  for each row execute function public.prevent_premium_self_grant();
```
2. Set `is_premium` only from a new server-side **verify-purchase** Edge Function (see C2) using the `service_role` key.
3. Remove `is_premium` from any client-side `updateProfile` call.

**Severity: Critical**

---

### C2 — No server-side purchase verification (Pro granted on client trust)
**Where:** `lib/services/purchase_service.dart` `_verifyAndDeliver` (218–243) — the TODO in the file already admits this.

**Issue:** Premium is granted whenever a `purchased`/`restored` event arrives with a *non-empty* token. The token is never validated against Google Play. On a rooted device or with billing-spoofing tools, a fake purchase event grants Pro. This is the client half of C1.

**Fix:** Add `/functions/v1/verify-purchase` that calls the Google Play Developer API (`purchases.subscriptions.get`) with the `purchaseToken`, confirms an active, non-expired subscription, and only then sets `profiles.is_premium = true` via `service_role`. The client should treat local `_isProActive` as optimistic UI only; the server decides entitlements.

**Severity: Critical**

---

## HIGH

### H1 — Unlimited free scans via the `correction_hint` flag
**Where:** `scan-image/index.ts` (109, 220–225).

**Issue:** `isCorrection = !!correction_hint`, and when true the function **skips the usage increment** but still calls the (expensive Sonnet vision) model. `correction_hint` is fully client-controlled. A user can attach `correction_hint` to *every* request and never consume quota → unlimited vision scans → unbounded Anthropic spend.

**Fix:** Corrections must still be metered (or metered at a reduced rate), and/or require a server-validated reference to a prior scan. Don't let a client-supplied field disable rate limiting.

**Severity: High**

### H2 — scan-image checks the limit, calls the model, *then* increments (race + over-spend)
**Where:** `scan-image/index.ts` (51–69 read-only check → 192 model call → 220 increment).

**Issue:** The pre-check is non-atomic. N concurrent requests all read `scan_count = 0`, all pass, all call Anthropic, and only the atomic RPC afterward caps the counter — but the expensive calls already happened. The `chat` function does this correctly (increment-first via `increment_chat_if_allowed`); scan-image does not.

**Fix:** Mirror `chat`: call `increment_scan_if_allowed` **before** the Anthropic call; if it returns `-1`, reject with 429 and never call the model. Refund/decrement only if you want corrections free (do it after a verified failure).

**Severity: High**

### H3 — `_sanitizeForPrompt` throws RangeError (crashes the correction flow)
**Where:** `lib/services/anthropic_service.dart` (58–66).
```dart
return input
  .replaceAll(...).trim()
  .substring(0, input.length.clamp(0, maxLength));  // uses ORIGINAL length on the TRIMMED string
```
**Issue:** After `.trim()` the string is shorter than `input`, but `substring` is bounded by `input.length`. Any input with leading/trailing whitespace (e.g. `"chicken "` — extremely common) makes the end index exceed the trimmed length → `RangeError`. This only runs on the BYOK path today, but it's a latent crash.

**Fix:**
```dart
static String _sanitizeForPrompt(String input, {int maxLength = 300}) {
  final s = input.replaceAll(RegExp(r'[\r\n]+'), ' ').replaceAll('"', "'").trim();
  return s.length <= maxLength ? s : s.substring(0, maxLength);
}
```
**Severity: High** (Medium in practice while BYOK is hidden, but it's a guaranteed crash on a trivial input)

### H4 — Anonymous-account farming
**Where:** `AuthGate._handleGuestMode` → `signInAnonymously()`; limits keyed on `user_id`.

**Issue:** Every anonymous sign-in is a fresh `user_id` with fresh quota (3 scans + 5 chats). Repeatedly creating guests yields unlimited free usage. The device-level `scanCountToday` counter mitigates same-install abuse but the server has no device binding.

**Fix:** Rate-limit anonymous creation (per IP / per device attestation), or attach device identity (Play Integrity) to guest quotas. At minimum, lower guest limits and monitor anon-user creation rate.

**Severity: High** (cost vector)

---

## MEDIUM

### M1 — Client supplies the coach `systemPrompt` and full `history`
**Where:** `chat/index.ts` (65, 76–79).

**Issue:** `systemPrompt` and `history` are taken verbatim from the request. A user can replace the coach persona/guardrails entirely and use your billed endpoint as a free general-purpose Claude, or inject crafted `assistant` turns. No length cap means token-cost inflation.

**Fix:** Build the system prompt server-side (the server knows it's "the coach"). Cap `history` length and per-message size. Validate roles.

**Severity: Medium**

### M2 — `today_screen.dart` leaks `TextEditingController`s
**Where:** `lib/screens/today_screen.dart` — `TodayScreen` is a `StatelessWidget` (14) yet creates controllers in dialog/sheet helpers (928, 1135, 1163–1167) that are never disposed.

**Issue:** Each time the "edit goal" / "add manually" sheets open, 1–5 controllers are allocated and never freed. Over a session this leaks memory and focus listeners.

**Fix:** Move each dialog/sheet body into a small `StatefulWidget` that disposes its controllers in `dispose()` (as `_EditSheet` in scan_screen now does), or dispose them in the `.then()` after the sheet closes.

**Severity: Medium**

### M3 — `setState` after `await` without a `mounted` guard (CoachScreen)
**Where:** `lib/screens/coach_screen.dart` (431 → 436/441/449).

**Issue:** Unlike the other three chat call-sites (382, 816, 2073) which guard with `mounted`, this one doesn't. A chat request can take up to 30s on a poor network; if the State is disposed in that window (sign-out → `AuthGate` swaps to `LoginScreen` → `AppShell`/CoachScreen unmounted), `setState` throws *"setState() called after dispose()"*.

**Fix:** Add `if (!mounted) return;` after the await (and before the `finally` setState). Consistency with the other sites.

**Severity: Medium**

### M4 — Edge Functions return raw internal error messages
**Where:** `scan-image` (232), `chat` (112): `error: (err as Error).message`.

**Issue:** Leaks internals to clients (e.g. `ANTHROPIC_API_KEY not set`, upstream Anthropic errors). Information disclosure + confusing UX.

**Fix:** Log full error server-side; return a generic message + an error code to the client.

**Severity: Medium**

### M5 — Pervasive silent `catch (_) {}` with no telemetry
**Where:** `supabase_service.dart` (every method), `app_state.dart` (`_refreshFromCloud`, `_migrateLocalDataToCloud`, `_refreshHealthData`), `storage_service.dart`, etc.

**Issue:** Failures vanish. In production you have no visibility into sync failures, parse errors, or auth issues, and bugs become "it just doesn't work sometimes." Swallowed cloud-sync errors can also cause silent local/cloud divergence.

**Fix:** Add crash/error reporting (Sentry or Firebase Crashlytics). Keep the graceful fallback, but log the exception before swallowing it.

**Severity: Medium**

### M6 — `restorePurchases` timeout race
**Where:** `purchase_service.dart` (151–166).

**Issue:** A hard `Future.delayed(5s)` emits an *error* if `_isProActive` isn't set yet, even when the restore legitimately completes at, say, 6s — surfacing a false "No active subscription found." Also the broadcast `_stateController` is closed in `dispose()`; any later `add()` on the app-lifetime singleton throws "Cannot add to a closed StreamController."

**Fix:** Track the restore with a completer/flag the stream handler clears; don't fire a fixed-timer error. Don't `close()` a singleton's controller (or guard every `add` with `if (!_stateController.isClosed)`).

**Severity: Medium**

---

## LOW

- **L1 — JSON parsing fragility / truncation.** `_parseResponseWithRaw` (anthropic_service 272–284) and the Edge Functions assume valid JSON in `content[0].text`. With `max_tokens: 1024`, a many-item meal can truncate mid-JSON → `jsonDecode` throws → generic failure. Raise `max_tokens` for scans and wrap parsing with a repair/retry path.
- **L2 — `Access-Control-Allow-Origin: '*'`** on authenticated endpoints. Low risk (JWT required) but tighten if these are only called from the app.
- **L3 — Fragile error classification.** `auth_service.dart` (115) `msg.contains('10')` misfires on any message containing "10" (e.g. "1000"). Match on structured codes where possible.
- **L4 — `IndexedStack` builds all 5 screens eagerly** (`main.dart` 463). Coach (2.6k lines) + Today + Meals all build at first frame and stay resident. Consider lazy `IndexedStack` or keep-alive-on-demand for startup time/memory.
- **L5 — `chat()` returns `''` on missing `response`** (backend_service 228) → blank assistant bubble. Surface an error instead.
- **L6 — USDA `DEMO_KEY`** (per CLAUDE.md) is 30 req/hr globally; enrichment will silently fail under real load. Provision a real key.
- **L7 — Cloud overwrites local diary.** `_refreshFromCloud` (349–365) replaces `_diary` with cloud "today". Entries added offline before a refresh (and not yet synced) can be lost since cloud is treated as authoritative. Consider merge-by-id/timestamp.
- **L8 — Day-rollover depends on app resume + device clock** (`_onAppResumed`). Manual clock changes or long-running foreground sessions can desync counters; the server is authoritative so impact is cosmetic, but worth noting.

---

## Patterns that flag AI-generated code (treat as unreliable)

1. **Remediation tags left in code** — `H-1`, `M-4`, `C-1`, `L-3` comments and verbose "IMPORTANT TODO" blocks that describe the correct fix (server-side purchase verification) without implementing it. The comment says "secure," the code is not.
2. **Inconsistent guards across near-identical sites** — three chat calls check `mounted`, one doesn't (M3); `_quantities` was a fixed-length list while its sibling list was growable (the earlier crash). Copy-paste drift is the tell.
3. **Duplicated source-of-truth** — the full scan prompts exist in **both** the client (`anthropic_service.dart`) and the Edge Functions. They will diverge; the free-scan limit is already described inconsistently (comments say 5/10 in different places).
4. **Defensive `catch (_) {}` everywhere** — looks robust, actually hides failures.
5. **Confident-but-wrong "fixes"** — `_sanitizeForPrompt` was added *for* safety and itself introduces a crash (H3).

## Looks correct but is fragile under edge cases

- Multi-item meals + `max_tokens: 1024` → silent JSON truncation (L1).
- USDA dedup map (`backend_service` 256–264) collapses items sharing a `usda_query`; fine until two genuinely different foods map to the same query.
- Offline-add-then-cloud-refresh diary divergence (L7).
- `restorePurchases` happy path works; the timeout path lies (M6).

## Hardening checklist for production

1. Lock `is_premium` (C1) + add server purchase verification (C2). **Do these first.**
2. Meter corrections and move scan increment before the model call (H1, H2).
3. Server-owned coach system prompt + input caps (M1).
4. Fix the `_sanitizeForPrompt` crash (H3).
5. Add crash/error telemetry (M5) — you're flying blind in prod without it.
6. Constrain anonymous-account creation (H4).
7. Dispose dialog controllers + add the missing `mounted` guard (M2, M3).
8. Raise `max_tokens` and harden JSON parsing (L1).
9. De-duplicate prompts to a single server source of truth.
