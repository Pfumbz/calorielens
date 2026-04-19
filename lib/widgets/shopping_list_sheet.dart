import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/retailers.dart';
import '../models/meal_plan.dart';
import '../theme.dart';

/// Shows the shopping list as a bottom sheet with retailer deep links.
void showShoppingListSheet(
  BuildContext context, {
  required List<Ingredient> ingredients,
  required String budgetTier,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShoppingListSheet(
      ingredients: ingredients,
      budgetTier: budgetTier,
    ),
  );
}

class ShoppingListSheet extends StatelessWidget {
  final List<Ingredient> ingredients;
  final String budgetTier;
  const ShoppingListSheet({
    super.key,
    required this.ingredients,
    required this.budgetTier,
  });

  @override
  Widget build(BuildContext context) {
    final total = ingredients.fold(0.0, (s, i) => s + i.estimatedPriceZAR);
    final grouped = _groupByCategory(ingredients);
    final retailers = retailersForBudgetTier(budgetTier);

    return Container(
      decoration: const BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, ctrl) => Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: CLColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Shopping List',
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: CLColors.green.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: CLColors.green.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Total: ~R${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: CLColors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Estimated prices · tap a store to search',
                style: TextStyle(
                    color: CLColors.muted.withOpacity(0.7), fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),

            // Retailer quick-links
            SizedBox(
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: retailers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _RetailerChip(
                  retailer: retailers[i],
                  onTap: () => _openRetailerSearch(
                    retailers[i],
                    ingredients.map((e) => e.name).join(' '),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Ingredient list grouped by category
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final group in grouped.entries) ...[
                    _sectionHeader(group.key),
                    ...group.value.map((ing) => _IngredientRow(
                          ingredient: ing,
                          retailers: retailers,
                        )),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String category) {
    final emoji = _categoryEmoji(category);
    final label = category[0].toUpperCase() + category.substring(1);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        '$emoji  $label',
        style: const TextStyle(
            color: CLColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Map<String, List<Ingredient>> _groupByCategory(List<Ingredient> items) {
    final map = <String, List<Ingredient>>{};
    // Order: protein, produce, grain, dairy, spice, pantry
    const order = ['protein', 'produce', 'grain', 'dairy', 'spice', 'pantry'];
    for (final cat in order) {
      final filtered = items.where((i) => i.category == cat).toList();
      if (filtered.isNotEmpty) map[cat] = filtered;
    }
    // Catch any uncategorised
    final uncategorised =
        items.where((i) => !order.contains(i.category)).toList();
    if (uncategorised.isNotEmpty) map['other'] = uncategorised;
    return map;
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

  Future<void> _openRetailerSearch(
      Retailer retailer, String searchTerms) async {
    final url = retailer.searchUrl(searchTerms);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ── Retailer chip ────────────────────────────────────────────────────────────
class _RetailerChip extends StatelessWidget {
  final Retailer retailer;
  final VoidCallback onTap;
  const _RetailerChip({required this.retailer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CLColors.surface2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(retailer.emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(retailer.name,
                style: const TextStyle(
                    color: CLColors.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_new,
                color: CLColors.muted.withOpacity(0.5), size: 12),
          ],
        ),
      ),
    );
  }
}

// ── Ingredient row ───────────────────────────────────────────────────────────
class _IngredientRow extends StatelessWidget {
  final Ingredient ingredient;
  final List<Retailer> retailers;
  const _IngredientRow({required this.ingredient, required this.retailers});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: CLColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ingredient.name,
                    style: const TextStyle(
                        color: CLColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(ingredient.quantity,
                    style: const TextStyle(
                        color: CLColors.muted, fontSize: 11)),
              ],
            ),
          ),
          Text('~R${ingredient.estimatedPriceZAR.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: CLColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          // Quick retailer buttons
          ...retailers.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(left: 4),
                child: GestureDetector(
                  onTap: () async {
                    final url = r.searchUrl(ingredient.name);
                    final uri = Uri.parse(url);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: CLColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: CLColors.border),
                    ),
                    child: Center(
                      child: Text(r.emoji,
                          style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
