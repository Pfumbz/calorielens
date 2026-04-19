import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'supabase_service.dart';

/// Result wrapper for auth operations.
class AuthResult {
  final bool success;
  final String? error;
  final User? user;

  AuthResult({required this.success, this.error, this.user});
}

/// ─────────────────────────────────────────────────────────────────────────────
/// AuthService — handles sign-up, sign-in, Google OAuth, and sign-out.
///
/// GOOGLE SIGN-IN SETUP:
///   1. Go to console.cloud.google.com → create OAuth 2.0 credentials
///   2. Add your Android SHA-1 fingerprint (run: keytool -list -v -keystore
///      ~/.android/debug.keystore -alias androiddebugkey -storepass android)
///   3. Copy the Web client ID and paste it as webClientId below
///   4. In Supabase Dashboard → Authentication → Providers → Google:
///      Enable it and paste the same Web client ID + Secret
/// ─────────────────────────────────────────────────────────────────────────────
class AuthService {
  static final _client = SupabaseService.client;

  // Google OAuth Web Client ID (from Google Cloud Console, project: refined-legend-330812)
  static const _googleWebClientId = '1053726882620-r90gu6qi0854d314rurligsnemks6qme.apps.googleusercontent.com';

  // ── Email / Password ─────────────────────────────────────────────────────
  static Future<AuthResult> signUpWithEmail(
    String email,
    String password,
  ) async {
    try {
      final res = await _client.auth.signUp(email: email, password: password);
      if (res.user != null) {
        return AuthResult(success: true, user: res.user);
      }
      // Email confirmation required
      return AuthResult(
        success: true,
        user: null,
        error: 'Check your email for a confirmation link.',
      );
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  static Future<AuthResult> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return AuthResult(success: true, user: res.user);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  // ── Google Sign-In ────────────────────────────────────────────────────────
  static Future<AuthResult> signInWithGoogle() async {
    try {
      // Disconnect any previous session to ensure a clean sign-in
      final googleSignIn = GoogleSignIn(serverClientId: _googleWebClientId);
      try { await googleSignIn.signOut(); } catch (_) {}

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return AuthResult(success: false, error: 'Sign-in cancelled.');
      }

      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null || accessToken == null) {
        return AuthResult(
          success: false,
          error: 'Could not retrieve Google credentials. '
              'Please check your internet connection and try again.',
        );
      }

      final res = await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      return AuthResult(success: true, user: res.user);
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // Error code 10 = DEVELOPER_ERROR: SHA-1 fingerprint not registered
      if (msg.contains('10') || msg.contains('developer_error')) {
        return AuthResult(
          success: false,
          error: 'Google Sign-In is not configured yet. '
              'The app\'s SHA-1 fingerprint needs to be registered in Google Cloud Console.',
        );
      }
      // Error code 12500 = sign-in attempt failed
      if (msg.contains('12500')) {
        return AuthResult(
          success: false,
          error: 'Google Sign-In failed. Please make sure Google Play Services is up to date.',
        );
      }
      // Network errors
      if (msg.contains('network') || msg.contains('timeout') || msg.contains('socket')) {
        return AuthResult(
          success: false,
          error: 'No internet connection. Check your network and try again.',
        );
      }
      return AuthResult(success: false, error: 'Google Sign-In failed: ${e.toString()}');
    }
  }

  // ── Sign out ────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    // Sign out of Google first (if signed in via Google)
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _client.auth.signOut();
  }

  // ── Password reset ──────────────────────────────────────────────────────
  static Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return AuthResult(
        success: true,
        error: 'Password reset email sent. Check your inbox.',
      );
    } on AuthException catch (e) {
      return AuthResult(success: false, error: _friendlyError(e.message));
    } catch (e) {
      return AuthResult(success: false, error: e.toString());
    }
  }

  // ── Error messages ──────────────────────────────────────────────────────
  static String _friendlyError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('invalid login')) return 'Incorrect email or password.';
    if (lower.contains('already registered')) return 'An account with this email already exists.';
    if (lower.contains('password should be')) return 'Password must be at least 6 characters.';
    if (lower.contains('invalid email')) return 'Please enter a valid email address.';
    if (lower.contains('email not confirmed')) return 'Please confirm your email before signing in.';
    if (lower.contains('network')) return 'No internet connection. Check your network and try again.';
    return raw;
  }
}
