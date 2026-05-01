/// Data models for the Meal Plans feature.
/// Supports curated + AI-generated plans with SA retailer deep links.

class MealPlan {
  final String id;
  final String name;
  final String description;
  final String category; // budget | balanced | high-protein | vegetarian | bulk-cook
  final String budgetTier; // r50 | r100 | r150
  final double estimatedCostZAR;
  final int totalCalories;
  final int totalProtein;
  final int totalCarbs;
  final int totalFat;
  final int servings;
  final int prepTimeMin;
  final String emoji; // used as visual icon on card
  final String? imageUrl; // hero photo URL (from FoodImageService or AI)
  final List<PlanMeal> meals;
  final List<String> tags;

  const MealPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.budgetTier,
    required this.estimatedCostZAR,
    required this.totalCalories,
    required this.totalProtein,
    required this.totalCarbs,
    required this.totalFat,
    required this.servings,
    required this.prepTimeMin,
    required this.emoji,
    this.imageUrl,
    required this.meals,
    this.tags = const [],
  });

  /// Total ingredient cost for the full plan.
  double get totalIngredientCost =>
      meals.fold(0.0, (sum, m) => sum + m.ingredientsCost);

  /// Per-serving cost.
  double get costPerServing =>
      servings > 0 ? estimatedCostZAR / servings : estimatedCostZAR;
}

class PlanMeal {
  final String id;
  final String name;
  final String mealType; // breakfast | lunch | dinner | snack
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final String recipe;
  final String emoji;
  final List<Ingredient> ingredients;

  const PlanMeal({
    required this.id,
    required this.name,
    required this.mealType,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.recipe,
    required this.emoji,
    required this.ingredients,
  });

  double get ingredientsCost =>
      ingredients.fold(0.0, (sum, i) => sum + i.estimatedPriceZAR);
}

class Ingredient {
  final String name;
  final String quantity;
  final double estimatedPriceZAR;
  final String category; // protein | produce | grain | dairy | pantry | spice

  const Ingredient({
    required this.name,
    required this.quantity,
    required this.estimatedPriceZAR,
    required this.category,
  });
}

/// Represents a retailer and how to link to their store.
class Retailer {
  final String id;
  final String name;
  final String emoji; // logo stand-in
  final String searchUrlTemplate; // use {query} as placeholder
  final String? appDeepLinkTemplate;

  const Retailer({
    required this.id,
    required this.name,
    required this.emoji,
    required this.searchUrlTemplate,
    this.appDeepLinkTemplate,
  });

  /// Build a search URL for a given ingredient name.
  String searchUrl(String ingredientName) {
    final encoded = Uri.encodeComponent(ingredientName);
    return searchUrlTemplate.replaceAll('{query}', encoded);
  }
}
