import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/meal_plan.dart';
import '../models/models.dart';
import '../theme.dart';
import 'meal_detail_screen.dart';

/// Full detail view for a single meal plan.
/// Shows macro summary, cost, and list of meals for the day.
class PlanDetailScreen extends StatelessWidget {
  final MealPlan plan;
  const PlanDetailScreen({super.key, required this.plan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ───────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: CLColors.bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              Builder(builder: (ctx) {
                final state = ctx.watch<AppState>();
                final saved = state.isPlanSaved(plan.id);
                return IconButton(
                  icon: Icon(
                    saved ? Icons.bookmark : Icons.bookmark_border,
                    color: saved ? CLColors.accent : CLColors.muted,
                  ),
                  onPressed: () => state.toggleSavedPlan(plan.id),
                );
              }),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      CLColors.accent.withOpacity(0.15),
                      CLColors.bg,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Text(plan.emoji,
                          style: const TextStyle(fontSize: 56)),
                      const SizedBox(height: 10),
                      Text(plan.name,
                          style: const TextStyle(
                              color: CLColors.text,
                              fontSize: 22,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(plan.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: CLColors.muted,
                              fontSize: 12,
                              height: 1.4)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Cost + stats row ────────────────────────────
                  Row(
                    children: [
                      _statChip(
                        'R${plan.estimatedCostZAR.toStringAsFixed(0)}',
                        'Total cost',
                        CLColors.green,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        '${plan.totalCalories}',
                        'kcal',
                        CLColors.accent,
                      ),
                      const SizedBox(width: 8),
                      _statChip(
                        '${plan.prepTimeMin} min',
                        'prep time',
                        CLColors.blue,
                      ),
                      if (plan.servings > 1) ...[
                        const SizedBox(width: 8),
                        _statChip(
                          '${plan.servings}',
                          'servings',
                          CLColors.purple,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Macro bars ──────────────────────────────────
                  _buildMacroSection(),
                  const SizedBox(height: 20),

                  // ── Meals list ──────────────────────────────────
                  const Text("Today's Meals",
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),

                  ...plan.meals.map((meal) => _MealCard(
                        meal: meal,
                        plan: plan,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MealDetailScreen(
                                meal: meal, plan: plan),
                          ),
                        ),
                      )),

                  const SizedBox(height: 16),

                  // ── Log all meals button ────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _logAllMeals(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('LOG ALL MEALS TO DIARY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CLColors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: CLColors.muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        children: [
          _macroBar('Protein', plan.totalProtein,
              (plan.totalCalories * 0.25 / 4).round(), CLColors.blue),
          const SizedBox(height: 10),
          _macroBar('Carbs', plan.totalCarbs,
              (plan.totalCalories * 0.50 / 4).round(), CLColors.green),
          const SizedBox(height: 10),
          _macroBar('Fat', plan.totalFat,
              (plan.totalCalories * 0.25 / 9).round(), CLColors.accent),
        ],
      ),
    );
  }

  Widget _macroBar(String label, int value, int target, Color color) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
            width: 52,
            child: Text(label,
                style: const TextStyle(
                    color: CLColors.muted, fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: CLColors.border,
              color: color,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${value}g',
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _logAllMeals(BuildContext context) {
    final state = context.read<AppState>();
    final now = TimeOfDay.now();
    for (final meal in plan.meals) {
      state.addEntry(DiaryEntry(
        id: DateTime.now().millisecondsSinceEpoch + plan.meals.indexOf(meal),
        time:
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
        name: meal.name,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
      ));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${plan.meals.length} meals logged — ${plan.totalCalories} kcal'),
        backgroundColor: CLColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }
}

// ── Meal Card ────────────────────────────────────────────────────────────────
class _MealCard extends StatelessWidget {
  final PlanMeal meal;
  final MealPlan plan;
  final VoidCallback onTap;
  const _MealCard(
      {required this.meal, required this.plan, required this.onTap});

  String get _mealTypeLabel {
    switch (meal.mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      case 'snack':
        return 'Snack';
      default:
        return meal.mealType;
    }
  }

  Color get _mealTypeColor {
    switch (meal.mealType) {
      case 'breakfast':
        return CLColors.gold;
      case 'lunch':
        return CLColors.green;
      case 'dinner':
        return CLColors.accent;
      case 'snack':
        return CLColors.blue;
      default:
        return CLColors.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            // Emoji
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _mealTypeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(meal.emoji,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _mealTypeColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(_mealTypeLabel,
                            style: TextStyle(
                                color: _mealTypeColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(meal.name,
                      style: const TextStyle(
                          color: CLColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    'P:${meal.protein}g  C:${meal.carbs}g  F:${meal.fat}g',
                    style: const TextStyle(
                        color: CLColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Calories
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${meal.calories}',
                    style: const TextStyle(
                        color: CLColors.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                const Text('kcal',
                    style: TextStyle(
                        color: CLColors.muted, fontSize: 10)),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: CLColors.muted, size: 16),
          ],
        ),
      ),
    );
  }
}
