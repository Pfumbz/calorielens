import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../data/meal_plans.dart';
import '../models/meal_plan.dart';
import '../theme.dart';
import '../widgets/generate_plan_sheet.dart';
import '../widgets/upgrade_modal.dart';
import 'fridge_scan_screen.dart';
import 'plan_detail_screen.dart';

/// Browse screen for curated meal plans.
/// Replaces the Workout tab in bottom navigation.
class MealPlansScreen extends StatefulWidget {
  const MealPlansScreen({super.key});

  @override
  State<MealPlansScreen> createState() => _MealPlansScreenState();
}

class _MealPlansScreenState extends State<MealPlansScreen> {
  String _selectedCat = 'all';
  String _selectedBudget = 'all';

  static const _categories = [
    ('all',          '🍽️', 'All'),
    ('budget',       '💰', 'Budget'),
    ('balanced',     '⚖️', 'Balanced'),
    ('high-protein', '💪', 'Protein'),
    ('vegetarian',   '🌱', 'Veggie'),
    ('bulk-cook',    '📦', 'Meal Prep'),
  ];

  static const _budgetTiers = [
    ('all',  'All prices'),
    ('r50',  'Under R50'),
    ('r100', 'Under R100'),
    ('r150', 'Under R150'),
  ];

  @override
  Widget build(BuildContext context) {
    final plans = filterPlans(
      category: _selectedCat,
      budgetTier: _selectedBudget,
    );

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Meal Plans',
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w600)),
                  _buildBudgetDropdown(),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'South African meals · shop at your favourite store',
                style: TextStyle(color: CLColors.muted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 14),

            // ── AI feature buttons (Pro/BYOK gated) ────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _AiActionButton(
                      emoji: '🤖',
                      label: 'Generate My Plan',
                      subtitle: 'AI-personalised',
                      color: CLColors.accent,
                      onTap: () => showGeneratePlanSheet(context),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _AiActionButton(
                      emoji: '📷',
                      label: 'Scan My Fridge',
                      subtitle: 'What can I make?',
                      color: CLColors.green,
                      onTap: () {
                        final state = context.read<AppState>();
                        if (!state.isPremium && !state.hasApiKey) {
                          showUpgradeModal(context, source: 'fridge_scan');
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const FridgeScanScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── Category chips ──────────────────────────────────
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (id, emoji, label) = _categories[i];
                  final active = _selectedCat == id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCat = id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? CLColors.accentLo : CLColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: active
                              ? CLColors.accent.withOpacity(0.6)
                              : CLColors.border,
                        ),
                      ),
                      child: Text(
                        '$emoji  $label',
                        style: TextStyle(
                          color: active ? CLColors.accent : CLColors.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // ── Plan cards ──────────────────────────────────────
            Expanded(
              child: plans.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: plans.length,
                      itemBuilder: (_, i) => _PlanCard(
                        plan: plans[i],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PlanDetailScreen(plan: plans[i]),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CLColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBudget,
          dropdownColor: CLColors.surface,
          style: const TextStyle(color: CLColors.text, fontSize: 12),
          icon: const Icon(Icons.keyboard_arrow_down,
              color: CLColors.muted, size: 16),
          items: _budgetTiers.map((t) {
            final (id, label) = t;
            return DropdownMenuItem(value: id, child: Text(label));
          }).toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedBudget = v);
          },
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          const Text('No plans match your filters',
              style: TextStyle(
                  color: CLColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Try a different category or budget',
              style: TextStyle(color: CLColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Plan Card ────────────────────────────────────────────────────────────────
class _PlanCard extends StatelessWidget {
  final MealPlan plan;
  final VoidCallback onTap;
  const _PlanCard({required this.plan, required this.onTap});

  // Gradient colours based on budget tier
  List<Color> get _gradientColors {
    switch (plan.budgetTier) {
      case 'r50':
        return [const Color(0xFF1A2010), const Color(0xFF0E1208)];
      case 'r100':
        return [const Color(0xFF1A1508), const Color(0xFF110F0D)];
      case 'r150':
        return [const Color(0xFF1A1020), const Color(0xFF0E0C14)];
      default:
        return [CLColors.surface, CLColors.surface2];
    }
  }

  Color get _accentColor {
    switch (plan.budgetTier) {
      case 'r50':
        return CLColors.green;
      case 'r100':
        return CLColors.accent;
      case 'r150':
        return CLColors.purple;
      default:
        return CLColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _accentColor.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            // Emoji icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _accentColor.withOpacity(0.25)),
              ),
              child: Center(
                child: Text(plan.emoji,
                    style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      style: const TextStyle(
                          color: CLColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(plan.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: CLColors.muted, fontSize: 11, height: 1.3)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _tag('R${plan.estimatedCostZAR.toStringAsFixed(0)}',
                          _accentColor),
                      _tag('${plan.totalCalories} kcal', CLColors.muted),
                      _tag('${plan.prepTimeMin} min', CLColors.muted),
                      if (plan.servings > 1)
                        _tag('${plan.servings} servings', CLColors.muted),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                color: _accentColor.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w500)),
    );
  }
}

// ── AI Action Button ────────────────────────────────────────────────────────
class _AiActionButton extends StatelessWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AiActionButton({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      style: const TextStyle(
                          color: CLColors.muted, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }
}
