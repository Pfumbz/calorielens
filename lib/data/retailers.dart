import '../models/meal_plan.dart';

/// South African retailers with search URL templates.
/// {query} is replaced with the URL-encoded ingredient name.
const List<Retailer> kRetailers = [
  // ── Supermarkets ──────────────────────────────────────────────────
  Retailer(
    id: 'checkers',
    name: 'Checkers',
    emoji: '🔴',
    searchUrlTemplate: 'https://www.checkers.co.za/search/all?q={query}',
  ),
  Retailer(
    id: 'pnp',
    name: 'Pick n Pay',
    emoji: '🔵',
    searchUrlTemplate: 'https://www.pnp.co.za/search?q={query}',
  ),
  Retailer(
    id: 'woolworths',
    name: 'Woolworths',
    emoji: '🟤',
    searchUrlTemplate: 'https://www.woolworths.co.za/cat?Ntt={query}',
  ),
  Retailer(
    id: 'shoprite',
    name: 'Shoprite',
    emoji: '🟡',
    searchUrlTemplate: 'https://www.shoprite.co.za/search/all?q={query}',
  ),

  // ── Delivery services ─────────────────────────────────────────────
  Retailer(
    id: 'sixty60',
    name: 'Sixty60',
    emoji: '🚀',
    searchUrlTemplate: 'https://www.sixty60.co.za/search?q={query}',
    appDeepLinkTemplate: 'sixty60://search?q={query}',
  ),
  Retailer(
    id: 'mrd',
    name: 'Mr D Food',
    emoji: '🟢',
    searchUrlTemplate: 'https://www.mrdfood.com/',
  ),
];

/// Returns a retailer by ID, or null.
Retailer? retailerById(String id) {
  try {
    return kRetailers.firstWhere((r) => r.id == id);
  } catch (_) {
    return null;
  }
}

/// The default retailers shown for each budget tier.
/// Budget → Checkers/Shoprite first; Premium → Woolworths first.
List<Retailer> retailersForBudgetTier(String tier) {
  switch (tier) {
    case 'r50':
      return kRetailers.where((r) =>
        r.id == 'shoprite' || r.id == 'checkers' || r.id == 'pnp'
      ).toList();
    case 'r100':
      return kRetailers.where((r) =>
        r.id == 'checkers' || r.id == 'pnp' || r.id == 'woolworths'
      ).toList();
    case 'r150':
      return kRetailers.where((r) =>
        r.id == 'woolworths' || r.id == 'checkers' || r.id == 'pnp'
      ).toList();
    default:
      return kRetailers.where((r) =>
        r.id != 'mrd' // exclude Mr D for groceries — it's mainly restaurants
      ).toList();
  }
}
