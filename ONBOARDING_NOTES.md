# Onboarding — Diagnosis & Plan (next project)

**Status:** investigation only, no code changed. Saved for the next session.
**Why this matters:** Growth audit + production DB confirm it's the #1 issue —
106 of 111 users sit on the default 2,000-calorie goal, only 4 have weight/height,
and all 111 are recorded as sex = male. The app's "personalised AI tracking"
promise is never delivered at setup, which is the biggest driver of low activation
and retention.

---

## What the current flow actually does

1. **No first-run onboarding exists.** App flow is: Splash → Login / "Continue as
   guest" → straight into the main app (`AppShell`). New users are never asked
   height, weight, age, sex, activity, or goal.

2. **Onboarding flags are dead code.** `StorageService.isOnboarded` /
   `setOnboarded()` exist but are never read or set anywhere. No setup step gates
   the app.

3. **Profile capture is hidden.** The only entry point is the "Edit Profile"
   bottom sheet (`lib/widgets/profile_sheet.dart` → `showProfileSheet()`),
   reachable from just:
   - Settings (`settings_screen.dart`, manual tap), and
   - A dismissible nudge card on Today (`_ProfileNudgeCard`) that only appears
     **after the user has already logged ≥2 meals** (`_shouldShowProfileNudge`).
   - Catch-22: the nudge only reaches already-engaged users, but most users never
     log anything, so they never see it.

4. **The profile sheet is incomplete.** It collects only **name, age, weight,
   height**. It does NOT collect **sex** or **activity level**, yet the calorie
   formula uses both:
   ```
   bmr = sex == 'm' ? 10*kg + 6.25*cm - 5*age + 5
                    : 10*kg + 6.25*cm - 5*age - 161   // Mifflin-St Jeor
   tdee = bmr * activity            // activity defaults to 1.55, never editable
   goal = round(tdee)
   ```
   So sex is permanently "male" (matches DB: 111/111 male) and activity is a fixed
   default → even completed profiles get a partly-wrong target. There is also no
   **goal direction** (lose / maintain / gain), which users expect most.

5. **Goal only computes when age, weight, height are all > 0** — i.e. only after
   the hidden sheet is filled. Otherwise it stays at the 2,000 default
   (`StorageService.calorieGoal` default).

## What already exists and can be reused

- `UserProfile` model (name, age, weight, height, sex, activity, calorieGoal).
- Mifflin-St Jeor BMR + TDEE math (in `profile_sheet.dart`).
- Cloud sync of profile (`AppState.saveProfile` / `saveCalorieGoal` →
  `SupabaseService.updateProfile`).
- `NotificationService.scheduleNudges` (for later: day-2 reminders / streaks).

## Plan for the onboarding build (when ready)

1. **New first-run flow after sign-in/guest**, gated by a *working* `isOnboarded`
   flag (wire it in `AuthGate`/`AppShell`). Show once; revisitable from Settings.
2. **Capture the full set:** sex, age, height, weight, activity level (with
   plain-language options, not a raw 1.55), and **goal direction** (lose /
   maintain / gain) + optional rate.
3. **Compute the personalised goal** (reuse the BMR/TDEE math; apply a deficit/
   surplus for the goal direction) and save profile + goal, synced to cloud.
4. **Front-load the AI "win":** let guests reach one successful scan quickly;
   keep onboarding short and skippable so it doesn't become a wall (activation
   risk). Consider: scan first, then ask profile right after the first result.
5. **Backfill existing users:** show the onboarding/profile prompt to the 106 on
   the default goal on their next open (one-time), so current users also benefit.
6. **Later (separate):** day-2 retention loop (reminders + streaks), in-app
   review prompt after a positive moment, free trial + annual plan at a value
   moment — all called out in the growth audit.

## Files involved

- `lib/main.dart` — `AuthGate` / `AppShell` (where the onboarding gate goes)
- `lib/widgets/profile_sheet.dart` — existing profile capture + BMR/TDEE math
- `lib/services/storage_service.dart` — `isOnboarded`, `calorieGoal`, profile
- `lib/app_state.dart` — `saveProfile`, `saveCalorieGoal`, profile getters
- `lib/models/models.dart` — `UserProfile`
- `lib/screens/today_screen.dart` — `_ProfileNudgeCard` (can retire once real
  onboarding exists)
