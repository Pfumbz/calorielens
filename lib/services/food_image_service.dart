import 'pexels_service.dart';

/// Maps food/meal names to photo URLs.
/// Primary: Pexels API search (async, cached locally).
/// Fallback: curated Unsplash photo URLs (sync, always available).
///
/// Sync methods (getThumbnailUrl, getHeroUrl) return Unsplash URLs instantly.
/// Async method (getSmartImageUrl) tries Pexels first, falls back to Unsplash.

class FoodImageService {
  /// Returns a photo URL for the given meal name / food description (sync fallback).
  static String getImageUrl(String mealName, {int width = 400, int height = 300}) {
    final category = _detectCategory(mealName.toLowerCase());
    final photos = _categoryPhotos[category] ?? _categoryPhotos['meal']!;
    // Deterministic selection based on meal name hash (same name = same photo)
    final index = mealName.hashCode.abs() % photos.length;
    final photoId = photos[index];
    return 'https://images.unsplash.com/photo-$photoId?w=$width&h=$height&fit=crop&q=80';
  }

  /// Returns a smaller thumbnail URL (sync).
  static String getThumbnailUrl(String mealName) =>
      getImageUrl(mealName, width: 300, height: 220);

  /// Returns a hero-sized image URL (sync).
  static String getHeroUrl(String mealName) =>
      getImageUrl(mealName, width: 800, height: 500);

  /// Tries Pexels API first (returns a real food photo matching the meal name),
  /// falls back to the curated Unsplash URL if Pexels fails or has no key.
  static Future<String> getSmartImageUrl(String mealName, {bool hero = false}) async {
    try {
      final pexelsUrl = await PexelsService.searchFoodPhoto(mealName);
      if (pexelsUrl != null) return pexelsUrl;
    } catch (_) {}
    // Fallback to curated Unsplash
    return hero ? getHeroUrl(mealName) : getThumbnailUrl(mealName);
  }

  static String _detectCategory(String name) {
    // Breakfast
    if (_matchesAny(name, ['oat', 'porridge', 'cereal', 'muesli', 'granola',
        'pancake', 'waffle', 'french toast', 'muffin', 'breakfast'])) {
      return 'breakfast';
    }
    // Eggs
    if (_matchesAny(name, ['egg', 'omelette', 'scramble', 'frittata'])) {
      return 'eggs';
    }
    // Salad
    if (_matchesAny(name, ['salad', 'slaw', 'coleslaw'])) {
      return 'salad';
    }
    // Smoothie / juice
    if (_matchesAny(name, ['smoothie', 'juice', 'shake', 'protein shake'])) {
      return 'smoothie';
    }
    // Soup
    if (_matchesAny(name, ['soup', 'stew', 'broth', 'chowder'])) {
      return 'soup';
    }
    // Grilled / meat
    if (_matchesAny(name, ['grill', 'steak', 'braai', 'boerewors', 'chop',
        'roast', 'bbq', 'barbeque'])) {
      return 'grilled';
    }
    // Chicken
    if (_matchesAny(name, ['chicken', 'wing', 'drumstick', 'thigh'])) {
      return 'chicken';
    }
    // Fish / seafood
    if (_matchesAny(name, ['fish', 'salmon', 'tuna', 'hake', 'prawn', 'seafood',
        'snoek'])) {
      return 'fish';
    }
    // Rice / grain bowls
    if (_matchesAny(name, ['rice', 'biryani', 'pilaf', 'fried rice', 'bowl',
        'buddha bowl', 'grain bowl'])) {
      return 'rice_bowl';
    }
    // Pasta / noodles
    if (_matchesAny(name, ['pasta', 'spaghetti', 'noodle', 'macaroni',
        'penne', 'lasagna'])) {
      return 'pasta';
    }
    // Bread / sandwich / wrap
    if (_matchesAny(name, ['sandwich', 'wrap', 'burger', 'toast', 'bread',
        'vetkoek', 'bunny chow', 'gatsby'])) {
      return 'sandwich';
    }
    // SA staples
    if (_matchesAny(name, ['pap', 'chakalaka', 'samp', 'mogodu', 'morogo',
        'umngqusho', 'umphokoqo', 'mielie'])) {
      return 'african';
    }
    // Curry
    if (_matchesAny(name, ['curry', 'masala', 'tikka', 'vindaloo', 'cape malay'])) {
      return 'curry';
    }
    // Snack / fruit
    if (_matchesAny(name, ['snack', 'fruit', 'apple', 'banana', 'yoghurt',
        'yogurt', 'nut', 'biltong', 'dried'])) {
      return 'snack';
    }
    // Vegetable / veggie
    if (_matchesAny(name, ['vegetable', 'veggie', 'roasted veg', 'stir fry',
        'stir-fry'])) {
      return 'vegetables';
    }
    // Default
    return 'meal';
  }

  static bool _matchesAny(String text, List<String> keywords) {
    return keywords.any((k) => text.contains(k));
  }

  // ── Curated Unsplash photo IDs per category ─────────────────────────────
  // Each entry is the photo ID portion after "photo-" in the Unsplash URL.
  static const _categoryPhotos = <String, List<String>>{
    'breakfast': [
      '1504754524776-8f4f37790ca0',
      '1533089860892-a7c6f0a88666',
      '1525351484163-7529414344d8',
      '1484723091739-30a097e8f929',
      '1495214783159-3503fd1b572d',
      '1517673132405-a56a62b18caf',
    ],
    'eggs': [
      '1482049016688-2d3e1b311543',
      '1510693206972-df098062cb71',
      '1525184782196-8e2ded604bf7',
      '1607532941433-304659e8198a',
    ],
    'salad': [
      '1512621776951-a57141f2eefd',
      '1540189549336-e6e99c3679fe',
      '1546069901-ba9599a7e63c',
      '1505253716362-afaea1d3d1af',
      '1607532941433-304659e8198a',
    ],
    'smoothie': [
      '1502741224143-90386d7f8c82',
      '1553530666-ba11a7da3888',
      '1505252585461-04db1eb84625',
      '1622597467836-f3285f2131b8',
    ],
    'soup': [
      '1547592166-23ac45744acd',
      '1603105037880-880cd4b4ecca',
      '1588566565463-180a5b2090d2',
      '1534939561126-855b8675edd7',
    ],
    'grilled': [
      '1529692236671-f1f6cf9683ba',
      '1558030006-450675393462',
      '1544025162-d76694265947',
      '1555939594-58d7cb561ad1',
    ],
    'chicken': [
      '1598103442097-8b74df4e1c37',
      '1604908176997-125f25cc6f3d',
      '1532550907401-a500c9a57435',
      '1562967916-eb82221dfb84',
    ],
    'fish': [
      '1467003909585-2f8a72700288',
      '1519708227418-b869c4dc5bbd',
      '1580476262798-bddd9f4b7369',
      '1535399602991-b85cead204f5',
    ],
    'rice_bowl': [
      '1512058564366-18510be2db19',
      '1516684732162-798a0062be99',
      '1543339308-71f39a186169',
      '1505253149413-d3a15c5d1038',
    ],
    'pasta': [
      '1551892374-ecf8754cf8b0',
      '1563379926898-05f4575a45d8',
      '1556761223-4c4282c73f77',
      '1473093295043-cdd812d0e601',
    ],
    'sandwich': [
      '1553909489-cd47e0907980',
      '1568901346375-23c9450c58cd',
      '1550547660-d9450f859349',
      '1521390188846-e2a3f97dc722',
    ],
    'african': [
      '1604329760661-e71dc83f8f26',
      '1565299624946-b28f40a0ae38',
      '1567620905862-fe4951462168',
      '1546549032-9571cd6b27df',
    ],
    'curry': [
      '1565557623262-b51c2513a641',
      '1585937421612-70a008356fbe',
      '1574484284002-952d92456975',
      '1455619452474-d2be8b1e70cd',
    ],
    'snack': [
      '1490474418585-ba9bad8fd0ea',
      '1563636619-e9143da7973b',
      '1506084868230-bb9d95c24759',
      '1488477181946-6428a0291777',
    ],
    'vegetables': [
      '1540420773420-3366772f4999',
      '1498837167922-ddd27525d352',
      '1467019972079-a273e1bc9173',
      '1606923829579-0cb855d1e0e7',
    ],
    'meal': [
      '1546069901-ba9599a7e63c',
      '1504674900247-0877df9cc836',
      '1476224203421-9ac39bcb3327',
      '1493770348161-369560ae357d',
      '1547592180-85f173990554',
      '1565299585323-38d6b0865b47',
    ],
  };
}
