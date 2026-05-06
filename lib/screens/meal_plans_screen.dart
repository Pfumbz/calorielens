import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../data/meal_plans.dart';
import '../models/meal_plan.dart';
import '../services/food_image_service.dart';
import '../theme.dart';
import '../widgets/ad_banner.dart';
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
  bool _showMyPlans = false; // toggles between Popular Plans and My Plans (Free)

  static const _categories = [
    ('all', '🍽️', 'All'),
    ('balanced', '⚖️', 'Balanced'),
    ('high-protein', '💪', 'High Protein'),
    ('vegetarian', '🌱', 'Veggie'),
    ('budget', '💰', 'Budget'),
    ('bulk-cook', '📦', 'Meal Prep'),
  ];

  // ── Category tag colour helper ──────────────────────────────────────
  static Color _catColor(String category) {
    switch (category) {
      case 'budget':
        return CLColors.green;
      case 'high-protein':
        return CLColors.accent;
      case 'vegetarian':
        return const Color(0xFF6DBF4A);
      case 'balanced':
        return CLColors.blue;
      case 'bulk-cook':
        return CLColors.purple;
      default:
        return CLColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isPro = state.isPremium || state.hasApiKey;

    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: isPro ? _buildProLayout(state) : _buildFreeLayout(state),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── FREE LAYOUT ─────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFreeLayout(AppState state) {
    final plans = _showMyPlans
        ? kMealPlans.where((p) => state.isPlanSaved(p.id)).toList()
        : filterPlans(category: _selectedCat);

    return CustomScrollView(
      slivers: [
        // ── Header ──────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Meal Plans',
                    style: TextStyle(
                        color: CLColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text(
                  'Simple plans to keep you on track.',
                  style: TextStyle(color: CLColors.muted, fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        // ── Generate Plan / My Plans toggle ─────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.auto_awesome,
                    label: 'Generate Plan',
                    filled: true,
                    onTap: () => showGeneratePlanSheet(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.bookmark_outline,
                    label: 'My Plans',
                    filled: _showMyPlans,
                    onTap: () => setState(() => _showMyPlans = !_showMyPlans),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Ad banner ───────────────────────────────────────────
        const SliverToBoxAdapter(child: AdBanner()),

        // ── Upgrade banner (just below ads) ─────────────────────
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => showUpgradeModal(context, source: 'meal_plans'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: CLColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CLColors.border),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline,
                      color: CLColors.muted, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unlock Pro for personalised recommendations, fridge scanning and more.',
                      style: TextStyle(
                          color: CLColors.muted,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Upgrade',
                      style: TextStyle(
                          color: CLColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Icon(Icons.chevron_right,
                      color: CLColors.accent, size: 18),
                ],
              ),
            ),
          ),
        ),

        // ── Category filter chips (only when showing Popular) ───
        if (!_showMyPlans)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                      child: Text('$emoji  $label',
                          style: TextStyle(
                            color: active ? CLColors.accent : CLColors.muted,
                            fontSize: 12.5,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          )),
                    ),
                  );
                },
              ),
            ),
          ),

        // ── Section header ──────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: Text(
              _showMyPlans ? 'My Saved Plans' : 'Popular Plans',
              style: const TextStyle(
                  color: CLColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),

        // ── 2×2 Plan grid ───────────────────────────────────────
        plans.isEmpty
            ? SliverFillRemaining(child: _buildEmpty(_showMyPlans))
            : SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _PlanCard(
                      plan: plans[i],
                      catColor: _catColor(plans[i].category),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                PlanDetailScreen(plan: plans[i])),
                      ),
                    ),
                    childCount: plans.length,
                  ),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.68,
                  ),
                ),
              ),

        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── PRO LAYOUT ──────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildProLayout(AppState state) {
    // Recommended plans — pick by what user might need
    final recommended = _getRecommendedPlans(state);
    final savedIds = state.savedPlanIds;
    final savedPlans =
        kMealPlans.where((p) => savedIds.contains(p.id)).toList();

    return CustomScrollView(
      slivers: [
        // ── Header with PRO badge ───────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Meal Plans',
                          style: TextStyle(
                              color: CLColors.text,
                              fontSize: 24,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      const Text(
                        'Personalised plans built around you.',
                        style:
                            TextStyle(color: CLColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFFC4A040), Color(0xFFA08030)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.workspace_premium,
                          color: Color(0xFF0E0C08), size: 13),
                      SizedBox(width: 4),
                      Text('PRO',
                          style: TextStyle(
                              color: Color(0xFF0E0C08),
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Action cards: Scan Fridge + Generate Plan ────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: _ProActionCard(
                    icon: Icons.camera_alt_outlined,
                    title: 'Scan My Fridge',
                    subtitle: 'See what you have\nand get meal ideas',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FridgeScanScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ProActionCard(
                    icon: Icons.auto_awesome,
                    title: 'Generate Plan',
                    subtitle: 'AI-powered plan based\non your goals',
                    onTap: () => showGeneratePlanSheet(context),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Recommended-for-you insight card ─────────────────────
        SliverToBoxAdapter(
          child: _RecommendedInsightCard(state: state),
        ),

        // ── Recommended For You — horizontal scroll ──────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                const Text('Recommended For You',
                    style: TextStyle(
                        color: CLColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    // Show all plans in a simple bottom sheet
                    _showAllPlans(context);
                  },
                  child: const Text('See all',
                      style: TextStyle(
                          color: CLColors.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),

        // ── Horizontal meal cards ────────────────────────────────
        SliverToBoxAdapter(
          child: SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              itemCount: recommended.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => SizedBox(
                width: 170,
                child: _HorizontalPlanCard(
                  plan: recommended[i],
                  catColor: _catColor(recommended[i].category),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            PlanDetailScreen(plan: recommended[i])),
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Your Saved Plans ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
            child: Row(
              children: [
                const Text('Your Saved Plans',
                    style: TextStyle(
                        color: CLColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                if (savedPlans.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showAllPlans(context, savedOnly: true),
                    child: const Text('View all',
                        style: TextStyle(
                            color: CLColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
        ),

        // ── Saved plans list items ──────────────────────────────
        if (savedPlans.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: CLColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: CLColors.border),
                ),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_border,
                        color: CLColors.muted, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tap the bookmark icon on any plan to save it here.',
                        style: TextStyle(
                            color: CLColors.muted,
                            fontSize: 13,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _SavedPlanRow(
                plan: savedPlans[i],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          PlanDetailScreen(plan: savedPlans[i])),
                ),
              ),
              childCount: savedPlans.length.clamp(0, 3),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 90)),
      ],
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  List<MealPlan> _getRecommendedPlans(AppState state) {
    // Smart recommendation: pick plans based on remaining macros
    final proteinPct = state.calorieGoal > 0
        ? (state.totalProtein * 4 / state.calorieGoal)
        : 0.0;

    List<MealPlan> recommended;
    if (proteinPct < 0.2) {
      // Low protein → prioritise high-protein plans
      recommended = [
        ...kMealPlans.where((p) => p.category == 'high-protein'),
        ...kMealPlans.where((p) => p.category == 'balanced'),
      ];
    } else {
      // Balanced mix
      recommended = [
        ...kMealPlans.where((p) => p.category == 'balanced'),
        ...kMealPlans.where((p) => p.category == 'high-protein'),
        ...kMealPlans.where((p) => p.category == 'vegetarian'),
      ];
    }

    // Deduplicate and limit
    final seen = <String>{};
    return recommended
        .where((p) => seen.add(p.id))
        .take(6)
        .toList();
  }

  String _getRecommendationReason(AppState state) {
    final proteinPct = state.calorieGoal > 0
        ? (state.totalProtein * 4 / state.calorieGoal)
        : 0.0;
    final fatPct = state.calorieGoal > 0
        ? (state.totalFat * 9 / state.calorieGoal)
        : 0.0;

    if (state.diary.isEmpty) {
      return "You haven't logged any meals yet today. These plans will help you hit your ${state.calorieGoal} kcal goal.";
    }
    if (proteinPct < 0.2) {
      return "You're low on protein today. These high-protein meals will help you hit your target.";
    }
    if (fatPct > 0.35) {
      return "Your fat intake is a bit high today. These balanced plans keep macros in check.";
    }
    return "Based on your eating patterns, these plans align with your ${state.calorieGoal} kcal daily goal.";
  }

  void _showAllPlans(BuildContext context, {bool savedOnly = false}) {
    final state = context.read<AppState>();
    final plans = savedOnly
        ? kMealPlans.where((p) => state.isPlanSaved(p.id)).toList()
        : kMealPlans;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AllPlansScreen(
          plans: plans,
          title: savedOnly ? 'Saved Plans' : 'All Plans',
          catColor: _catColor,
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isSavedView) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSavedView ? Icons.bookmark_border : Icons.restaurant_menu,
            color: CLColors.muted,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            isSavedView
                ? 'No saved plans yet'
                : 'No plans match your filters',
            style: const TextStyle(
                color: CLColors.text,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            isSavedView
                ? 'Bookmark a plan to save it here'
                : 'Try a different category',
            style: const TextStyle(color: CLColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── FREE: Action button (Generate Plan / My Plans) ───────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        decoration: BoxDecoration(
          color: filled ? CLColors.accent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled
                ? CLColors.accent.withOpacity(0.5)
                : CLColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: filled ? CLColors.accent : CLColors.muted, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: filled ? CLColors.accent : CLColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── FREE: Plan card (2×2 grid) ───────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _PlanCard extends StatefulWidget {
  final MealPlan plan;
  final Color catColor;
  final VoidCallback onTap;
  const _PlanCard(
      {required this.plan, required this.catColor, required this.onTap});

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  late Future<String> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = FoodImageService.getSmartImageUrl(widget.plan.name);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final fallbackUrl =
        plan.imageUrl ?? FoodImageService.getThumbnailUrl(plan.name);
    final catLabel = plan.category.replaceAll('-', ' ').toUpperCase();

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
            // ── Hero image with badges ──
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
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: CLColors.accent),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: CLColors.surface2,
                          child: Center(
                            child: Text(plan.emoji,
                                style: const TextStyle(fontSize: 36)),
                          ),
                        ),
                      );
                    },
                  ),
                  // Category tag (top-left)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.catColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        catLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Calorie badge (top-right)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
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
                    // Macro chips
                    Row(
                      children: [
                        _macroChip('P', '${plan.totalProtein}g', CLColors.blue),
                        const SizedBox(width: 4),
                        _macroChip(
                            'C', '${plan.totalCarbs}g', CLColors.green),
                        const SizedBox(width: 4),
                        _macroChip(
                            'F', '${plan.totalFat}g', CLColors.accent),
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
        style: TextStyle(
            color: color, fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── PRO: Action card (Scan Fridge / Generate Plan) ───────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _ProActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CLColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: CLColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: CLColors.accent, size: 18),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                    color: CLColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(
                    color: CLColors.muted, fontSize: 11, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── PRO: Recommended insight card ────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _RecommendedInsightCard extends StatelessWidget {
  final AppState state;
  const _RecommendedInsightCard({required this.state});

  String _getReason() {
    final proteinPct = state.calorieGoal > 0
        ? (state.totalProtein * 4 / state.calorieGoal)
        : 0.0;
    final fatPct = state.calorieGoal > 0
        ? (state.totalFat * 9 / state.calorieGoal)
        : 0.0;

    if (state.diary.isEmpty) {
      return "You haven't logged any meals today. Start with a plan that fits your ${state.calorieGoal} kcal goal.";
    }
    if (proteinPct < 0.2) {
      return "You're low on protein today. These high-protein meals will help you hit your target.";
    }
    if (fatPct > 0.35) {
      return "Your fat intake is a bit high. These balanced plans keep your macros in check.";
    }
    return "Based on today's meals, these plans align with your ${state.calorieGoal} kcal daily goal.";
  }

  @override
  Widget build(BuildContext context) {
    // Pick a representative plan for the thumbnail
    final representativePlan = state.totalProtein < 40
        ? kMealPlans.firstWhere((p) => p.category == 'high-protein',
            orElse: () => kMealPlans.first)
        : kMealPlans.firstWhere((p) => p.category == 'balanced',
            orElse: () => kMealPlans.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CLColors.gold.withOpacity(0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome,
                          color: CLColors.gold, size: 16),
                      const SizedBox(width: 6),
                      const Text('Recommended for you',
                          style: TextStyle(
                              color: CLColors.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: CLColors.surface2,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Why?',
                            style: TextStyle(
                                color: CLColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _getReason(),
                    style: const TextStyle(
                        color: CLColors.muted,
                        fontSize: 12,
                        height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Thumbnail
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl:
                    FoodImageService.getThumbnailUrl(representativePlan.name),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: CLColors.surface2,
                  child: Center(
                    child: Text(representativePlan.emoji,
                        style: const TextStyle(fontSize: 24)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── PRO: Horizontal plan card (scrollable row) ───────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _HorizontalPlanCard extends StatefulWidget {
  final MealPlan plan;
  final Color catColor;
  final VoidCallback onTap;
  const _HorizontalPlanCard(
      {required this.plan, required this.catColor, required this.onTap});

  @override
  State<_HorizontalPlanCard> createState() => _HorizontalPlanCardState();
}

class _HorizontalPlanCardState extends State<_HorizontalPlanCard> {
  late Future<String> _imageFuture;

  @override
  void initState() {
    super.initState();
    _imageFuture = FoodImageService.getSmartImageUrl(widget.plan.name);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final fallbackUrl =
        plan.imageUrl ?? FoodImageService.getThumbnailUrl(plan.name);
    final catLabel = plan.category.replaceAll('-', ' ').toUpperCase();

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
            // Image
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
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: CLColors.accent),
                            ),
                          ),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: CLColors.surface2,
                          child: Center(
                            child: Text(plan.emoji,
                                style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      );
                    },
                  ),
                  // Category + calorie badges
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.catColor.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        catLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 7.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${plan.totalCalories} kcal',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: CLColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        _chip('P:${plan.totalProtein}g', CLColors.blue),
                        const SizedBox(width: 4),
                        _chip('C:${plan.totalCarbs}g', CLColors.green),
                        const SizedBox(width: 4),
                        _chip('F:${plan.totalFat}g', CLColors.accent),
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

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 8.5, fontWeight: FontWeight.w600)),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── PRO: Saved plan list row ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _SavedPlanRow extends StatelessWidget {
  final MealPlan plan;
  final VoidCallback onTap;
  const _SavedPlanRow({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: CLColors.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(plan.emoji,
                    style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.name,
                      style: const TextStyle(
                          color: CLColors.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '${plan.meals.length} meals • ${plan.totalCalories} kcal',
                    style: const TextStyle(
                        color: CLColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: CLColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── Full plans listing screen (See all / View all) ───────────────────────
// ═══════════════════════════════════════════════════════════════════════════
class _AllPlansScreen extends StatelessWidget {
  final List<MealPlan> plans;
  final String title;
  final Color Function(String) catColor;

  const _AllPlansScreen({
    required this.plans,
    required this.title,
    required this.catColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      appBar: AppBar(
        backgroundColor: CLColors.bg,
        title: Text(title,
            style: const TextStyle(color: CLColors.text, fontSize: 18)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: plans.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.restaurant_menu,
                      color: CLColors.muted, size: 48),
                  SizedBox(height: 14),
                  Text('No plans found',
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.68,
              ),
              itemCount: plans.length,
              itemBuilder: (ctx, i) => _PlanCard(
                plan: plans[i],
                catColor: catColor(plans[i].category),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PlanDetailScreen(plan: plans[i])),
                ),
              ),
            ),
    );
  }
}
