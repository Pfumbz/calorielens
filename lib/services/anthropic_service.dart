import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class AnthropicService {
  static const _endpoint = 'https://api.anthropic.com/v1/messages';
  static const _modelVision = 'claude-sonnet-4-6'; // Better accuracy for image analysis
  static const _modelFast   = 'claude-haiku-4-5-20251001';  // Fast/cheap for text & chat
  static const _version = '2023-06-01';

  final String apiKey;
  AnthropicService(this.apiKey);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _version,
        'anthropic-dangerous-direct-browser-access': 'true',
      };

  // ── Scan image ───────────────────────────────────────────────────
  Future<ScanResult> scanImage(Uint8List imageBytes, String mediaType) async {
    const prompt = '''You are an expert nutritionist specialising in South African cuisine. Analyse this meal photo and estimate its nutritional content.

INSTRUCTIONS:
1. Identify every distinct food item visible in the photo. Look carefully — don't miss sides, sauces, or drinks.
2. Estimate realistic portion sizes based on the plate/bowl size and food volume. Use standard portion references (a fist ≈ 1 cup, palm ≈ 100g meat, thumb ≈ 1 tbsp).
3. For South African dishes (e.g. pap, chakalaka, bunny chow, boerewors, vetkoek, samp & beans, mogodu, morogo), use nutrition data specific to those foods — do NOT substitute with generic Western equivalents.
4. When uncertain about a food item, name your best guess and note the uncertainty in that item's "note" field.
5. Round calories to the nearest 5. Be conservative rather than over-estimating.
6. The meal_name should be concise but descriptive (e.g. "Grilled Chicken with Pap & Chakalaka" not just "Plate of food").

Respond ONLY in this exact JSON format (no markdown, no backticks, no explanation):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<specific food>","portion":"<estimated size with unit>","calories":<int>,"note":"<brief observation or uncertainty>"}],"overall_notes":"<2-3 sentences: nutritional highlights, balance assessment, any concerns>"}''';

    final b64 = base64Encode(imageBytes);
    final body = jsonEncode({
      'model': _modelVision,
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': b64,
              }
            },
            {'type': 'text', 'text': prompt}
          ]
        }
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    return _parseResponse(res);
  }

  // ── Scan text description ────────────────────────────────────────
  Future<ScanResult> scanText(String description) async {
    final prompt =
        '''You are an expert nutritionist specialising in South African cuisine. Estimate the nutritional content for this meal: "$description"

INSTRUCTIONS:
1. Identify each food component mentioned. If the description is vague (e.g. "lunch"), ask yourself what a typical South African portion would be.
2. Use standard adult portion sizes unless the user specifies otherwise.
3. For SA-specific foods (pap, chakalaka, boerewors, bunny chow, vetkoek, samp, mogodu, morogo, etc.), use nutrition data specific to those foods.
4. Round calories to the nearest 5. Be conservative.
5. Give a concise but descriptive meal_name.

Respond ONLY in this exact JSON format (no markdown, no backticks):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<estimated size>","calories":<int>,"note":"<brief>"}],"overall_notes":"<2-3 sentences>"}''';

    final body = jsonEncode({
      'model': _modelFast,
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': prompt
        }
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    return _parseResponse(res);
  }

  ScanResult _parseResponse(http.Response res) {
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'API error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = (data['content'] as List)
        .map((b) => (b as Map)['text'] ?? '')
        .join('');
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final parsed = jsonDecode(clean) as Map<String, dynamic>;
    return ScanResult.fromJson(parsed);
  }

  // ── Generate meal plan ───────────────────────────────────────────
  Future<Map<String, dynamic>> generateMealPlan({
    required int calorieGoal,
    required String budgetTier,
    String? dietaryPreference,
    String? profileContext,
  }) async {
    final budgetLabel = budgetTier == 'r50'
        ? 'under R50 (budget, use Shoprite/Checkers ingredients)'
        : budgetTier == 'r100'
            ? 'around R100 (mid-range, use Pick n Pay/Checkers ingredients)'
            : 'up to R150 (premium, can use Woolworths ingredients)';

    final dietNote = dietaryPreference != null && dietaryPreference.isNotEmpty
        ? '\nDietary preference: $dietaryPreference.'
        : '';

    final profileNote = profileContext != null && profileContext.isNotEmpty
        ? '\nUser context: $profileContext'
        : '';

    final prompt = '''You are a South African nutritionist and meal planner. Create a personalised one-day meal plan.

Requirements:
- Target: $calorieGoal kcal for the day
- Budget: $budgetLabel per day (prices in South African Rand)$dietNote$profileNote
- Include 4 meals: breakfast, lunch, dinner, snack
- Use South African foods, brands, and ingredients available at local supermarkets
- Include realistic ZAR prices for each ingredient (2025/2026 prices)

Respond ONLY in this exact JSON (no markdown, no explanation):
{"plan_name":"<creative name>","description":"<1-2 sentences>","category":"<budget|balanced|high-protein|vegetarian|bulk-cook>","budget_tier":"$budgetTier","estimated_cost_zar":<total number>,"total_calories":<int>,"total_protein":<int>,"total_carbs":<int>,"total_fat":<int>,"prep_time_min":<int>,"emoji":"<single emoji>","meals":[{"name":"<meal name>","meal_type":"<breakfast|lunch|dinner|snack>","calories":<int>,"protein":<int>,"carbs":<int>,"fat":<int>,"emoji":"<single emoji>","recipe":"<brief instructions>","ingredients":[{"name":"<ingredient>","quantity":"<amount>","estimated_price_zar":<number>,"category":"<protein|produce|grain|dairy|spice|pantry>"}]}]}''';

    final body = jsonEncode({
      'model': _modelFast,
      'max_tokens': 2048,
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'API error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = (data['content'] as List)
        .map((b) => (b as Map)['text'] ?? '')
        .join('');
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  }

  // ── Scan fridge photo ──────────────────────────────────────────
  Future<List<String>> scanFridge(Uint8List imageBytes, String mediaType) async {
    const prompt = '''You are a kitchen inventory assistant. Look at this photo of a fridge/pantry/kitchen and identify all visible food ingredients.

Respond ONLY in this exact JSON (no markdown):
{"ingredients":["<ingredient 1>","<ingredient 2>","<ingredient 3>",...]}

Be specific (e.g. "chicken thighs" not just "meat", "cheddar cheese" not just "cheese"). Include quantities if visible.''';

    final b64 = base64Encode(imageBytes);
    final body = jsonEncode({
      'model': _modelVision,
      'max_tokens': 1024,
      'messages': [
        {
          'role': 'user',
          'content': [
            {
              'type': 'image',
              'source': {
                'type': 'base64',
                'media_type': mediaType,
                'data': b64,
              }
            },
            {'type': 'text', 'text': prompt}
          ]
        }
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'API error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final raw = (data['content'] as List)
        .map((b) => (b as Map)['text'] ?? '')
        .join('');
    final clean = raw.replaceAll('```json', '').replaceAll('```', '').trim();
    final parsed = jsonDecode(clean) as Map<String, dynamic>;
    return (parsed['ingredients'] as List).map((e) => e.toString()).toList();
  }

  // ── Coach chat ───────────────────────────────────────────────────
  Future<String> chat({
    required List<ChatMessage> history,
    required String userMessage,
    required String systemPrompt,
  }) async {
    final messages = [
      ...history.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    final body = jsonEncode({
      'model': _modelFast,
      'max_tokens': 1024,
      'system': systemPrompt,
      'messages': messages,
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body);
    if (res.statusCode != 200) {
      final err = jsonDecode(res.body);
      throw Exception(err['error']?['message'] ?? 'API error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return (data['content'] as List)
        .map((b) => (b as Map)['text'] ?? '')
        .join('');
  }
}
