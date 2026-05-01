import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../data/meal_plans.dart';
import '../models/meal_plan.dart';
import '../services/food_image_service.dart';
import '../theme.dart';
import '../widgets/generate_plan_sheet.dart';
import '../widgets/upgrade_modal.dart';
import 'fridge_scan_screen.dart';
import 'plan_detail_screen.dart';

class MealPlansScreen extends StatefulWidget {
  const MealPlansScreen({super.key});

  @override
  State<MealPlansScreen> createState() => _MealPlansScreenState();
}

class _MealPlansScreenState extends State<MealPlansScreen> {
  String _selectedCat = 'all';

  static const _categories = [
    ('all',          '🍽️', 'All'),
    ('balanced',     '⚖️', 'Balanced'),
    ('high-protein', '💪', 'Protein'),
    ('vegetarian',   '🌱', 'Veggie'),
    ('budget',       '💰', 'Budget'),
    ('bulk-cook',    '📦', 'Meal Prep'),
  ];

  @override
  Widget build(BuildContext context) {
    final plans = filterPlans(category: _selectedCat);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Meal Plans',
                        style: TextStyle(
                            color: CLColors.text,
                            fontSize: 24,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    const Text(
                      'Personalised plans based on your goals',
                      style: TextStyle(color: CLColors.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

            // ── AI action buttons ────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _AiActionChip(
                        icon: Icons.auto_awesome,
                        label: 'Generate Plan',
                        color: CLColors.accent,
                        onTap: () => showGeneratePlanSheet(context),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _AiActionChip(
                        icon: Icons.camera_alt_outlined,
                        label: 'Scan Fridge',
                        color: CLColors.green,
                        onTap: () {
                          final state = context.read<AppState>();
                          if (!state.isPremium && !state.hasApiKey) {
                            showUpgradeModal(context, source: 'fridge_scan');
                            return;
                          }
                          Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const FridgeScanScreen()));
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Category chips ───────────────────────────────
            SliverToBoxAdapter(
              child: SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (id, emoji, label) = _categories[i];
                    final active = _selectedCat == id;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCat = id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? CLColors.accentLo : CLColors.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: active ? CLColors.accent.withOpacity(0.6) : CLColors.border,
                          ),
                        ),
                        child: Text('$emoji  $label',
                            style: TextStyle(
                              color: active ? CLColors.accent : CLColors.muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            )),
                      ),
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Pinterest-style grid ─────────────────────────
            plans.isEmpty
                ? SliverFillRemaining(child: _buildEmpty())
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _PlanPhotoCard(
                          plan: plans[i],
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => PlanDetailScreen(plan: plans[i]))),
                        ),
                        childCount: plans.length,
                      ),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                    ),
                  ),

            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.restaurant_menu, color: CLColors.muted, size: 48),
          const SizedBox(height: 14),
          const Text('No plans match your filters',
              style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Try a different category',
              style: TextStyle(color: CLColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Pinterest-style photo card ────────────────────────────────────────────────
class _PlanPhotoCard extends StatefulWidget {
  final MealPlan plan;
  final VoidCallback onTap;
  const _PlanPhotoCard({required this.plan, required this.onTap});

  @override
  State<_PlanPhotoCard> createState() => _PlanPhotoCardState();
}

class _PlanPhotoCardState extends State<_PlanPhotoCard> {
  late Future<String> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = FoodImageService.getSmartImageUrl(widget.plan.name);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final fallbackUrl = plan.imageUrl ?? FoodImageService.getThumbnailUrl(plan.name);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: CLColors.surface,
          border: Border.all(color: CLColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Hero image ──
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<String>(
                    future: _imageFuture,
                    builder: (context, snap) {
                      final url = snap.data ?? fallbackUrl;
                      return CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          color: CLColors.surface2,
                          child: const Center(
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: CLColors.accent),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: CLColors.surface2,
                          child: Center(
                            child: Text(plan.emoji, style: const TextStyle(fontSize: 36)),
                          ),
                        ),
                      );
                    },
                  ),
                  // Calorie badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${plan.totalCalories} kcal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Category chip
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: CLColors.accent.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        plan.category.replaceAll('-', ' ').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ── Text info ──
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CLColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Macro chips row
                    Row(
                      children: [
                        _macroChip('P', '${plan.totalProtein}g', CLColors.blue),
                        const SizedBox(width: 4),
                        _macroChip('C', '${plan.totalCarbs}g', CLColors.green),
                        const SizedBox(width: 4),
                        _macroChip('F', '${plan.totalFat}g', CLColors.accent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label:$value',
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── AI Action Chip ──────────────────────────────────────────────────────────
class _AiActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AiActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
