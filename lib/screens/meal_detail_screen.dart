import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/meal_plan.dart';
import '../models/models.dart';
import '../services/food_image_service.dart';
import '../theme.dart';

/// Detail view for a single meal within a plan.
/// Shows recipe, ingredients, and macros.
class MealDetailScreen extends StatefulWidget {
  final PlanMeal meal;
  final MealPlan plan;
  const MealDetailScreen({super.key, required this.meal, required this.plan});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  late Future<String> _heroImageFuture;

  PlanMeal get meal => widget.meal;
  MealPlan get plan => widget.plan;

  @override
  void initState() {
    super.initState();
    _heroImageFuture = FoodImageService.getSmartImageUrl(meal.name, hero: true);
  }

  @override
  Widget build(BuildContext context) {
    final fallbackUrl = FoodImageService.getHeroUrl(meal.name);

    return Scaffold(
      backgroundColor: CLColors.bg,
      body: CustomScrollView(
        slivers: [
          // ── Hero header with photo ─────────────────────────────
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: CLColors.bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 18),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<String>(
                    future: _heroImageFuture,
                    builder: (context, snap) {
                      final url = snap.data ?? fallbackUrl;
                      return CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: CLColors.surface2),
                        errorWidget: (_, __, ___) => Container(
                          color: CLColors.surface2,
                          child: Center(child: Text(meal.emoji, style: const TextStyle(fontSize: 56))),
                        ),
                      );
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          CLColors.bg.withOpacity(0.7),
                          CLColors.bg,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.2, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 20,
                    right: 20,
                    child: Text(meal.name,
                        style: const TextStyle(
                            color: CLColors.text,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),

                  // ── Macro summary card ─────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: CLColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CLColors.border),
                    ),
                    child: Column(
                      children: [
                        Text('${meal.calories}',
                            style: const TextStyle(
                                color: CLColors.accent,
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                height: 1)),
                        const Text('kcal',
                            style: TextStyle(color: CLColors.muted, fontSize: 14)),
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
                  const Text('Ingredients',
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  ...meal.ingredients.map((ing) => _ingredientRow(ing)),
                  const SizedBox(height: 20),

                  // ── Log to diary button ─────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _logMeal(context),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('LOG TO DIARY'),
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
