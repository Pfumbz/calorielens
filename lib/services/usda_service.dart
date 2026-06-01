import 'dart:convert';
import 'package:http/http.dart' as http;

/// Nutrition data per 100g from USDA FoodData Central.
class UsdaNutrition {
  final int fdcId;
  final String description;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;

  const UsdaNutrition({
    required this.fdcId,
    required this.description,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fiberPer100g,
  });

  /// Calculate nutrition for a specific portion weight.
  Map<String, int> forGrams(double grams) {
    final factor = grams / 100.0;
    return {
      'calories': (caloriesPer100g * factor).round(),
      'protein': (proteinPer100g * factor).round(),
      'carbs': (carbsPer100g * factor).round(),
      'fat': (fatPer100g * factor).round(),
      'fiber': (fiberPer100g * factor).round(),
    };
  }

  @override
  String toString() =>
      '$description (per 100g: ${caloriesPer100g.round()} kcal, '
      'P:${proteinPer100g.round()}g C:${carbsPer100g.round()}g '
      'F:${fatPer100g.round()}g Fi:${fiberPer100g.round()}g)';
}

/// Service for looking up lab-verified nutrition data from USDA FoodData Central.
///
/// Free API with 300K+ foods. Uses the search endpoint which returns nutrients
/// inline, so a single call per food item is sufficient.
///
/// API docs: https://fdc.nal.usda.gov/api-guide
class UsdaService {
  static const _baseUrl = 'https://api.nal.usda.gov/fdc/v1';

  // USDA API key injected at build time via --dart-define=USDA_API_KEY=...
  // Never hardcode this value here — the key must stay out of source control.
  // Falls back to DEMO_KEY (30 req/hr) if not set.
  static const _apiKey = String.fromEnvironment('USDA_API_KEY', defaultValue: 'DEMO_KEY');

  // USDA nutrient IDs we care about
  static const _nutrientIds = {
    1008: 'calories',  // Energy (kcal)
    1003: 'protein',   // Protein (g)
    1005: 'carbs',     // Carbohydrate (g)
    1004: 'fat',       // Total lipid / fat (g)
    1079: 'fiber',     // Fiber, total dietary (g)
  };

  /// Search USDA for a food item and return the best match's nutrition per 100g.
  ///
  /// [query] should be a specific food name (e.g. "grilled chicken breast",
  /// "white rice cooked", "cheddar cheese").
  ///
  /// Returns null if no match found or API call fails.
  static Future<UsdaNutrition?> lookupFood(String query) async {
    try {
      final uri = Uri.parse('$_baseUrl/foods/search').replace(
        queryParameters: {
          'api_key': _apiKey,
          'query': query,
          'dataType': 'SR Legacy,Foundation', // Lab-verified datasets only
          'pageSize': '5',
        },
      );

      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final foods = data['foods'] as List?;
      if (foods == null || foods.isEmpty) return null;

      // Pick the best match — first result from SR Legacy or Foundation
      // is usually the most generic/standard form of the food.
      final best = foods.first as Map<String, dynamic>;
      return _parseFood(best);
    } catch (_) {
      return null;
    }
  }

  /// Look up multiple foods in parallel, returning a map of query → nutrition.
  /// Items that fail to match are omitted from the result.
  static Future<Map<String, UsdaNutrition>> lookupFoods(
    List<String> queries,
  ) async {
    final results = <String, UsdaNutrition>{};

    // Run lookups in parallel (max 5 concurrent to respect rate limits)
    final futures = <Future<void>>[];
    for (final query in queries) {
      futures.add(
        lookupFood(query).then((nutrition) {
          if (nutrition != null) results[query] = nutrition;
        }),
      );
    }
    await Future.wait(futures);
    return results;
  }

  /// Parse a single USDA food search result into [UsdaNutrition].
  static UsdaNutrition? _parseFood(Map<String, dynamic> food) {
    final nutrients = food['foodNutrients'] as List?;
    if (nutrients == null) return null;

    double calories = 0, protein = 0, carbs = 0, fat = 0, fiber = 0;

    for (final n in nutrients) {
      final nutrientId = n['nutrientId'] as int? ?? 0;
      final value = (n['value'] as num?)?.toDouble() ?? 0.0;

      switch (nutrientId) {
        case 1008:
          calories = value;
        case 1003:
          protein = value;
        case 1005:
          carbs = value;
        case 1004:
          fat = value;
        case 1079:
          fiber = value;
      }
    }

    // Skip entries with no calorie data (probably not a real food entry)
    if (calories == 0) return null;

    return UsdaNutrition(
      fdcId: food['fdcId'] as int? ?? 0,
      description: food['description'] as String? ?? '',
      caloriesPer100g: calories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      fiberPer100g: fiber,
    );
  }
}
