import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import 'anthropic_service.dart';
import 'supabase_service.dart';
import 'usda_service.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// BackendService — the single entry point for all AI requests.
///
/// Decision tree on each request:
///   1. If user has a BYOK (bring-your-own-key) API key in Settings
///      → call Anthropic directly (they pay their own costs, no limits)
///   2. Otherwise → proxy through our Supabase Edge Functions
///      • Rate limits enforced server-side (5 scans/day free, 50 Pro; 15 chats/day)
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

  // ── Scan image (supports multi-angle) ────────────────────────────────────
  /// Pass a single image or multiple images for multi-angle scanning.
  /// When two images are provided, the AI uses both angles for better
  /// portion depth estimation.
  Future<ScanResult> scanImage(
    Uint8List imageBytes,
    String mediaType, {
    Uint8List? secondImageBytes,
    String? secondMediaType,
    /// When set, this is a correction retake — the hint is the user's corrected
    /// food description and originalContext holds the prior nutrition estimates.
    String? correctionHint,
    Map<String, dynamic>? originalContext,
  }) async {
    ScanResult aiResult;
    Map<String, dynamic>? rawJson;

    final imageList = [imageBytes, if (secondImageBytes != null) secondImageBytes];
    final mediaList = [mediaType, if (secondMediaType != null) secondMediaType];

    if (_useByok) {
      final (result, raw) = await AnthropicService(byokApiKey!).scanImageWithRaw(
        imageList,
        mediaList,
        correctionHint: correctionHint,
        originalContext: originalContext,
      );
      aiResult = result;
      rawJson = raw;
    } else {
      _requireSignIn();

      // Build payload — supports 1 or 2 images
      final payload = <String, dynamic>{
        'imageBase64': base64Encode(imageBytes),
        'mediaType': mediaType,
      };
      if (secondImageBytes != null) {
        payload['imageBase64_2'] = base64Encode(secondImageBytes);
        payload['mediaType_2'] = secondMediaType ?? 'image/jpeg';
      }
      if (correctionHint != null) payload['correction_hint'] = correctionHint;
      if (originalContext != null) payload['original_context'] = originalContext;

      final res = await http.post(
        Uri.parse('$_functionsBaseUrl/scan-image'),
        headers: _authHeaders,
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 45));

      aiResult = _parseScanResponse(res);
      try {
        rawJson = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Enrich with USDA data (non-blocking — falls back to AI estimates)
    return _enrichWithUsdaFromRaw(aiResult, rawJson);
  }

  // ── Scan text ────────────────────────────────────────────────────────────
  /// [isCorrection] skips the server-side scan counter so corrections
  /// don't consume the user's daily quota.
  /// [originalContext] provides the original scan's nutrition data so the AI
  /// can adjust proportionally rather than estimating from scratch.
  Future<ScanResult> scanText(
    String description, {
    bool isCorrection = false,
    Map<String, dynamic>? originalContext,
  }) async {
    ScanResult aiResult;
    Map<String, dynamic>? rawJson;

    if (_useByok) {
      final (result, raw) = await AnthropicService(byokApiKey!).scanTextWithRaw(
        description,
        originalContext: originalContext,
      );
      aiResult = result;
      rawJson = raw;
    } else {
      _requireSignIn();

      final body = <String, dynamic>{'description': description};
      if (isCorrection) body['is_correction'] = true;
      if (originalContext != null) body['original_context'] = originalContext;

      final res = await http.post(
        Uri.parse('$_functionsBaseUrl/scan-text'),
        headers: _authHeaders,
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));

      aiResult = _parseScanResponse(res);
      try {
        rawJson = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
    }

    // Skip USDA enrichment for corrections (the user is fixing names, not nutrition)
    if (isCorrection) return aiResult;

    return _enrichWithUsdaFromRaw(aiResult, rawJson);
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

  // ── Purchase verification (server-side entitlement) ───────────────────────
  /// Sends the Google Play purchase token to the server, which is the ONLY
  /// party allowed to set `is_premium` (the DB rejects client-side writes).
  /// Returns the server's authoritative premium state. Entitlement is always
  /// server-decided regardless of BYOK.
  Future<bool> verifyPurchase({
    required String purchaseToken,
    required String productId,
  }) async {
    _requireSignIn();
    final res = await http.post(
      Uri.parse('$_functionsBaseUrl/verify-purchase'),
      headers: _authHeaders,
      body: jsonEncode({'purchaseToken': purchaseToken, 'productId': productId}),
    ).timeout(const Duration(seconds: 30));

    _checkSuccess(res);
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['isPremium'] as bool? ?? false;
  }

  // ── USDA enrichment ──────────────────────────────────────────────────────
  /// After an AI scan, look up each food item in USDA FoodData Central and
  /// recalculate nutrition using lab-verified per-100g data × estimated grams.
  /// Falls back to the AI's original estimates if USDA lookup fails.
  ///
  /// [rawJson] is the raw parsed JSON from the AI response, used to extract
  /// the `usda_query` field that the AI provides for better USDA matching.
  Future<ScanResult> _enrichWithUsdaFromRaw(
    ScanResult aiResult,
    Map<String, dynamic>? rawJson,
  ) async {
    // Extract usda_query values from raw JSON items (AI provides these for
    // better USDA matching than the display name)
    final rawItems = (rawJson?['items'] as List?) ?? [];
    final usdaQueries = <int, String>{}; // index → usda_query

    for (int i = 0; i < rawItems.length && i < aiResult.items.length; i++) {
      final raw = rawItems[i] as Map<String, dynamic>?;
      final q = raw?['usda_query'] as String?;
      if (q != null && q.isNotEmpty) {
        usdaQueries[i] = q.toLowerCase().trim();
      }
    }

    // Build lookup list: prefer usda_query, fall back to item name
    final queryToIndices = <String, List<int>>{};
    for (int i = 0; i < aiResult.items.length; i++) {
      final item = aiResult.items[i];
      if (item.weightG == null || item.weightG! <= 0) continue;

      final query = usdaQueries[i] ?? item.name.toLowerCase().trim();
      if (query.isEmpty) continue;
      queryToIndices.putIfAbsent(query, () => []).add(i);
    }

    if (queryToIndices.isEmpty) return aiResult;

    // Look up all unique queries in USDA in parallel
    final usdaResults = await UsdaService.lookupFoods(queryToIndices.keys.toList());

    if (usdaResults.isEmpty) return aiResult;

    // Rebuild items with USDA nutrition data where available
    final enrichedItems = List<FoodItem>.from(aiResult.items);
    int totalCal = 0, totalProtein = 0, totalCarbs = 0, totalFat = 0, totalFiber = 0;
    int usdaCount = 0;

    for (int i = 0; i < aiResult.items.length; i++) {
      final item = aiResult.items[i];
      final query = usdaQueries[i] ?? item.name.toLowerCase().trim();
      final usda = usdaResults[query];

      if (usda != null && item.weightG != null && item.weightG! > 0) {
        // Use USDA data: per-100g values × (weight_g / 100)
        final nutrition = usda.forGrams(item.weightG!);
        enrichedItems[i] = item.copyWith(
          calories: nutrition['calories']!,
          source: 'usda',
          note: item.note.isEmpty
              ? 'USDA verified'
              : '${item.note} · USDA verified',
        );
        totalCal += nutrition['calories']!;
        totalProtein += nutrition['protein']!;
        totalCarbs += nutrition['carbs']!;
        totalFat += nutrition['fat']!;
        totalFiber += nutrition['fiber']!;
        usdaCount++;
      } else {
        // Keep AI estimate as fallback
        totalCal += item.calories;
        // Proportionally attribute macros from original totals
        final calShare = aiResult.totalCalories == 0
            ? 0.0
            : item.calories / aiResult.totalCalories;
        totalProtein += (aiResult.proteinG * calShare).round();
        totalCarbs += (aiResult.carbsG * calShare).round();
        totalFat += (aiResult.fatG * calShare).round();
        totalFiber += (aiResult.fiberG * calShare).round();
      }
    }

    // If no USDA matches, return the original AI result unchanged
    if (usdaCount == 0) return aiResult;

    return ScanResult(
      mealName: aiResult.mealName,
      totalCalories: totalCal,
      proteinG: totalProtein,
      carbsG: totalCarbs,
      fatG: totalFat,
      fiberG: totalFiber,
      items: enrichedItems,
      overallNotes: aiResult.overallNotes,
    );
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
      ? 'You\'ve used all your free scans for today. Upgrade to Pro for up to 50 scans/day.'
      : 'You\'ve used all your free coach messages for today. Upgrade to Pro for unlimited coaching.';
}
