# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CalorieLens is a Flutter-based AI nutrition tracking app (Android primary, iOS future). Users photograph or describe meals; the app uses Claude Haiku to analyse nutrition and provides an AI coaching chat. The backend runs on Supabase (Edge Functions + PostgreSQL + Auth).

**Current target:** Android (debug builds via `flutter run`, release via Codemagic CI/CD at github.com/Pfumbz/calorielens).

---

## Commands

```bash
# Run on connected Android device
flutter run

# If build fails with "Unable to delete directory mergeDebugAssets" (Windows file lock):
Stop-Process -Name "java" -Force -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build
flutter run

# Get/update packages
flutter pub get

# Analyse for lint errors
flutter analyze

# Build release APK (prefer Codemagic; local fallback):
flutter build apk --release
```

There are no automated tests in this project yet.

---

## Architecture

### Request Flow for AI Features

All AI calls route through a single decision point in `BackendService`:

```
AppState.backend (getter)
  └── BackendService(byokApiKey: state.apiKey or null)
        ├── BYOK key present → AnthropicService (direct Anthropic API, no limits)
        └── No BYOK key     → Supabase Edge Functions (rate-limited, key held server-side)
              ├── /functions/v1/scan-image  (10 free scans/day enforced server-side)
              ├── /functions/v1/scan-text
              └── /functions/v1/chat        (15 free messages/day enforced server-side)
```

The Edge Functions are TypeScript/Deno and live in `supabase/functions/`. Each function: verifies the Supabase JWT → checks the `usage` table for daily rate limits → calls Anthropic → increments the counter. The `ANTHROPIC_API_KEY` is stored as a Supabase secret, never in client code.

### State Management

Single `AppState` (`lib/app_state.dart`) extends `ChangeNotifier`, provided at root via `provider`. It is the single source of truth for:
- Local diary entries, profile, water, calorie goal (loaded from `StorageService`/SharedPreferences)
- Auth state (`_supabaseUser` from Supabase)
- Backend rate-limit cache (`_backendScansToday`, `_backendChatsToday`)

**Offline-first pattern:** Local SharedPreferences is always written first. Cloud sync (`SupabaseService`) is fire-and-forget via the `unawaited()` helper at the bottom of `app_state.dart`. On sign-in, `onSignIn()` triggers `_migrateLocalDataToCloud()` (one-time) then `_refreshFromCloud()`.

### Auth & Navigation Flow

```
SplashScreen (2.4s animated)
  └── AuthGate (StatefulWidget, listens to Supabase auth stream)
        ├── signed in      → AppShell
        ├── _guestMode=true → AppShell (set by LoginScreen callback)
        └── not signed in  → LoginScreen(onContinueAsGuest: () => setState(_guestMode=true))
```

`AuthGate` is a `StatefulWidget` with a `_guestMode` bool. Guest mode uses local-only storage with a 3 scan/day limit (enforced by `StorageService.canScan`). Signed-in users get 10 scans/day enforced server-side.

**Sign-in from Settings:** `SettingsScreen` pushes `LoginScreen()` without the `onContinueAsGuest` callback (which hides the guest button when opened mid-session).

### Data Layer

| Layer | File | Responsibility |
|---|---|---|
| Local persistence | `lib/services/storage_service.dart` | SharedPreferences singleton — diary, profile, scan counts, API key |
| Cloud | `lib/services/supabase_service.dart` | Supabase client wrapper — profile sync, diary sync, usage fetch |
| Auth | `lib/services/auth_service.dart` | Email/password + Google Sign-In via Supabase Auth |
| AI proxy | `lib/services/backend_service.dart` | Routes to BYOK or Edge Functions; handles 429 rate-limit errors |
| Direct AI | `lib/services/anthropic_service.dart` | Only used by BackendService when BYOK key is present |

### Supabase Schema (already deployed)

Three tables in `supabase/schema.sql`:
- `profiles` — one row per user; auto-created by a trigger on `auth.users` insert
- `usage` — `(user_id, date)` primary key; `scan_count` and `chat_count` columns
- `diary_entries` — cloud-synced meal log; `(user_id, date)` indexed

Row Level Security is enabled; users can only read/write their own rows.

### UI / Theming

All colours are in `lib/theme.dart` as `CLColors` static constants (e.g. `CLColors.accent` = orange `#D07830`, `CLColors.bg` = near-black `#0C0B09`). The theme is fully dark. Never hardcode colours in widgets.

### Pricing / Localisation

`lib/utils/pricing.dart` uses `Platform.localeName` to detect country and return localised subscription price (e.g. ZAR for South Africa, USD fallback). The `PricingInfo` map covers ZA, NG, KE, GH, EG, TZ, UG, GB, DE, FR, CA, BR, AU, NZ, IN, SG, AE, MX, US. Upgrade modal and Settings screen both read from `getLocalPricing()`.

---

## Key Decisions & Constraints

- **Windows file locking:** Gradle daemons frequently lock `build/app/intermediates/assets/debug/mergeDebugAssets` on Windows. The fix is always: kill Java processes → delete `build/` → re-run. Restarting the PC is the nuclear option.
- **No `supabase_flutter` URL property on client:** Use `SupabaseConfig.supabaseUrl` (the constant) not `SupabaseService.client.supabaseUrl` — the latter doesn't exist in v2 of the library.
- **Google Sign-In configured:** OAuth set up in Google Cloud Console (project `refined-legend-330812`). Android client (SHA-1 debug key), Web client (for Supabase), and `google-services.json` at `android/app/`. Google provider enabled in Supabase Auth. OAuth consent screen is in "Testing" mode — only `makhuvhap.c@gmail.com` is whitelisted as a test user. To add more testers or go live, visit Google Cloud Console → Google Auth Platform → Audience.
- **iOS not yet configured:** Requires Apple Developer Program enrolment ($99/year). iOS build from Codemagic produces an unsigned `Runner.app.zip` that cannot run on a real device.
- **Email confirmation:** Supabase has email confirmation enabled by default. Disable it in Supabase Dashboard → Authentication → Providers → Email → toggle off "Confirm email" for better UX.
- **Scan limit display in ScanScreen:** The header pill shows `scansRemainingToday` for signed-in users, "BYOK" for API key users, "Guest" for unauthenticated — it uses `state.isSignedIn` and `state.hasApiKey`.
- **`unawaited()` helper:** Defined at the bottom of `app_state.dart`. Used for all fire-and-forget cloud sync calls to prevent unhandled Future exceptions from crashing the UI.

---

## Supabase Configuration

Credentials are in `lib/services/supabase_service.dart` (`SupabaseConfig` class). The project URL is `https://qjyxdapbuszjtguyrtdk.supabase.co`. The anon key is already populated.

Edge Functions require the `ANTHROPIC_API_KEY` secret set in Supabase Dashboard → Edge Functions → Secrets.

---

## Pending Work (as of last session)

1. ~~**Google Sign-In setup**~~ — ✅ DONE.
2. ~~**Disable Supabase email confirmation**~~ — ✅ DONE.
3. ~~**End-to-end test**~~ — ✅ DONE. AI scan works via Edge Functions.
4. ~~**Push to GitHub → Codemagic rebuild**~~ — ✅ DONE. Nav restructure, settings cleanup, bug fixes all pushed.
5. ~~**Clean up duplicate Web client secret**~~ — ✅ DONE. Old secret (`****kzYw`) deleted.
6. ~~**In-app purchases**~~ — ✅ DONE. Uses `in_app_purchase` package with Google Play Billing. PurchaseService singleton manages subscription lifecycle. Product ID: `calorielens_pro_monthly`. Needs subscription created in Google Play Console to go live.
7. ~~**Barcode scanning**~~ — ✅ DONE. Uses `mobile_scanner` + Open Food Facts API with AI fallback.
8. ~~**Dead code cleanup**~~ — ✅ DONE. `workout_screen.dart` and `data/exercises.dart` deleted.

### Recent Changes (April 2026)
- Restructured bottom nav from 5 tabs to 4: Scan · Today · Coach · Meals
- Trends accessible from Today screen via "Weekly Trends" button
- Removed Workout tab and Workout Library from Settings
- API Key section hidden behind collapsible "Advanced / Developer" toggle in Settings
- Fixed overflow bugs (Wrap instead of Row for tag chips, Expanded for diary entries)
- Fixed scan count to use AppState.scansRemainingToday (unified source of truth)
- Scan limit pill shows "Unlimited" for Pro/BYOK users instead of "999 left"
- Added "Clear all" button for bulk-deleting diary entries

### Recent Changes (May 2026)
- Fixed model IDs: vision scans now use `claude-sonnet-4-6`, text/chat use `claude-haiku-4-5-20251001`
- Simplified edit flow: "Correct" button lets users fix food item names, then AI re-analyses nutrition (no manual calorie/macro editing)
- Fixed keyboard overlapping edit sheet (SingleChildScrollView + correct BuildContext for viewInsets)
- Fixed gallery image picker crash (added maxWidth/maxHeight + retrieveLostData for Android activity restart)
- Added barcode scanning: third mode in Scan tab (Photo / Describe / Barcode), uses Open Food Facts API for nutrition lookup, falls back to AI estimation if product not found
- Added Google Play Billing integration: `in_app_purchase` package, `PurchaseService` singleton in `lib/services/purchase_service.dart`, upgrade modal triggers real purchase flow, Settings links to Play Store subscription management, restore purchases support added
- Codemagic pre-build script now decodes a release keystore (base64 env var) and imports it as debug.keystore for consistent Google Sign-In SHA-1 across builds
- Fixed ZA pricing from R79.99 to R48.99 in `lib/utils/pricing.dart`
- Removed Advanced/Developer section (BYOK API key input) from Settings — backend key management only
- Fixed Contact Us mailto link with proper `Uri()` constructor and `LaunchMode.externalApplication`
- Sign-up flow now properly handles Supabase email confirmation (green info message + switch to sign-in mode)
- Coach responses now rendered as structured section cards (Today's Priority, Recommended Action, etc.)
- Coach tone softened — supportive language, acknowledges incomplete data, non-judgmental
- Weekly Report shows "Just starting" state when < 3 days logged — score hidden, encouraging messaging
- Individual "Log this meal" buttons added to meal plan detail cards (+ icon, logs single meal to diary)
- Pro status messaging: "Pro insights active" on Coach, "Pro · X left today" on Scan, detailed feature list in Settings
- Settings Pro section now shows detailed feature checklist with scan usage instead of icon row
