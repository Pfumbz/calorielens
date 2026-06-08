import 'dart:async';
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
        // L-3: Removed 'anthropic-dangerous-direct-browser-access' — only needed
        // for browser/WASM builds; unnecessary and misleading in an Android app.
      };

  // ── Image scan prompts ────────────────────────────────────────────
  static const _imageScanPromptSingle = '''You are an expert nutritionist specialising in South African cuisine. Analyse this meal photo and estimate its nutritional content.

INSTRUCTIONS:
1. Identify every distinct food item visible in the photo. Look carefully — don't miss sides, sauces, or drinks.
2. Estimate realistic portion sizes based on the plate/bowl size and food volume. Use standard portion references (a fist ≈ 1 cup, palm ≈ 100g meat, thumb ≈ 1 tbsp).
3. For EACH item, estimate the weight in grams (weight_g). This is critical — be as accurate as possible.
4. For EACH item, provide a "usda_query" — a simple, generic English food name suitable for searching the USDA database (e.g. "rice white cooked", "chicken breast grilled", "cheddar cheese"). Avoid brand names.
5. For South African dishes (e.g. pap, chakalaka, bunny chow, boerewors, vetkoek, samp & beans, mogodu, morogo), use nutrition data specific to those foods — do NOT substitute with generic Western equivalents.
6. When uncertain about a food item, name your best guess and note the uncertainty in that item's "note" field.
7. Round calories to the nearest 5. Be conservative rather than over-estimating.
8. The meal_name should be concise but descriptive (e.g. "Grilled Chicken with Pap & Chakalaka" not just "Plate of food").

Respond ONLY in this exact JSON format (no markdown, no backticks, no explanation):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<specific food>","portion":"<estimated size with unit>","calories":<int>,"weight_g":<number>,"usda_query":"<generic USDA search term>","note":"<brief observation or uncertainty>"}],"overall_notes":"<2-3 sentences: nutritional highlights, balance assessment, any concerns>"}''';

  static const _imageScanPromptMulti = '''You are an expert nutritionist specialising in South African cuisine. You are given TWO photos of the SAME meal taken from different angles. Use BOTH images together to accurately identify food items and estimate portion sizes.

INSTRUCTIONS:
1. The first image is typically a top-down view. The second image shows a different angle (side, 45°, etc.) revealing depth and volume that the top view cannot show.
2. Cross-reference both images: use the top view to identify foods and the side/angle view to gauge how deep or tall portions are — bowls, cups, and plates often hold much more than they appear from above.
3. For EACH item, estimate the weight in grams (weight_g). Use BOTH angles to judge volume accurately. This is critical — the second angle exists specifically to improve your weight estimate.
4. For EACH item, provide a "usda_query" — a simple, generic English food name suitable for searching the USDA database (e.g. "rice white cooked", "chicken breast grilled", "cheddar cheese"). Avoid brand names.
5. For South African dishes (e.g. pap, chakalaka, bunny chow, boerewors, vetkoek, samp & beans, mogodu, morogo), use nutrition data specific to those foods — do NOT substitute with generic Western equivalents.
6. When uncertain about a food item, name your best guess and note the uncertainty in that item's "note" field.
7. Round calories to the nearest 5. Be conservative rather than over-estimating.
8. The meal_name should be concise but descriptive (e.g. "Grilled Chicken with Pap & Chakalaka" not just "Plate of food").

Respond ONLY in this exact JSON format (no markdown, no backticks, no explanation):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<specific food>","portion":"<estimated size with unit>","calories":<int>,"weight_g":<number>,"usda_query":"<generic USDA search term>","note":"<brief observation or uncertainty>"}],"overall_notes":"<2-3 sentences: nutritional highlights, balance assessment, any concerns>"}''';

  // ── Input sanitization ────────────────────────────────────────────
  /// M-4: Sanitizes user-supplied text before embedding it in an AI prompt.
  /// Strips newlines (used for prompt injection), normalises quotes, and caps length.
  static String _sanitizeForPrompt(String input, {int maxLength = 300}) {
    return input
        .replaceAll('\r\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('"', "'")  // avoid breaking JSON-like context in prompts
        .trim()
        .substring(0, input.length.clamp(0, maxLength));
  }

  // ── Scan image (single or multi-angle) ──────────────────────────
  Future<ScanResult> scanImage(Uint8List imageBytes, String mediaType) async {
    final (result, _) = await scanImageWithRaw([imageBytes], [mediaType]);
    return result;
  }

  /// Scan one or more images and return both the ScanResult and raw JSON.
  /// Supports multi-angle: pass two images for better portion depth estimation.
  /// Pass [correctionHint] + [originalContext] when this is a correction retake.
  Future<(ScanResult, Map<String, dynamic>)> scanImageWithRaw(
    List<Uint8List> imageBytesList,
    List<String> mediaTypes, {
    String? correctionHint,
    Map<String, dynamic>? originalContext,
  }) async {
    final isMulti = imageBytesList.length > 1;

    // Choose prompt: correction retake, multi-angle, or standard single
    String prompt;
    if (correctionHint != null) {
      final ctx = originalContext;
      // M-4: Sanitize user input before embedding in prompt to prevent injection.
      final safeHint = _sanitizeForPrompt(correctionHint);
      final safeOrigName = _sanitizeForPrompt(ctx?['name']?.toString() ?? 'Unknown');
      prompt = '''You are an expert nutritionist. The user has CORRECTED a food identification mistake made by the AI.

⚠️ OVERRIDE IN EFFECT — THE USER'S CORRECTION IS THE GROUND TRUTH ⚠️
The AI previously misidentified the food. The user is now telling you what it actually is.
You MUST trust the user's correction completely. Do NOT use the photo to re-identify the food — the photo is ONLY for estimating portion size (weight in grams).

CORRECTED FOOD NAME(S): "$safeHint"

WHAT THE AI PREVIOUSLY (WRONGLY) CALLED IT: $safeOrigName
— Ignore this. The user says it is wrong.

RULE 1 — FOOD IDENTITY: The corrected name above is what the food IS. Accept it without question. Never revert to the old name or let the photo override it.
RULE 2 — SINGLE UNIT: Return nutrition for EXACTLY ONE unit/serving. Ignore any quantity numbers in the corrected name — the app handles scaling in code.
RULE 3 — PHOTO USE: Use the photo ONLY to estimate the weight in grams of one unit/serving of the corrected food. Nothing else.

INSTRUCTIONS:
1. Look up nutrition data for "$safeHint" — this is the food, full stop.
2. Use the photo to estimate weight_g of ONE serving of that food as it appears on the plate.
3. Calculate calories and macros from the corrected food's nutrition data × estimated weight.
4. For EACH item, provide a usda_query — a simple generic English name for USDA lookup.
5. For South African dishes (pap, chakalaka, boerewors, vetkoek, samp, mogodu, morogo, pork trotters) use SA-specific nutrition data.
6. Round calories to the nearest 5.
7. The portion field describes ONE unit only (e.g. "1 pork trotter (~200g)").

Respond ONLY in this exact JSON format (no markdown, no backticks):
{"meal_name":"<name using corrected food>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<corrected food name>","portion":"<1 unit size>","calories":<int>,"weight_g":<number>,"usda_query":"<USDA term>","note":"<observation>"}],"overall_notes":"<2-3 sentences>"}''';
    } else {
      prompt = isMulti ? _imageScanPromptMulti : _imageScanPromptSingle;
    }

    // Build content array: images first, then prompt text
    final content = <Map<String, dynamic>>[];
    for (int i = 0; i < imageBytesList.length; i++) {
      content.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mediaTypes[i],
          'data': base64Encode(imageBytesList[i]),
        }
      });
    }
    content.add({'type': 'text', 'text': prompt});

    final body = jsonEncode({
      'model': _modelVision,
      'max_tokens': 1024,
      'messages': [
        {'role': 'user', 'content': content}
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body)
        .timeout(const Duration(seconds: 45)); // Slightly longer for multi-image
    return _parseResponseWithRaw(res);
  }

  // ── Scan text description ────────────────────────────────────────
  Future<ScanResult> scanText(
    String description, {
    Map<String, dynamic>? originalContext,
  }) async {
    String prompt;

    if (originalContext != null) {
      // Correction mode: reference the original scan so the AI adjusts
      // proportionally instead of estimating from scratch.
      prompt =
          '''You are an expert nutritionist. The user previously scanned a meal and is now correcting it.

ORIGINAL ANALYSIS:
- Meal name: ${originalContext['name'] ?? 'Unknown'}
- Calories: ${originalContext['calories'] ?? '?'} kcal
- Protein: ${originalContext['protein'] ?? '?'}g | Carbs: ${originalContext['carbs'] ?? '?'}g | Fat: ${originalContext['fat'] ?? '?'}g | Fiber: ${originalContext['fiber'] ?? '?'}g

The user says the meal should actually be: "$description"

INSTRUCTIONS:
1. Compare the user's corrected description to the original analysis above.
2. Adjust the nutrition proportionally based on what changed (e.g. if the original had 5 items but the user says there were only 3, scale down accordingly).
3. Use the original analysis as your baseline — do NOT estimate from scratch.
4. Be conservative. Round calories to the nearest 5.
5. Give a concise but descriptive meal_name based on the corrected description.

Respond ONLY in this exact JSON format (no markdown, no backticks):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<estimated size>","calories":<int>,"note":"<brief>"}],"overall_notes":"<2-3 sentences>"}''';
    } else {
      prompt =
          '''You are an expert nutritionist specialising in South African cuisine. Estimate the nutritional content for this meal: "$description"

INSTRUCTIONS:
1. Identify each food component mentioned. If the description is vague (e.g. "lunch"), ask yourself what a typical South African portion would be.
2. Use standard adult portion sizes unless the user specifies otherwise.
3. For EACH item, estimate the weight in grams (weight_g). This is critical for accuracy.
4. For EACH item, provide a "usda_query" — a simple, generic English food name for USDA database lookup (e.g. "rice white cooked", "chicken breast grilled").
5. For SA-specific foods (pap, chakalaka, boerewors, bunny chow, vetkoek, samp, mogodu, morogo, etc.), use nutrition data specific to those foods.
6. Round calories to the nearest 5. Be conservative.
7. Give a concise but descriptive meal_name.

Respond ONLY in this exact JSON format (no markdown, no backticks):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<estimated size>","calories":<int>,"weight_g":<number>,"usda_query":"<generic USDA search term>","note":"<brief>"}],"overall_notes":"<2-3 sentences>"}''';
    }

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

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body)
        .timeout(const Duration(seconds: 30));
    return _parseResponse(res);
  }

  /// Same as [scanText] but also returns raw JSON for USDA query extraction.
  Future<(ScanResult, Map<String, dynamic>)> scanTextWithRaw(
    String description, {
    Map<String, dynamic>? originalContext,
  }) async {
    // Build the same prompt as scanText
    String prompt;
    if (originalContext != null) {
      // M-4: Sanitize user-supplied description before embedding in prompt.
      final safeDesc = _sanitizeForPrompt(description);
      prompt =
          '''You are an expert nutritionist. The user previously scanned a meal and is now correcting it.

ORIGINAL ANALYSIS:
- Meal name: ${originalContext['name'] ?? 'Unknown'}
- Calories: ${originalContext['calories'] ?? '?'} kcal
- Protein: ${originalContext['protein'] ?? '?'}g | Carbs: ${originalContext['carbs'] ?? '?'}g | Fat: ${originalContext['fat'] ?? '?'}g | Fiber: ${originalContext['fiber'] ?? '?'}g

The user says the meal should actually be: "$safeDesc"

INSTRUCTIONS:
1. Compare the user's corrected description to the original analysis above.
2. Adjust the nutrition proportionally based on what changed.
3. Use the original analysis as your baseline — do NOT estimate from scratch.
4. Be conservative. Round calories to the nearest 5.
5. Give a concise but descriptive meal_name based on the corrected description.

Respond ONLY in this exact JSON format (no markdown, no backticks):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<estimated size>","calories":<int>,"note":"<brief>"}],"overall_notes":"<2-3 sentences>"}''';
    } else {
      prompt =
          '''You are an expert nutritionist specialising in South African cuisine. Estimate the nutritional content for this meal: "$description"

INSTRUCTIONS:
1. Identify each food component mentioned.
2. Use standard adult portion sizes unless the user specifies otherwise.
3. For EACH item, estimate the weight in grams (weight_g). This is critical for accuracy.
4. For EACH item, provide a "usda_query" — a simple, generic English food name for USDA database lookup.
5. For SA-specific foods, use nutrition data specific to those foods.
6. Round calories to the nearest 5. Be conservative.
7. Give a concise but descriptive meal_name.

Respond ONLY in this exact JSON format (no markdown, no backticks):
{"meal_name":"<descriptive name>","total_calories":<int>,"protein_g":<int>,"carbs_g":<int>,"fat_g":<int>,"fiber_g":<int>,"items":[{"name":"<food>","portion":"<estimated size>","calories":<int>,"weight_g":<number>,"usda_query":"<generic USDA search term>","note":"<brief>"}],"overall_notes":"<2-3 sentences>"}''';
    }

    final body = jsonEncode({
      'model': _modelFast,
      'max_tokens': 1024,
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body)
        .timeout(const Duration(seconds: 30));
    return _parseResponseWithRaw(res);
  }

  /// Parse the Anthropic API response and return both the ScanResult and
  /// the raw parsed JSON (needed for extracting usda_query fields).
  (ScanResult, Map<String, dynamic>) _parseResponseWithRaw(http.Response res) {
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
    return (ScanResult.fromJson(parsed), parsed);
  }

  ScanResult _parseResponse(http.Response res) {
    return _parseResponseWithRaw(res).$1;
  }

  // ── Generate meal plan ───────────────────────────────────────────
  Future<Map<String, dynamic>> generateMealPlan({
    required int calorieGoal,
    required String budgetTier,
    String? dietaryPreference,
    String? profileContext,
  }) async {
    // Detect country/currency from profileContext
    final countryMatch = RegExp(r'Country code:\s*(\w+)', caseSensitive: false)
        .firstMatch(profileContext ?? '');
    final countryCode = countryMatch?.group(1)?.toUpperCase() ?? 'US';
    final currencyMatch = RegExp(r'Currency:\s*(\w+)\s*\(([^)]+)\)', caseSensitive: false)
        .firstMatch(profileContext ?? '');
    final currency = currencyMatch?.group(1) ?? 'USD';
    final currencySymbol = currencyMatch?.group(2) ?? '\$';

    // Locale-aware context
    final countryContextMap = <String, Map<String, String>>{
      'ZA': {'name': 'South Africa', 'foods': 'South African foods (pap, chakalaka, boerewors, biltong, butternut, spinach, braai chicken, samp and beans, etc.)', 'stores': 'Shoprite, Checkers, Pick n Pay, Woolworths', 'low': '50', 'mid': '100', 'high': '150'},
      'NG': {'name': 'Nigeria', 'foods': 'Nigerian foods (jollof rice, plantain, beans, yam, egusi soup, pepper soup, suya, moi moi, etc.)', 'stores': 'Shoprite, local markets, Spar', 'low': '3000', 'mid': '5000', 'high': '8000'},
      'KE': {'name': 'Kenya', 'foods': 'Kenyan foods (ugali, sukuma wiki, nyama choma, githeri, chapati, tilapia, pilau, etc.)', 'stores': 'Naivas, Carrefour, local markets', 'low': '500', 'mid': '800', 'high': '1200'},
      'GH': {'name': 'Ghana', 'foods': 'Ghanaian foods (fufu, banku, groundnut soup, jollof rice, waakye, kelewele, etc.)', 'stores': 'Shoprite, Melcom, local markets', 'low': '50', 'mid': '80', 'high': '120'},
      'GB': {'name': 'United Kingdom', 'foods': 'UK foods and ingredients from British supermarkets', 'stores': 'Tesco, Sainsbury\'s, Aldi, Asda', 'low': '5', 'mid': '10', 'high': '15'},
      'US': {'name': 'United States', 'foods': 'American foods and common supermarket ingredients', 'stores': 'Walmart, Trader Joe\'s, Kroger, Whole Foods', 'low': '8', 'mid': '15', 'high': '25'},
      'IN': {'name': 'India', 'foods': 'Indian foods (dal, roti, paneer, biryani, idli, dosa, sabzi, curd rice, etc.)', 'stores': 'DMart, Big Bazaar, local markets', 'low': '200', 'mid': '400', 'high': '600'},
      'BR': {'name': 'Brazil', 'foods': 'Brazilian foods (arroz e feijão, frango, mandioca, farofa, açaí, coxinha, etc.)', 'stores': 'Pão de Açúcar, Carrefour, local markets', 'low': '30', 'mid': '50', 'high': '80'},
      'AU': {'name': 'Australia', 'foods': 'Australian foods and supermarket ingredients', 'stores': 'Coles, Woolworths, Aldi', 'low': '10', 'mid': '20', 'high': '30'},
      'DE': {'name': 'Germany', 'foods': 'German foods and common European ingredients', 'stores': 'Aldi, Lidl, Edeka, REWE', 'low': '5', 'mid': '10', 'high': '15'},
      'MX': {'name': 'Mexico', 'foods': 'Mexican foods (frijoles, tortillas, pollo, arroz, aguacate, nopales, chilaquiles, etc.)', 'stores': 'Walmart, Soriana, Bodega Aurrera', 'low': '100', 'mid': '200', 'high': '350'},
      'AE': {'name': 'UAE', 'foods': 'Middle Eastern foods (hummus, shawarma, falafel, rice, lamb, lentils, fattoush, etc.)', 'stores': 'Carrefour, Lulu, Spinneys', 'low': '25', 'mid': '50', 'high': '80'},
    };

    final ctx = countryContextMap[countryCode] ?? {'name': 'the user\'s country', 'foods': 'locally available foods and ingredients', 'stores': 'local supermarkets', 'low': '8', 'mid': '15', 'high': '25'};

    final budgetLabel = budgetTier == 'r50'
        ? 'under $currencySymbol${ctx['low']} (budget, use ${ctx['stores']} ingredients)'
        : budgetTier == 'r100'
            ? 'around $currencySymbol${ctx['mid']} (mid-range, use ${ctx['stores']} ingredients)'
            : 'up to $currencySymbol${ctx['high']} (premium, use quality store-bought ingredients)';

    final dietNote = dietaryPreference != null && dietaryPreference.isNotEmpty
        ? '\nDietary preference: $dietaryPreference.'
        : '';

    final profileNote = profileContext != null && profileContext.isNotEmpty
        ? '\nUser context: $profileContext'
        : '';

    final prompt = '''You are a nutritionist and meal planner based in ${ctx['name']}. Create a personalised one-day meal plan.

Requirements:
- Target: $calorieGoal kcal for the day
- Budget: $budgetLabel per day (prices in $currency)$dietNote$profileNote
- Include 4 meals: breakfast, lunch, dinner, snack
- Use ${ctx['foods']} available at ${ctx['stores']}
- Include realistic $currency prices for each ingredient (2025/2026 prices)

Respond ONLY in this exact JSON (no markdown, no explanation):
{"plan_name":"<creative name>","description":"<1-2 sentences>","category":"<budget|balanced|high-protein|vegetarian|bulk-cook>","budget_tier":"$budgetTier","estimated_cost":<total number>,"total_calories":<int>,"total_protein":<int>,"total_carbs":<int>,"total_fat":<int>,"prep_time_min":<int>,"emoji":"<single emoji>","meals":[{"name":"<meal name>","meal_type":"<breakfast|lunch|dinner|snack>","calories":<int>,"protein":<int>,"carbs":<int>,"fat":<int>,"emoji":"<single emoji>","recipe":"<brief instructions>","ingredients":[{"name":"<ingredient>","quantity":"<amount>","estimated_price":<number>,"category":"<protein|produce|grain|dairy|spice|pantry>"}]}]}''';

    final body = jsonEncode({
      'model': _modelFast,
      'max_tokens': 2048,
      'messages': [
        {'role': 'user', 'content': prompt}
      ]
    });

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body)
        .timeout(const Duration(seconds: 30));
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

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body)
        .timeout(const Duration(seconds: 30));
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

    final res = await http.post(Uri.parse(_endpoint), headers: _headers, body: body)
        .timeout(const Duration(seconds: 30));
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
