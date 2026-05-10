import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState()..init(),
      child: const CalorieLensApp(),
    ),
  );
}

class CalorieLensApp extends StatelessWidget {
  const CalorieLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieLens',
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
                // Logo icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE07B39), Color(0xFF8B4513)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: CLColors.accent.withOpacity(0.45),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 40),
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
                      TextSpan(text: 'Calorie'),
                      TextSpan(
                        text: 'Lens',
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
                  'AI-powered nutrition tracking',
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
        // Show AppShell while stream is initializing (avoids flicker)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AppShell();
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
    // Back button can only exit when on Scan tab with no results showing
    final canExitApp = _currentIndex == 0 && !ScanScreen.hasResult;

    return PopScope(
      canPop: canExitApp,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Priority 1: If scan results are showing, clear them first
          if (_currentIndex == 0 && ScanScreen.hasResult) {
            ScanScreen.clearResult?.call();
          }
          // Priority 2: If on Coach tab with active chat, clear chat first
          else if (_currentIndex == 2 && CoachScreen.hasChatMessages) {
            CoachScreen.clearChat?.call();
          }
          // Priority 3: Any non-Scan tab → go back to Scan
          else {
            setState(() => _currentIndex = 0);
          }
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
