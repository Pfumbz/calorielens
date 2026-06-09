import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'theme.dart';
import 'app_state.dart';
import 'screens/scan_screen.dart';
import 'screens/today_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/meal_plans_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize local storage first (needed by AppState)
  await StorageService().init();

  // Run remaining inits in parallel for faster startup
  await Future.wait([
    // Supabase (no-ops gracefully if credentials are placeholders)
    SupabaseService.initialize().catchError((_) {}),
    // Local notifications
    NotificationService.init(),
    // Google Mobile Ads
    MobileAds.instance.initialize(),
  ]);

  // H-1: init() is async — await it before runApp so the first frame has real
  // data (diary, premium state, API key) rather than default values.
  final appState = AppState();
  await appState.init();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const CalNovaApp(),
    ),
  );
}

class CalNovaApp extends StatelessWidget {
  const CalNovaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalNova',
      theme: buildTheme(),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ─── SPLASH SCREEN ────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _ctrl.forward();

    // Navigate to shell after 1.4s
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthGate(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: CLColors.accent.withOpacity(0.45),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/logo.png', width: 88, height: 88),
                  ),
                ),
                const SizedBox(height: 22),
                // App name
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      color: CLColors.text,
                      letterSpacing: 0.5,
                    ),
                    children: [
                      TextSpan(text: 'Cal'),
                      TextSpan(
                        text: 'Nova',
                        style: TextStyle(
                          color: CLColors.accent,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'AI Nutrition Companion',
                  style: TextStyle(
                    color: CLColors.muted,
                    fontSize: 13,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AUTH GATE ────────────────────────────────────────────────────────────────
/// Listens to Supabase auth state and routes accordingly.
/// • Signed in (real or anonymous) → AppShell
/// • Not signed in → LoginScreen (with "Continue as Guest")
/// • Guest tapped → anonymous sign-in → AppShell (3 scans/day)
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _signInHandled = false;
  bool _recoveryDialogShown = false;

  Future<void> _handleGuestMode() async {
    try {
      await SupabaseService.signInAnonymously();
      // The auth stream will pick up the new session and route to AppShell
    } catch (e) {
      debugPrint('Anonymous sign-in failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: SupabaseService.authStateChanges,
      builder: (context, snapshot) {
        // H-4: Show a neutral loading scaffold while the auth stream initialises.
        // Previously returned AppShell, which exposed the full UI to unauthenticated
        // users during the brief connection-waiting window.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: CLColors.bg,
            body: Center(
              child: CircularProgressIndicator(
                color: CLColors.accent,
                strokeWidth: 2,
              ),
            ),
          );
        }

        // Check for password recovery event
        final data = snapshot.data;
        if (data != null && data.event == AuthChangeEvent.passwordRecovery && !_recoveryDialogShown) {
          _recoveryDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showPasswordResetDialog(context);
          });
        }

        final isSignedIn = SupabaseService.isSignedIn;

        if (isSignedIn) {
          // Trigger cloud sync only once per sign-in session
          if (!_signInHandled) {
            _signInHandled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.read<AppState>().onSignIn();
            });
          }
          return const AppShell();
        }

        // User signed out — reset guard so next sign-in triggers sync
        _signInHandled = false;
        _recoveryDialogShown = false;

        // Show login screen — guest callback triggers anonymous sign-in
        return LoginScreen(
          onContinueAsGuest: _handleGuestMode,
        );
      },
    );
  }

  void _showPasswordResetDialog(BuildContext context) {
    final pwCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool loading = false;
    String? error;
    bool obscure = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: CLColors.surface2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Set your new password',
                style: TextStyle(color: CLColors.text, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose a new password for your account.',
                    style: TextStyle(color: CLColors.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: pwCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: CLColors.text),
                    decoration: InputDecoration(
                      hintText: 'New password (min. 6 chars)',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18, color: CLColors.muted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure ? Icons.visibility_off : Icons.visibility,
                          size: 18, color: CLColors.muted,
                        ),
                        onPressed: () => setDialogState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: obscure,
                    style: const TextStyle(color: CLColors.text),
                    decoration: const InputDecoration(
                      hintText: 'Confirm new password',
                      prefixIcon: Icon(Icons.lock_outline, size: 18, color: CLColors.muted),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: const TextStyle(color: CLColors.red, fontSize: 12)),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: loading ? null : () {
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Cancel', style: TextStyle(color: CLColors.muted)),
                ),
                ElevatedButton(
                  onPressed: loading ? null : () async {
                    final pw = pwCtrl.text;
                    final confirm = confirmCtrl.text;

                    if (pw.length < 6) {
                      setDialogState(() => error = 'Password must be at least 6 characters.');
                      return;
                    }
                    if (pw != confirm) {
                      setDialogState(() => error = 'Passwords do not match.');
                      return;
                    }

                    setDialogState(() { loading = true; error = null; });

                    try {
                      await SupabaseService.client.auth.updateUser(
                        UserAttributes(password: pw),
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Password updated successfully!'),
                            backgroundColor: CLColors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      setDialogState(() {
                        loading = false;
                        error = 'Failed to update password. Please try again.';
                      });
                    }
                  },
                  child: loading
                      ? const SizedBox(
                          height: 16, width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Update Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ─── APP SHELL ────────────────────────────────────────────────────────────────
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  /// Set true when the installed build is below the server's minimum supported
  /// build. Fails open: any error / offline leaves the app usable.
  bool _updateRequired = false;

  @override
  void initState() {
    super.initState();
    _checkMinVersion();
  }

  Future<void> _checkMinVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final current = int.tryParse(info.buildNumber) ?? 0;
      final min = await SupabaseService.fetchMinSupportedBuild();
      if (min != null && current > 0 && current < min && mounted) {
        setState(() => _updateRequired = true);
      }
    } catch (_) {
      // fail open — never lock a user out due to a config/network error
    }
  }

  static const _screens = [
    ScanScreen(),
    TodayScreen(),
    CoachScreen(),
    MealPlansScreen(),
    SettingsScreen(),
  ];

  static const _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.camera_alt_outlined),
      activeIcon: Icon(Icons.camera_alt),
      label: 'Scan',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.bar_chart_outlined),
      activeIcon: Icon(Icons.bar_chart),
      label: 'Today',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.smart_toy_outlined),
      activeIcon: Icon(Icons.smart_toy),
      label: 'Coach',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.restaurant_menu_outlined),
      activeIcon: Icon(Icons.restaurant_menu),
      label: 'Meals',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (_updateRequired) return const ForceUpdateScreen();
    return PopScope(
      // Always intercept back — statics like ScanScreen.isOnPhotoMode can
      // change without triggering an AppShell rebuild, so canPop must stay
      // false to guarantee onPopInvokedWithResult always fires.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Priority 1: If scan results are showing, clear them first
        if (_currentIndex == 0 && ScanScreen.hasResult) {
          ScanScreen.clearResult?.call();
        }
        // Priority 2: If on Scan tab but not on Photo mode, go back to Photo
        else if (_currentIndex == 0 && !ScanScreen.isOnPhotoMode) {
          ScanScreen.resetToPhotoMode?.call();
        }
        // Priority 3: If on Coach tab with active chat, clear chat first
        else if (_currentIndex == 2 && CoachScreen.hasChatMessages) {
          CoachScreen.clearChat?.call();
        }
        // Priority 4: Any non-Scan tab → go back to Scan
        else if (_currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
        // Priority 5: On Scan tab, Photo mode, no results → exit app
        else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2820))),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: _navItems,
        ),
      ),
    ),
    );
  }
}

// ─── FORCE UPDATE SCREEN ──────────────────────────────────────────────────────
/// Blocking screen shown when the installed build is below the server-configured
/// minimum supported build (`app_config.min_supported_build`). Used to retire
/// older versions whose purchase flow predates server-side entitlement.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  static const _packageId = 'com.pcmacstudios.calorielens';

  Future<void> _openStore() async {
    // Prefer the Play Store app; fall back to the web listing.
    final market = Uri.parse('market://details?id=$_packageId');
    final web = Uri.parse(
        'https://play.google.com/store/apps/details?id=$_packageId');
    if (!await launchUrl(market, mode: LaunchMode.externalApplication)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 64, color: CLColors.accent),
                const SizedBox(height: 24),
                const Text(
                  'Update required',
                  style: TextStyle(
                    color: CLColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A newer version of CalNova is available with important '
                  'improvements. Please update to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CLColors.muted, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openStore,
                    icon: const Icon(Icons.shop, size: 18),
                    label: const Text('Update now',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CLColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
