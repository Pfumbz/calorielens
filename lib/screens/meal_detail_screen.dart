import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/meal_plan.dart';
import '../models/models.dart';
import '../theme.dart';
import '../widgets/shopping_list_sheet.dart';

/// Detail view for a single meal within a plan.
/// Shows recipe, ingredients, macros, and a "Shop Ingredients" button.
class MealDetailScreen extends StatelessWidget {
  final PlanMeal meal;
  final MealPlan plan;
  const MealDetailScreen({super.key, required this.meal, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      appBar: AppBar(
        title: Text(meal.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),

            // ── Hero card ────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    CLColors.accent.withOpacity(0.12),
                    CLColors.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CLColors.accent.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(meal.emoji,
                      style: const TextStyle(fontSize: 48)),
                  const SizedBox(height: 12),
                  Text('${meal.calories}',
                      style: const TextStyle(
                          color: CLColors.accent,
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          height: 1)),
                  const Text('kcal',
                      style:
                          TextStyle(color: CLColors.muted, fontSize: 14)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _macroChip('Protein', '${meal.protein}g', CLColors.blue),
                      _macroChip('Carbs', '${meal.carbs}g', CLColors.green),
                      _macroChip('Fat', '${meal.fat}g', CLColors.accent),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Recipe ───────────────────────────────────────────
            const Text('Recipe',
                style: TextStyle(
                    color: CLColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CLColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CLColors.border),
              ),
              child: Text(meal.recipe,
                  style: const TextStyle(
                      color: CLColors.text,
                      fontSize: 14,
                      height: 1.6)),
            ),
            const SizedBox(height: 20),

            // ── Ingredients ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ingredients',
                    style: TextStyle(
                        color: CLColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text(
                  '~R${meal.ingredientsCost.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: CLColors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...meal.ingredients.map((ing) => _ingredientRow(ing)),
            const SizedBox(height: 20),

            // ── Action buttons ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => showShoppingListSheet(
                  context,
                  ingredients: meal.ingredients,
                  budgetTier: plan.budgetTier,
                ),
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: const Text('SHOP INGREDIENTS'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _logMeal(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('LOG TO DIARY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: CLColors.green,
                  side: const BorderSide(color: CLColors.green),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: CLColors.muted, fontSize: 11)),
      ],
    );
  }

  Widget _ingredientRow(Ingredient ing) {
    final catEmoji = _categoryEmoji(ing.category);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CLColors.border),
      ),
      child: Row(
        children: [
          Text(catEmoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ing.name,
                    style: const TextStyle(
                        color: CLColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(ing.quantity,
                    style: const TextStyle(
                        color: CLColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Text('~R${ing.estimatedPriceZAR.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: CLColors.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _categoryEmoji(String category) {
    switch (category) {
      case 'protein':
        return '🥩';
      case 'produce':
        return '🥬';
      case 'grain':
        return '🌾';
      case 'dairy':
        return '🥛';
      case 'spice':
        return '🌶️';
      case 'pantry':
        return '🫙';
      default:
        return '🛒';
    }
  }

  void _logMeal(BuildContext context) {
    final state = context.read<AppState>();
    final now = TimeOfDay.now();
    state.addEntry(DiaryEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      time:
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
      name: meal.name,
      calories: meal.calories,
      protein: meal.protein,
      carbs: meal.carbs,
      fat: meal.fat,
    ));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${meal.name} logged — ${meal.calories} kcal'),
        backgroundColor: CLColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
