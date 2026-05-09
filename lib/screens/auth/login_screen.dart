import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_state.dart';
import '../../services/auth_service.dart';
import '../../theme.dart';

/// Full-screen login / sign-up screen.
/// Shows after splash if the user is not signed in.
/// "Continue as Guest" lets them use the app without an account
/// (limited to 3 scans/day via local count, no cloud sync).
///
/// When opened from Settings (onContinueAsGuest == null), defaults to
/// sign-up mode so guests see "Create your free account" first.
class LoginScreen extends StatefulWidget {
  /// Called when the user taps "Continue as Guest".
  /// If null (e.g. when opened from Settings), the button shows "← Go back".
  final VoidCallback? onContinueAsGuest;

  const LoginScreen({super.key, this.onContinueAsGuest});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late bool _isSignUp;
  bool _loading = false;
  bool _pwVisible = false;
  String? _errorMsg;
  String? _infoMsg;

  /// Tracks the type of error for showing contextual action buttons
  _ErrorType? _errorType;

  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  /// Whether this screen was opened from Settings (guest upgrading)
  bool get _isFromSettings => widget.onContinueAsGuest == null;

  @override
  void initState() {
    super.initState();
    // Guests coming from Settings should see sign-up first
    _isSignUp = _isFromSettings;

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text;

    if (email.isEmpty || pw.isEmpty) {
      setState(() {
        _errorMsg = 'Please enter your email and password.';
        _errorType = null;
      });
      return;
    }

    // Basic email format check
    if (!email.contains('@') || !email.contains('.')) {
      setState(() {
        _errorMsg = 'Please enter a valid email address.';
        _errorType = null;
      });
      return;
    }

    // Password length check for sign-up
    if (_isSignUp && pw.length < 6) {
      setState(() {
        _errorMsg = 'Password must be at least 6 characters.';
        _errorType = null;
      });
      return;
    }

    setState(() { _loading = true; _errorMsg = null; _infoMsg = null; _errorType = null; });

    if (_isSignUp) {
      // ── Sign-up flow ──
      final result = await AuthService.signUpWithEmail(email, pw);
      if (!mounted) return;
      setState(() => _loading = false);

      if (result.success) {
        if (result.user == null) {
          // Email confirmation is enabled — user must verify before signing in.
          setState(() {
            _infoMsg = 'Account created! Check your email for a verification link, then sign in below.';
            _isSignUp = false; // Switch to sign-in mode
            _pwCtrl.clear();
            _errorType = null;
          });
        } else {
          // Email confirmation is disabled — user is signed in immediately.
          setState(() {
            _infoMsg = 'Account created! Your meals will now sync.';
          });
          if (mounted) {
            context.read<AppState>().onSignIn();
          }
          // Pop back after a brief moment so user sees the confirmation
          if (mounted && _isFromSettings) {
            await Future.delayed(const Duration(milliseconds: 800));
            if (mounted) Navigator.of(context).pop();
          }
        }
      } else {
        // Determine error type for contextual actions
        final err = result.error ?? 'Something went wrong. Please try again.';
        _ErrorType? type;
        if (err.contains('already has an account')) {
          type = _ErrorType.alreadyRegistered;
        } else if (err.contains('wait a few minutes') || err.contains('Too many')) {
          type = _ErrorType.rateLimit;
        } else if (err.contains('Could not connect') || err.contains('internet')) {
          type = _ErrorType.network;
        }
        setState(() {
          _errorMsg = err;
          _errorType = type;
        });
      }
    } else {
      // ── Sign-in flow ──
      final result = await AuthService.signInWithEmail(email, pw);
      if (!mounted) return;
      setState(() => _loading = false);

      if (result.success) {
        if (mounted && _isFromSettings) {
          Navigator.of(context).pop();
        }
      } else {
        final err = result.error ?? 'Something went wrong. Please try again.';
        _ErrorType? type;
        if (err.contains('confirm your email')) {
          type = _ErrorType.emailNotConfirmed;
        } else if (err.contains('Could not connect') || err.contains('internet')) {
          type = _ErrorType.network;
        }
        setState(() {
          _errorMsg = err;
          _errorType = type;
        });
      }
    }
  }

  Future<void> _googleSignIn() async {
    setState(() { _loading = true; _errorMsg = null; _infoMsg = null; _errorType = null; });
    final result = await AuthService.signInWithGoogle();
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      if (mounted && _isFromSettings) {
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        _errorMsg = result.error;
        _errorType = null;
      });
    }
  }

  void _continueAsGuest() {
    if (widget.onContinueAsGuest != null) {
      widget.onContinueAsGuest!.call();
    } else {
      Navigator.pop(context);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_isFromSettings)
                  _buildBackButton()
                else
                  const SizedBox(height: 32),
                _buildLogo(),
                const SizedBox(height: 36),
                _buildHeadline(),
                const SizedBox(height: 28),
                _buildEmailField(),
                const SizedBox(height: 14),
                _buildPasswordField(),
                const SizedBox(height: 6),
                if (!_isSignUp) _buildForgotPassword(),
                const SizedBox(height: 22),
                if (_errorMsg != null) ...[
                  _buildErrorCard(_errorMsg!),
                  const SizedBox(height: 14),
                ],
                if (_infoMsg != null) ...[
                  _buildMessage(_infoMsg!, isError: false),
                  const SizedBox(height: 14),
                ],
                _buildSubmitButton(),
                const SizedBox(height: 16),
                _buildDivider(),
                const SizedBox(height: 16),
                _buildGoogleButton(),
                const SizedBox(height: 28),
                _buildToggleRow(),
                const SizedBox(height: 36),
                _buildGuestOption(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Back button (when opened from Settings) ────────────────────────────
  Widget _buildBackButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Row(
          children: const [
            Icon(Icons.arrow_back_ios, size: 16, color: CLColors.muted),
            SizedBox(width: 4),
            Text('Back to Settings', style: TextStyle(color: CLColors.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE07B39), Color(0xFF8B4513)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: CLColors.accent.withOpacity(0.4),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        RichText(
          text: const TextSpan(
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: CLColors.text),
            children: [
              TextSpan(text: 'Calorie'),
              TextSpan(
                text: 'Lens',
                style: TextStyle(color: CLColors.accent, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    String title;
    String subtitle;

    if (_isSignUp) {
      title = _isFromSettings ? 'Create your free account' : 'Create your account';
      subtitle = _isFromSettings
          ? 'Sync your meals across devices and unlock ${AppState.freeScanLimit} AI scans/day'
          : 'Sign up for free — ${AppState.freeScanLimit} AI scans/day included';
    } else {
      title = 'Welcome back';
      subtitle = 'Sign in to sync your meals and unlock AI features';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: CLColors.text,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: CLColors.muted, fontSize: 13, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailCtrl,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      style: const TextStyle(color: CLColors.text),
      decoration: const InputDecoration(
        hintText: 'Email address',
        prefixIcon: Icon(Icons.email_outlined, size: 18, color: CLColors.muted),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _pwCtrl,
      obscureText: !_pwVisible,
      autofillHints: _isSignUp
          ? const [AutofillHints.newPassword]
          : const [AutofillHints.password],
      style: const TextStyle(color: CLColors.text),
      decoration: InputDecoration(
        hintText: _isSignUp ? 'Create a password (min. 6 chars)' : 'Password',
        prefixIcon: const Icon(Icons.lock_outline, size: 18, color: CLColors.muted),
        suffixIcon: IconButton(
          icon: Icon(
            _pwVisible ? Icons.visibility_off : Icons.visibility,
            size: 18,
            color: CLColors.muted,
          ),
          onPressed: () => setState(() => _pwVisible = !_pwVisible),
        ),
      ),
      onSubmitted: (_) => _submit(),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: () async {
          final email = _emailCtrl.text.trim();
          if (email.isEmpty) {
            setState(() {
              _errorMsg = 'Enter your email above first.';
              _errorType = null;
            });
            return;
          }
          setState(() { _loading = true; _errorMsg = null; _infoMsg = null; _errorType = null; });
          final r = await AuthService.sendPasswordReset(email);
          if (mounted) {
            setState(() {
              _loading = false;
              _infoMsg = r.error;
            });
          }
        },
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Forgot password?', style: TextStyle(color: CLColors.muted, fontSize: 12)),
      ),
    );
  }

  // ── Error card with contextual action buttons ──────────────────────────
  Widget _buildErrorCard(String msg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CLColors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CLColors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            msg,
            style: const TextStyle(color: CLColors.red, fontSize: 13, height: 1.4),
          ),
          // Contextual action buttons based on error type
          if (_errorType != null) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _buildErrorActions(),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildErrorActions() {
    switch (_errorType) {
      case _ErrorType.alreadyRegistered:
        return [
          _errorActionChip('Sign in instead', () {
            setState(() {
              _isSignUp = false;
              _errorMsg = null;
              _errorType = null;
              _pwCtrl.clear();
            });
          }),
          _errorActionChip('Continue with Google', _googleSignIn),
        ];
      case _ErrorType.rateLimit:
        return [
          _errorActionChip('Continue with Google', _googleSignIn),
          _errorActionChip('Try again later', () {
            setState(() { _errorMsg = null; _errorType = null; });
          }),
        ];
      case _ErrorType.network:
        return [
          _errorActionChip('Try again', () {
            setState(() { _errorMsg = null; _errorType = null; });
            _submit();
          }),
        ];
      case _ErrorType.emailNotConfirmed:
        return [
          _errorActionChip('Resend confirmation', () async {
            final email = _emailCtrl.text.trim();
            if (email.isEmpty) return;
            setState(() { _loading = true; _errorMsg = null; _errorType = null; });
            // Use password reset as a proxy to trigger email
            await AuthService.sendPasswordReset(email);
            if (mounted) {
              setState(() {
                _loading = false;
                _infoMsg = 'Confirmation email resent. Check your inbox.';
              });
            }
          }),
          _errorActionChip('Continue with Google', _googleSignIn),
        ];
      default:
        return [];
    }
  }

  Widget _errorActionChip(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: CLColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(color: CLColors.accent, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildMessage(String msg, {required bool isError}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError ? CLColors.red.withOpacity(0.08) : CLColors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? CLColors.red.withOpacity(0.3) : CLColors.green.withOpacity(0.3),
        ),
      ),
      child: Text(
        msg,
        style: TextStyle(
          color: isError ? CLColors.red : CLColors.green,
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _loading ? null : _submit,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
        ),
        child: _loading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(
                _isSignUp ? 'CREATE FREE ACCOUNT' : 'SIGN IN',
                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: CLColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or', style: const TextStyle(color: CLColors.muted, fontSize: 12)),
        ),
        const Expanded(child: Divider(color: CLColors.border)),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loading ? null : _googleSignIn,
        icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: CLColors.text)),
        label: const Text(
          'Continue with Google',
          style: TextStyle(color: CLColors.text, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: CLColors.border),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildToggleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isSignUp ? 'Already have an account?' : 'No account yet?',
          style: const TextStyle(color: CLColors.muted, fontSize: 13),
        ),
        TextButton(
          onPressed: () => setState(() {
            _isSignUp = !_isSignUp;
            _errorMsg = null;
            _infoMsg = null;
            _errorType = null;
          }),
          child: Text(
            _isSignUp ? 'Sign in' : 'Create one free',
            style: const TextStyle(color: CLColors.accent, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestOption() {
    return Center(
      child: Column(
        children: [
          Text(
            _isFromSettings
                ? 'You can always sign up later'
                : 'No account needed to get started',
            style: const TextStyle(color: CLColors.muted2, fontSize: 12),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _continueAsGuest,
            child: Text(
              _isFromSettings ? '← Go back' : 'Continue as Guest  →',
              style: const TextStyle(color: CLColors.muted, fontSize: 13),
            ),
          ),
          if (!_isFromSettings)
            const Text(
              '${AppState.guestScanLimit} free AI scans/day · no sync',
              style: TextStyle(color: CLColors.muted2, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

/// Error types for contextual action suggestions
enum _ErrorType {
  alreadyRegistered,
  rateLimit,
  network,
  emailNotConfirmed,
}
