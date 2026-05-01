import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/meal_plan.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/upgrade_modal.dart';
import '../screens/plan_detail_screen.dart';

/// Shows the AI meal plan generation sheet.
/// Gated behind Pro or BYOK.
void showGeneratePlanSheet(BuildContext context) {
  final state = context.read<AppState>();
  if (!state.isPremium && !state.hasApiKey) {
    showUpgradeModal(context, source: 'generate_plan');
    return;
  }
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const GeneratePlanSheet(),
  );
}

class GeneratePlanSheet extends StatefulWidget {
  const GeneratePlanSheet({super.key});

  @override
  State<GeneratePlanSheet> createState() => _GeneratePlanSheetState();
}

class _GeneratePlanSheetState extends State<GeneratePlanSheet> {
  String _dietary = '';
  bool _loading = false;
  String? _error;

  static const _dietaryOptions = [
    ('', 'No preference'),
    ('high-protein', 'High protein'),
    ('vegetarian', 'Vegetarian'),
    ('low-carb', 'Low carb'),
    ('halal', 'Halal'),
    ('dairy-free', 'Dairy free'),
  ];

  Future<void> _generate() async {
    final state = context.read<AppState>();
    setState(() { _loading = true; _error = null; });

    try {
      final profile = state.profile;

      // Build rich profile context with eating history
      final profileParts = <String>[
        if (profile.name.isNotEmpty) 'Name: ${profile.name}',
        if (profile.weight > 0) 'Weight: ${profile.weight}kg',
        if (profile.height > 0) 'Height: ${profile.height}cm',
        if (profile.age > 0) 'Age: ${profile.age}',
        if (profile.sex.isNotEmpty) 'Sex: ${profile.sex == "m" ? "Male" : "Female"}',
      ];

      // Add country/locale context
      try {
        final locale = Platform.localeName;
        if (locale.contains('ZA') || locale.contains('za')) {
          profileParts.add('Country: South Africa');
        } else if (locale.length >= 2) {
          profileParts.add('Locale: $locale');
        }
      } catch (_) {}

      // Add recent eating history (last 3 days of meals)
      final storage = StorageService();
      final recentMeals = <String>[];
      for (int i = 0; i < 3; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final entries = storage.getDiary(date: date);
        for (final e in entries) {
          if (e.name.isNotEmpty) recentMeals.add(e.name);
        }
      }
      if (recentMeals.isNotEmpty) {
        profileParts.add('Recent meals eaten: ${recentMeals.take(10).join(', ')}');
        profileParts.add('Please suggest DIFFERENT meals from what they have been eating recently for variety.');
      }

      final profileContext = profileParts.join('. ');

      final result = await state.backend.generateMealPlan(
        calorieGoal: state.calorieGoal,
        budgetTier: 'r100',
        dietaryPreference: _dietary.isNotEmpty ? _dietary : null,
        profileContext: profileContext.isNotEmpty ? profileContext : null,
      );

      // Parse result into a MealPlan
      final plan = _parsePlan(result);

      // Save the generated plan JSON for persistence
      await state.trackScan(); // counts toward usage

      if (!mounted) return;
      Navigator.pop(context); // close sheet
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PlanDetailScreen(plan: plan)),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  MealPlan _parsePlan(Map<String, dynamic> json) {
    final meals = (json['meals'] as List).map((m) {
      final mj = m as Map<String, dynamic>;
      final ingredients = (mj['ingredients'] as List? ?? []).map((i) {
        final ij = i as Map<String, dynamic>;
        return Ingredient(
          name: ij['name'] ?? '',
          quantity: ij['quantity'] ?? '',
          estimatedPriceZAR: (ij['estimated_price_zar'] as num?)?.toDouble() ?? 0,
          category: ij['category'] ?? 'pantry',
        );
      }).toList();

      return PlanMeal(
        id: 'gen_${DateTime.now().millisecondsSinceEpoch}_${mj['meal_type']}',
        name: mj['name'] ?? 'Unnamed Meal',
        mealType: mj['meal_type'] ?? 'lunch',
        calories: (mj['calories'] as num?)?.toInt() ?? 0,
        protein: (mj['protein'] as num?)?.toInt() ?? 0,
        carbs: (mj['carbs'] as num?)?.toInt() ?? 0,
        fat: (mj['fat'] as num?)?.toInt() ?? 0,
        emoji: mj['emoji'] ?? '🍽️',
        recipe: mj['recipe'] ?? '',
        ingredients: ingredients,
      );
    }).toList();

    return MealPlan(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      name: json['plan_name'] ?? 'Custom Meal Plan',
      description: json['description'] ?? 'AI-generated meal plan tailored to your goals.',
      category: json['category'] ?? 'balanced',
      budgetTier: json['budget_tier'] ?? 'r100',
      estimatedCostZAR: (json['estimated_cost_zar'] as num?)?.toDouble() ?? 0,
      totalCalories: (json['total_calories'] as num?)?.toInt() ?? 0,
      totalProtein: (json['total_protein'] as num?)?.toInt() ?? 0,
      totalCarbs: (json['total_carbs'] as num?)?.toInt() ?? 0,
      totalFat: (json['total_fat'] as num?)?.toInt() ?? 0,
      servings: 1,
      prepTimeMin: (json['prep_time_min'] as num?)?.toInt() ?? 30,
      emoji: json['emoji'] ?? '🤖',
      meals: meals,
      tags: ['ai-generated', 'personalised'],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      decoration: const BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: CLColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: CLColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('🤖', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Generate My Meal Plan',
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  Text('AI creates a plan tailored to you',
                      style: TextStyle(color: CLColors.muted, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Calorie goal display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CLColors.accentLo,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CLColors.accent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_fire_department,
                    color: CLColors.accent, size: 16),
                const SizedBox(width: 6),
                Text('Target: ${state.calorieGoal} kcal/day',
                    style: const TextStyle(
                        color: CLColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                const Text('Based on your profile',
                    style: TextStyle(color: CLColors.muted, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Dietary preference
          const Text('Dietary preference',
              style: TextStyle(
                  color: CLColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _dietaryOptions.map((opt) {
              final (id, label) = opt;
              final active = _dietary == id;
              return GestureDetector(
                onTap: () => setState(() => _dietary = id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active
                        ? CLColors.accent.withOpacity(0.12)
                        : CLColors.surface2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: active
                          ? CLColors.accent.withOpacity(0.5)
                          : CLColors.border,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: active ? CLColors.accent : CLColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Error
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CLColors.redLo,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CLColors.red.withOpacity(0.3)),
              ),
              child: Text('⚠ $_error',
                  style: const TextStyle(
                      color: CLColors.red, fontSize: 12)),
            ),
            const SizedBox(height: 12),
          ],

          // Generate button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generate,
              icon: _loading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(_loading
                  ? 'GENERATING YOUR PLAN...'
                  : 'GENERATE MY MEAL PLAN'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
