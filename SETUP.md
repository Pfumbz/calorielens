# CalorieLens — Flutter Setup Guide

## Step 1 — Install Flutter SDK (if not already done)

1. Go to https://docs.flutter.dev/get-started/install/windows
2. Download the Flutter SDK zip
3. Extract to `C:\flutter` (avoid paths with spaces)
4. Add `C:\flutter\bin` to your **System PATH**:
   - Search "Environment Variables" in Start
   - Edit `Path` → New → `C:\flutter\bin`
5. Restart VS Code

## Step 2 — Install VS Code Extensions

Open VS Code and install these two extensions:
- **Flutter** (by Dart Code)
- **Dart** (by Dart Code)

Both install together when you search "Flutter".

## Step 3 — Verify your setup

Open a terminal in VS Code (`Ctrl + ~`) and run:

```bash
flutter doctor
```

Fix any issues it reports (Android Studio / Xcode / device).

## Step 4 — Open this project

In VS Code: **File → Open Folder** → select this `CalorieLens_Flutter` folder.

## Step 5 — Get packages

In the VS Code terminal:

```bash
flutter pub get
```

## Step 6 — Run the app

**Android:**
- Connect your phone via USB with Developer Mode + USB Debugging on
- Or start an Android emulator from VS Code (bottom status bar → device picker)
- Press **F5** or run:
```bash
flutter run
```

**iOS (Mac only):**
```bash
flutter run
```

---

## Project Structure

```
lib/
├── main.dart               ← App entry point & bottom navigation
├── app_state.dart          ← Global state (Provider)
├── theme.dart              ← Dark CalorieLens colour palette
├── models/
│   └── models.dart         ← DiaryEntry, ScanResult, UserProfile, etc.
├── services/
│   ├── storage_service.dart  ← SharedPreferences wrapper
│   └── anthropic_service.dart ← Anthropic API (scan + coach)
├── data/
│   └── exercises.dart      ← All 24 exercises with jsDelivr image URLs
├── screens/
│   ├── scan_screen.dart    ← Photo/text meal scanning
│   ├── today_screen.dart   ← Diary, calorie ring, water, macros
│   ├── trends_screen.dart  ← 7-day bar chart, weekly report
│   ├── coach_screen.dart   ← AI chat with quick prompts
│   ├── workout_screen.dart ← Exercise library + workout player
│   └── settings_screen.dart ← API key, profile, premium
└── widgets/
    └── upgrade_modal.dart  ← Pro upgrade bottom sheet
```

## Features

| Feature | Free | Pro |
|---------|------|-----|
| Meal scanning | 3/day | Unlimited |
| AI coach | ✓ | ✓ Unlimited |
| Workout player | ✓ | ✓ |
| Weekly progress report | ✗ | ✓ |
| Budget coach | ✗ | ✓ |
| Exercise animations (crossfade) | ✓ | ✓ |

## Getting your Anthropic API Key

1. Go to https://console.anthropic.com
2. Sign up / log in
3. Settings → API Keys → Create Key
4. Copy the key (`sk-ant-api03-…`)
5. Paste it in the app under **Settings**

Each meal scan costs ~$0.001. Each coach message ~$0.001.

---

## Common Issues

**`flutter: command not found`**
→ Flutter not in PATH. Re-check Step 1.

**`flutter doctor` shows Android toolchain issues**
→ Install Android Studio and accept SDK licenses:
```bash
flutter doctor --android-licenses
```

**Image picker not working on Android**
→ Make sure you've enabled camera permission on the device when prompted.

**Build fails with "compileSdkVersion"**
→ Open `android/app/build.gradle` and set `compileSdkVersion 34`.
