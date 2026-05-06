import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'anthropic_service.dart';
import 'supabase_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// BackendService — the single entry point for all AI requests.
///
/// Decision tree on each request:
///   1. If user has a BYOK (bring-your-own-key) API key in Settings
///      → call Anthropic directly (they pay their own costs, no limits)
///   2. Otherwise → proxy through our Supabase Edge Functions
///      • Rate limits enforced server-side (10 scans/day, 15 chats/day)
///      • Returns 429 with a user-friendly message if limit hit
/// ─────────────────────────────────────────────────────────────────────────────
class BackendService {
  final String? byokApiKey;

  BackendService({this.byokApiKey});

  bool get _useByok => byokApiKey != null && byokApiKey!.isNotEmpty;

  String get _functionsBaseUrl =>
      '${SupabaseConfig.supabaseUrl}/functions/v1';

  Map<String, String> get _authHeaders {
    final session = SupabaseService.currentSession;
    return {
      'Content-Type': 'application/json',
      if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
    };
  }

  // ── Scan image ───────────────────────────────────────────────────────────
  Future<ScanResult> scanImage(Uint8List imageBytes, String mediaType) async {
    if (_useByok) {
      return AnthropicService(byokApiKey!).scanImage(imageBytes, mediaType);
    }
    _requireSignIn();

    final res = await http.post(
      Uri.parse('$_functionsBaseUrl/scan-image'),
      headers: _authHeaders,
      body: jsonEncode({
        'imageBase64': base64Encode(imageBytes),
        'mediaType': mediaType,
      }),
    ).timeout(const Duration(seconds: 30));

    return _parseScanResponse(res);
  }

  // ── Scan text ────────────────────────────────────────────────────────────
  Future<ScanResult> scanText(String description) async {
    if (_useByok) {
      return AnthropicService(byokApiKey!).scanText(description);
    }
    _requireSignIn();

    final res = await http.post(
      Uri.parse('$_functionsBaseUrl/scan-text'),
      headers: _authHeaders,
      body: jsonEncode({'description': description}),
    ).timeout(const Duration(seconds: 30));

    return _parseScanResponse(res);
  }

  // ── Generate meal plan ────────────────────────────────────────────────
  Future<Map<String, dynamic>> generateMealPlan({
    required int calorieGoal,
    required String budgetTier,
    String? dietaryPreference,
    String? profileContext,
  }) async {
    if (_useByok) {
      return AnthropicService(byokApiKey!).generateMealPlan(
        calorieGoal: calorieGoal,
        budgetTier: budgetTier,
        dietaryPreference: dietaryPreference,
        profileContext: profileContext,
      );
    }
    _requireSignIn();

    final res = await http.post(
      Uri.parse('$_functionsBaseUrl/generate-plan'),
      headers: _authHeaders,
      body: jsonEncode({
        'calorieGoal': calorieGoal,
        'budgetTier': budgetTier,
        'dietaryPreference': dietaryPreference,
        'profileContext': profileContext,
      }),
    ).timeout(const Duration(seconds: 30));

    _checkRateLimit(res, isScan: false);
    _checkSuccess(res);
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ── Scan fridge ─────────────────────────────────────────────────────
  Future<List<String>> scanFridge(Uint8List imageBytes, String mediaType) async {
    if (_useByok) {
      return AnthropicService(byokApiKey!).scanFridge(imageBytes, mediaType);
    }
    _requireSignIn();

    final res = await http.post(
      Uri.parse('$_functionsBaseUrl/scan-image'),
      headers: _authHeaders,
      body: jsonEncode({
        'imageBase64': base64Encode(imageBytes),
        'mediaType': mediaType,
        'mode': 'fridge', // tells the Edge Function to use fridge prompt
      }),
    ).timeout(const Duration(seconds: 30));

    _checkRateLimit(res, isScan: true);
    _checkSuccess(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['ingredients'] as List).map((e) => e.toString()).toList();
  }

  // ── Coach chat ───────────────────────────────────────────────────────────
  Future<String> chat({
    required List<ChatMessage> history,
    required String userMessage,
    required String systemPrompt,
  }) async {
    if (_useByok) {
      return AnthropicService(byokApiKey!).chat(
        history: history,
        userMessage: userMessage,
        systemPrompt: systemPrompt,
      );
    }
    _requireSignIn();

    final res = await http.post(
      Uri.parse('$_functionsBaseUrl/chat'),
      headers: _authHeaders,
      body: jsonEncode({
        'history': history.map((m) => {'role': m.role, 'content': m.content}).toList(),
        'userMessage': userMessage,
        'systemPrompt': systemPrompt,
      }),
    ).timeout(const Duration(seconds: 30));

    _checkRateLimit(res, isScan: false);
    _checkSuccess(res);

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['response'] as String? ?? '';
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  void _requireSignIn() {
    if (!SupabaseService.isSignedIn) {
      throw Exception(
        'Please sign in to use AI features, or add your own API key in Settings → API Key.',
      );
    }
  }

  ScanResult _parseScanResponse(http.Response res) {
    _checkRateLimit(res, isScan: true);
    _checkSuccess(res);
    final parsed = jsonDecode(res.body) as Map<String, dynamic>;
    return ScanResult.fromJson(parsed);
  }

  void _checkRateLimit(http.Response res, {required bool isScan}) {
    if (res.statusCode == 429) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(data['error'] ?? _defaultLimitMessage(isScan));
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception(_defaultLimitMessage(isScan));
      }
    }
  }

  void _checkSuccess(http.Response res) {
    if (res.statusCode != 200) {
      try {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        throw Exception(data['error'] ?? 'Server error ${res.statusCode}');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Server error ${res.statusCode}');
      }
    }
  }

  String _defaultLimitMessage(bool isScan) => isScan
      ? 'You\'ve used all 10 free scans for today. Upgrade to Pro for unlimited scanning.'
      : 'You\'ve used all 15 free coach messages for today. Upgrade to Pro for unlimited coaching.';
}
