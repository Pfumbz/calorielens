import '../models/meal_plan.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Curated South African meal plans.
///
/// 10 plans across categories and budget tiers, featuring SA staple foods.
/// Prices are estimated based on typical 2025/2026 SA grocery prices.
/// ─────────────────────────────────────────────────────────────────────────────

const List<MealPlan> kMealPlans = [
  // ═══════════════════════════════════════════════════════════════════
  // 1. BUDGET BRAAI BOWL
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp1',
    name: 'Budget Braai Bowl',
    description: 'Classic SA braai flavours in a budget-friendly bowl. Wors, pap, and chakalaka — all for under R50.',
    category: 'budget',
    budgetTier: 'r50',
    estimatedCostZAR: 45,
    totalCalories: 1850,
    totalProtein: 85,
    totalCarbs: 220,
    totalFat: 72,
    servings: 1,
    prepTimeMin: 35,
    emoji: '🔥',
    tags: ['south-african', 'braai', 'budget'],
    meals: [
      PlanMeal(
        id: 'mp1_b', name: 'Mielie Pap & Boiled Egg', mealType: 'breakfast',
        calories: 380, protein: 16, carbs: 55, fat: 12,
        emoji: '🥚',
        recipe: 'Cook stiff pap (1 cup maize meal). Serve with 2 boiled eggs and a pinch of salt & pepper.',
        ingredients: [
          Ingredient(name: 'maize meal', quantity: '500g', estimatedPriceZAR: 12, category: 'grain'),
          Ingredient(name: 'eggs', quantity: '6 pack', estimatedPriceZAR: 18, category: 'protein'),
        ],
      ),
      PlanMeal(
        id: 'mp1_l', name: 'Chakalaka & Bread', mealType: 'lunch',
        calories: 420, protein: 12, carbs: 65, fat: 14,
        emoji: '🫘',
        recipe: 'Warm tinned chakalaka. Serve with 2 slices of brown bread. Add chopped onion on top if available.',
        ingredients: [
          Ingredient(name: 'chakalaka (tin)', quantity: '410g', estimatedPriceZAR: 18, category: 'pantry'),
          Ingredient(name: 'brown bread', quantity: '1 loaf', estimatedPriceZAR: 16, category: 'grain'),
        ],
      ),
      PlanMeal(
        id: 'mp1_d', name: 'Boerewors & Pap', mealType: 'dinner',
        calories: 680, protein: 38, carbs: 60, fat: 34,
        emoji: '🌭',
        recipe: 'Braai or pan-fry 200g boerewors. Serve with krummelpap (crumbly pap) and a dollop of tomato sauce.',
        ingredients: [
          Ingredient(name: 'boerewors', quantity: '500g', estimatedPriceZAR: 55, category: 'protein'),
        ],
      ),
      PlanMeal(
        id: 'mp1_s', name: 'Rusks & Rooibos', mealType: 'snack',
        calories: 370, protein: 19, carbs: 40, fat: 12,
        emoji: '☕',
        recipe: 'Dunk 2 rusks in a strong cup of rooibos tea with milk.',
        ingredients: [
          Ingredient(name: 'rusks', quantity: '500g pack', estimatedPriceZAR: 35, category: 'pantry'),
          Ingredient(name: 'rooibos tea', quantity: '40 bags', estimatedPriceZAR: 22, category: 'pantry'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 2. HIGH-PROTEIN BILTONG & EGGS
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp2',
    name: 'Biltong & Eggs Bulk',
    description: 'High-protein SA favourites for muscle building. Biltong, eggs, and chicken — simple and effective.',
    category: 'high-protein',
    budgetTier: 'r100',
    estimatedCostZAR: 95,
    totalCalories: 2100,
    totalProtein: 165,
    totalCarbs: 130,
    totalFat: 95,
    servings: 1,
    prepTimeMin: 30,
    emoji: '💪',
    tags: ['high-protein', 'south-african', 'gym'],
    meals: [
      PlanMeal(
        id: 'mp2_b', name: 'Scrambled Eggs & Biltong', mealType: 'breakfast',
        calories: 520, protein: 42, carbs: 8, fat: 36,
        emoji: '🥩',
        recipe: 'Scramble 3 eggs in butter. Chop 50g biltong on top. Serve with 1 slice of toast.',
        ingredients: [
          Ingredient(name: 'eggs', quantity: '6 pack', estimatedPriceZAR: 18, category: 'protein'),
          Ingredient(name: 'biltong (sliced)', quantity: '100g', estimatedPriceZAR: 45, category: 'protein'),
          Ingredient(name: 'butter', quantity: '250g', estimatedPriceZAR: 28, category: 'dairy'),
          Ingredient(name: 'white bread', quantity: '1 loaf', estimatedPriceZAR: 16, category: 'grain'),
        ],
      ),
      PlanMeal(
        id: 'mp2_l', name: 'Chicken Breast & Rice', mealType: 'lunch',
        calories: 620, protein: 52, carbs: 60, fat: 16,
        emoji: '🍗',
        recipe: 'Season chicken breast with Aromat and paprika. Pan-fry until golden. Serve with 1 cup white rice.',
        ingredients: [
          Ingredient(name: 'chicken breasts', quantity: '500g', estimatedPriceZAR: 55, category: 'protein'),
          Ingredient(name: 'white rice', quantity: '1kg', estimatedPriceZAR: 18, category: 'grain'),
          Ingredient(name: 'Aromat', quantity: '75g', estimatedPriceZAR: 15, category: 'spice'),
        ],
      ),
      PlanMeal(
        id: 'mp2_d', name: 'Steak & Sweet Potato', mealType: 'dinner',
        calories: 650, protein: 50, carbs: 45, fat: 30,
        emoji: '🥩',
        recipe: 'Season rump steak with salt and pepper. Braai or pan-fry to preference. Serve with roasted sweet potato wedges.',
        ingredients: [
          Ingredient(name: 'rump steak', quantity: '300g', estimatedPriceZAR: 65, category: 'protein'),
          Ingredient(name: 'sweet potato', quantity: '2 medium', estimatedPriceZAR: 15, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp2_s', name: 'Droëwors & Nuts', mealType: 'snack',
        calories: 310, protein: 21, carbs: 17, fat: 13,
        emoji: '🥜',
        recipe: 'Snack on 50g droëwors and a handful of mixed nuts.',
        ingredients: [
          Ingredient(name: 'droëwors', quantity: '100g', estimatedPriceZAR: 40, category: 'protein'),
          Ingredient(name: 'mixed nuts', quantity: '200g', estimatedPriceZAR: 35, category: 'pantry'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 3. VEGGIE BUNNY CHOW
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp3',
    name: 'Veggie Bunny Chow Day',
    description: 'Durban-inspired vegetarian meals packed with flavour. Bean curry bunny chow is the star.',
    category: 'vegetarian',
    budgetTier: 'r50',
    estimatedCostZAR: 48,
    totalCalories: 1750,
    totalProtein: 62,
    totalCarbs: 265,
    totalFat: 48,
    servings: 1,
    prepTimeMin: 45,
    emoji: '🍞',
    tags: ['vegetarian', 'durban', 'south-african', 'budget'],
    meals: [
      PlanMeal(
        id: 'mp3_b', name: 'Banana & Peanut Butter Toast', mealType: 'breakfast',
        calories: 420, protein: 14, carbs: 52, fat: 18,
        emoji: '🍌',
        recipe: 'Toast 2 slices of brown bread. Spread with peanut butter and top with sliced banana.',
        ingredients: [
          Ingredient(name: 'brown bread', quantity: '1 loaf', estimatedPriceZAR: 16, category: 'grain'),
          Ingredient(name: 'peanut butter', quantity: '400g', estimatedPriceZAR: 28, category: 'pantry'),
          Ingredient(name: 'bananas', quantity: '1kg (6-7)', estimatedPriceZAR: 15, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp3_l', name: 'Bean Curry Bunny Chow', mealType: 'lunch',
        calories: 620, protein: 24, carbs: 88, fat: 18,
        emoji: '🫘',
        recipe: 'Cook tinned sugar beans with onion, tomato, curry powder, and turmeric. Hollow out a quarter loaf of white bread and fill with the curry.',
        ingredients: [
          Ingredient(name: 'sugar beans (tin)', quantity: '410g', estimatedPriceZAR: 14, category: 'pantry'),
          Ingredient(name: 'onions', quantity: '1kg bag', estimatedPriceZAR: 12, category: 'produce'),
          Ingredient(name: 'tomatoes', quantity: '4 medium', estimatedPriceZAR: 10, category: 'produce'),
          Ingredient(name: 'curry powder', quantity: '100g', estimatedPriceZAR: 15, category: 'spice'),
          Ingredient(name: 'white bread (unsliced)', quantity: '1 loaf', estimatedPriceZAR: 18, category: 'grain'),
        ],
      ),
      PlanMeal(
        id: 'mp3_d', name: 'Gem Squash & Cheese', mealType: 'dinner',
        calories: 480, protein: 18, carbs: 55, fat: 22,
        emoji: '🎃',
        recipe: 'Halve 2 gem squash, boil until tender. Fill centres with grated cheese and a knob of butter. Grill until golden.',
        ingredients: [
          Ingredient(name: 'gem squash', quantity: '4 pieces', estimatedPriceZAR: 20, category: 'produce'),
          Ingredient(name: 'cheddar cheese', quantity: '200g', estimatedPriceZAR: 30, category: 'dairy'),
        ],
      ),
      PlanMeal(
        id: 'mp3_s', name: 'Mango Atchar & Poppadums', mealType: 'snack',
        calories: 230, protein: 6, carbs: 70, fat: 10,
        emoji: '🥭',
        recipe: 'Serve mango atchar with a few poppadums for dipping.',
        ingredients: [
          Ingredient(name: 'mango atchar', quantity: '380g', estimatedPriceZAR: 25, category: 'pantry'),
          Ingredient(name: 'poppadums', quantity: '100g pack', estimatedPriceZAR: 18, category: 'pantry'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 4. MEAL PREP SUNDAY
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp5',
    name: 'Sunday Meal Prep',
    description: 'Cook once on Sunday, eat all week. Chicken, rice, and veggies portioned into 5 containers.',
    category: 'bulk-cook',
    budgetTier: 'r100',
    estimatedCostZAR: 85,
    totalCalories: 2000,
    totalProtein: 130,
    totalCarbs: 210,
    totalFat: 68,
    servings: 5,
    prepTimeMin: 90,
    emoji: '📦',
    tags: ['meal-prep', 'bulk-cook', 'budget', 'gym'],
    meals: [
      PlanMeal(
        id: 'mp5_b', name: 'Overnight Oats (x5)', mealType: 'breakfast',
        calories: 380, protein: 14, carbs: 55, fat: 12,
        emoji: '🫙',
        recipe: 'Mix oats, milk, chia seeds, and honey in 5 jars. Refrigerate overnight. Top with banana in the morning.',
        ingredients: [
          Ingredient(name: 'rolled oats', quantity: '1kg', estimatedPriceZAR: 25, category: 'grain'),
          Ingredient(name: 'long-life milk', quantity: '1L', estimatedPriceZAR: 18, category: 'dairy'),
          Ingredient(name: 'chia seeds', quantity: '200g', estimatedPriceZAR: 30, category: 'pantry'),
          Ingredient(name: 'bananas', quantity: '1kg', estimatedPriceZAR: 15, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp5_l', name: 'Chicken, Rice & Broccoli (x5)', mealType: 'lunch',
        calories: 580, protein: 45, carbs: 60, fat: 18,
        emoji: '🥦',
        recipe: 'Bake 1kg chicken thighs with Aromat and garlic. Cook 2.5 cups rice. Steam broccoli. Portion into 5 containers.',
        ingredients: [
          Ingredient(name: 'chicken thighs', quantity: '1kg', estimatedPriceZAR: 55, category: 'protein'),
          Ingredient(name: 'white rice', quantity: '2.5kg', estimatedPriceZAR: 35, category: 'grain'),
          Ingredient(name: 'broccoli', quantity: '2 heads', estimatedPriceZAR: 25, category: 'produce'),
          Ingredient(name: 'garlic', quantity: '3 bulbs', estimatedPriceZAR: 10, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp5_d', name: 'Beef Mince & Samp (x5)', mealType: 'dinner',
        calories: 650, protein: 42, carbs: 70, fat: 24,
        emoji: '🍲',
        recipe: 'Brown mince with onion and tomato. Season with Rajah curry. Serve over cooked samp & beans.',
        ingredients: [
          Ingredient(name: 'beef mince', quantity: '1kg', estimatedPriceZAR: 70, category: 'protein'),
          Ingredient(name: 'samp & beans', quantity: '1kg', estimatedPriceZAR: 22, category: 'grain'),
          Ingredient(name: 'tinned tomatoes', quantity: '400g x2', estimatedPriceZAR: 20, category: 'pantry'),
          Ingredient(name: 'Rajah curry powder', quantity: '100g', estimatedPriceZAR: 18, category: 'spice'),
        ],
      ),
      PlanMeal(
        id: 'mp5_s', name: 'Hard-Boiled Eggs (x5)', mealType: 'snack',
        calories: 390, protein: 29, carbs: 25, fat: 14,
        emoji: '🥚',
        recipe: 'Boil 10 eggs, peel and store in fridge. 2 per day with salt.',
        ingredients: [
          Ingredient(name: 'eggs', quantity: '18 pack', estimatedPriceZAR: 45, category: 'protein'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 6. BOBOTIE FEAST
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp6',
    name: 'Cape Malay Feast',
    description: 'Traditional Cape Malay bobotie with yellow rice. A South African classic that feeds the whole family.',
    category: 'balanced',
    budgetTier: 'r100',
    estimatedCostZAR: 90,
    totalCalories: 1950,
    totalProtein: 95,
    totalCarbs: 230,
    totalFat: 72,
    servings: 4,
    prepTimeMin: 60,
    emoji: '🏔️',
    tags: ['south-african', 'cape-malay', 'family', 'traditional'],
    meals: [
      PlanMeal(
        id: 'mp6_b', name: 'Mosbolletjies & Jam', mealType: 'breakfast',
        calories: 350, protein: 8, carbs: 62, fat: 8,
        emoji: '🍞',
        recipe: 'Toast mosbolletjies (or plain rolls) and spread with apricot jam and butter.',
        ingredients: [
          Ingredient(name: 'bread rolls', quantity: '6 pack', estimatedPriceZAR: 20, category: 'grain'),
          Ingredient(name: 'apricot jam', quantity: '450g', estimatedPriceZAR: 22, category: 'pantry'),
        ],
      ),
      PlanMeal(
        id: 'mp6_l', name: 'Bobotie & Yellow Rice', mealType: 'lunch',
        calories: 720, protein: 42, carbs: 68, fat: 32,
        emoji: '🍛',
        recipe: 'Brown mince with onion. Add soaked bread, curry powder, turmeric, chutney, and raisins. Pour egg-milk custard on top and bake at 180°C for 30 min. Serve with yellow rice (turmeric + raisins).',
        ingredients: [
          Ingredient(name: 'beef mince', quantity: '500g', estimatedPriceZAR: 50, category: 'protein'),
          Ingredient(name: "Mrs Ball's chutney", quantity: '470g', estimatedPriceZAR: 28, category: 'pantry'),
          Ingredient(name: 'turmeric', quantity: '50g', estimatedPriceZAR: 12, category: 'spice'),
          Ingredient(name: 'raisins', quantity: '250g', estimatedPriceZAR: 20, category: 'pantry'),
          Ingredient(name: 'basmati rice', quantity: '1kg', estimatedPriceZAR: 28, category: 'grain'),
        ],
      ),
      PlanMeal(
        id: 'mp6_d', name: 'Waterblommetjie Bredie', mealType: 'dinner',
        calories: 580, protein: 35, carbs: 55, fat: 24,
        emoji: '🌿',
        recipe: 'Slow-cook lamb or beef with potatoes, onion, and sorrel (or spinach as substitute). Season with nutmeg and white pepper.',
        ingredients: [
          Ingredient(name: 'stewing lamb/beef', quantity: '500g', estimatedPriceZAR: 60, category: 'protein'),
          Ingredient(name: 'potatoes', quantity: '1kg bag', estimatedPriceZAR: 18, category: 'produce'),
          Ingredient(name: 'spinach', quantity: '250g', estimatedPriceZAR: 15, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp6_s', name: 'Koeksisters & Tea', mealType: 'snack',
        calories: 300, protein: 10, carbs: 45, fat: 8,
        emoji: '🍩',
        recipe: 'Enjoy 2 koeksisters with rooibos tea.',
        ingredients: [
          Ingredient(name: 'koeksisters (pack)', quantity: '6 pack', estimatedPriceZAR: 30, category: 'pantry'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 7. STUDENT SURVIVAL
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp7',
    name: 'Student Survival',
    description: 'Maximum nutrition on minimum budget. Under R40 for a full day of meals. Perfect for res life.',
    category: 'budget',
    budgetTier: 'r50',
    estimatedCostZAR: 38,
    totalCalories: 1900,
    totalProtein: 72,
    totalCarbs: 280,
    totalFat: 55,
    servings: 1,
    prepTimeMin: 25,
    emoji: '🎓',
    tags: ['student', 'ultra-budget', 'quick', 'south-african'],
    meals: [
      PlanMeal(
        id: 'mp7_b', name: 'Peanut Butter Porridge', mealType: 'breakfast',
        calories: 450, protein: 16, carbs: 60, fat: 18,
        emoji: '🥜',
        recipe: 'Cook instant oats with water or milk. Stir in a heaped tablespoon of peanut butter and a drizzle of honey.',
        ingredients: [
          Ingredient(name: 'instant oats', quantity: '1kg', estimatedPriceZAR: 22, category: 'grain'),
          Ingredient(name: 'peanut butter', quantity: '400g', estimatedPriceZAR: 28, category: 'pantry'),
        ],
      ),
      PlanMeal(
        id: 'mp7_l', name: 'Tin Fish & Rice', mealType: 'lunch',
        calories: 520, protein: 28, carbs: 75, fat: 12,
        emoji: '🐟',
        recipe: 'Fry onion and tomato, add tinned pilchards, and simmer 10 min. Serve over white rice.',
        ingredients: [
          Ingredient(name: 'pilchards in tomato', quantity: '400g tin', estimatedPriceZAR: 18, category: 'protein'),
          Ingredient(name: 'white rice', quantity: '1kg', estimatedPriceZAR: 18, category: 'grain'),
          Ingredient(name: 'onions', quantity: '1kg', estimatedPriceZAR: 12, category: 'produce'),
          Ingredient(name: 'tomatoes', quantity: '3 medium', estimatedPriceZAR: 8, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp7_d', name: 'Vetkoek & Mince', mealType: 'dinner',
        calories: 680, protein: 22, carbs: 85, fat: 28,
        emoji: '🫓',
        recipe: 'Make dough from flour, yeast, salt, and water. Deep-fry until golden. Fill with curried mince.',
        ingredients: [
          Ingredient(name: 'cake flour', quantity: '2.5kg', estimatedPriceZAR: 28, category: 'grain'),
          Ingredient(name: 'instant yeast', quantity: '10g sachet', estimatedPriceZAR: 5, category: 'pantry'),
          Ingredient(name: 'beef mince', quantity: '500g', estimatedPriceZAR: 50, category: 'protein'),
          Ingredient(name: 'cooking oil', quantity: '750ml', estimatedPriceZAR: 25, category: 'pantry'),
        ],
      ),
      PlanMeal(
        id: 'mp7_s', name: 'Marie Biscuits & Tea', mealType: 'snack',
        calories: 250, protein: 6, carbs: 60, fat: 7,
        emoji: '🍪',
        recipe: 'Stack 5 Marie biscuits. Dunk in sweet rooibos tea.',
        ingredients: [
          Ingredient(name: 'Marie biscuits', quantity: '200g pack', estimatedPriceZAR: 12, category: 'pantry'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 8. SHISA NYAMA SATURDAY
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp8',
    name: 'Shisa Nyama Saturday',
    description: 'A proper South African braai day — from breakfast to the last piece of meat off the grill.',
    category: 'high-protein',
    budgetTier: 'r150',
    estimatedCostZAR: 140,
    totalCalories: 2400,
    totalProtein: 145,
    totalCarbs: 190,
    totalFat: 115,
    servings: 1,
    prepTimeMin: 120,
    emoji: '🥩',
    tags: ['braai', 'high-protein', 'weekend', 'south-african'],
    meals: [
      PlanMeal(
        id: 'mp8_b', name: 'Boerewors Roll', mealType: 'breakfast',
        calories: 520, protein: 22, carbs: 45, fat: 28,
        emoji: '🌭',
        recipe: 'Braai a boerewors coil. Place in a hot dog roll with fried onions, mustard, and tomato sauce.',
        ingredients: [
          Ingredient(name: 'boerewors', quantity: '500g', estimatedPriceZAR: 55, category: 'protein'),
          Ingredient(name: 'hot dog rolls', quantity: '6 pack', estimatedPriceZAR: 18, category: 'grain'),
          Ingredient(name: 'onions', quantity: '1kg', estimatedPriceZAR: 12, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp8_l', name: 'Braai Chicken & Mielies', mealType: 'lunch',
        calories: 680, protein: 48, carbs: 55, fat: 32,
        emoji: '🌽',
        recipe: 'Marinate chicken pieces in peri-peri sauce. Braai until charred. Serve with braai mielies brushed with butter.',
        ingredients: [
          Ingredient(name: 'chicken pieces', quantity: '1kg', estimatedPriceZAR: 60, category: 'protein'),
          Ingredient(name: 'peri-peri sauce', quantity: '250ml', estimatedPriceZAR: 25, category: 'pantry'),
          Ingredient(name: 'mielies (corn)', quantity: '4 cobs', estimatedPriceZAR: 20, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp8_d', name: 'T-Bone & Braaibroodjies', mealType: 'dinner',
        calories: 850, protein: 55, carbs: 50, fat: 48,
        emoji: '🥩',
        recipe: 'Season T-bone with coarse salt. Braai to medium-rare. Make braaibroodjies (braai sandwiches) with cheese, tomato, and onion.',
        ingredients: [
          Ingredient(name: 'T-bone steak', quantity: '400g', estimatedPriceZAR: 90, category: 'protein'),
          Ingredient(name: 'white bread', quantity: '1 loaf', estimatedPriceZAR: 16, category: 'grain'),
          Ingredient(name: 'cheddar cheese', quantity: '200g', estimatedPriceZAR: 30, category: 'dairy'),
          Ingredient(name: 'tomatoes', quantity: '3 medium', estimatedPriceZAR: 8, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp8_s', name: 'Melktert', mealType: 'snack',
        calories: 350, protein: 20, carbs: 40, fat: 7,
        emoji: '🥧',
        recipe: 'Enjoy a slice of melktert with cinnamon. Best bought from a local bakery.',
        ingredients: [
          Ingredient(name: 'melktert', quantity: '1 whole', estimatedPriceZAR: 45, category: 'pantry'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 9. QUICK WEEKNIGHT
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp9',
    name: 'Quick Weeknight',
    description: 'All meals ready in under 15 minutes. For busy days when you still want to eat well.',
    category: 'balanced',
    budgetTier: 'r100',
    estimatedCostZAR: 80,
    totalCalories: 1800,
    totalProtein: 90,
    totalCarbs: 200,
    totalFat: 68,
    servings: 1,
    prepTimeMin: 15,
    emoji: '⚡',
    tags: ['quick', '15-minute', 'weeknight', 'easy'],
    meals: [
      PlanMeal(
        id: 'mp9_b', name: 'Avo Toast & Egg', mealType: 'breakfast',
        calories: 420, protein: 18, carbs: 35, fat: 24,
        emoji: '🥑',
        recipe: 'Toast sourdough. Mash half an avo with salt, chilli flakes, and lemon. Top with a fried egg.',
        ingredients: [
          Ingredient(name: 'sourdough bread', quantity: '1 loaf', estimatedPriceZAR: 30, category: 'grain'),
          Ingredient(name: 'avocados', quantity: '3 pack', estimatedPriceZAR: 25, category: 'produce'),
          Ingredient(name: 'eggs', quantity: '6 pack', estimatedPriceZAR: 18, category: 'protein'),
        ],
      ),
      PlanMeal(
        id: 'mp9_l', name: 'Tuna Mayo Wrap', mealType: 'lunch',
        calories: 480, protein: 32, carbs: 45, fat: 18,
        emoji: '🌯',
        recipe: 'Mix tinned tuna with mayo, sweetcorn, and chopped pepper. Roll in a tortilla wrap with lettuce.',
        ingredients: [
          Ingredient(name: 'tinned tuna', quantity: '170g x2', estimatedPriceZAR: 30, category: 'protein'),
          Ingredient(name: 'tortilla wraps', quantity: '6 pack', estimatedPriceZAR: 25, category: 'grain'),
          Ingredient(name: 'mayo', quantity: '375ml', estimatedPriceZAR: 22, category: 'pantry'),
          Ingredient(name: 'sweetcorn (tin)', quantity: '410g', estimatedPriceZAR: 14, category: 'pantry'),
        ],
      ),
      PlanMeal(
        id: 'mp9_d', name: 'Chicken Stir-Fry Noodles', mealType: 'dinner',
        calories: 580, protein: 32, carbs: 72, fat: 18,
        emoji: '🍜',
        recipe: 'Slice chicken breast thin. Stir-fry with frozen veg and 2-minute noodles. Add soy sauce and a squeeze of lemon.',
        ingredients: [
          Ingredient(name: 'chicken breast', quantity: '500g', estimatedPriceZAR: 55, category: 'protein'),
          Ingredient(name: '2-minute noodles', quantity: '5 pack', estimatedPriceZAR: 18, category: 'grain'),
          Ingredient(name: 'frozen stir-fry veg', quantity: '500g', estimatedPriceZAR: 25, category: 'produce'),
        ],
      ),
      PlanMeal(
        id: 'mp9_s', name: 'Biltong & Apple', mealType: 'snack',
        calories: 320, protein: 8, carbs: 48, fat: 8,
        emoji: '🍎',
        recipe: 'Snack on 30g biltong with a fresh apple.',
        ingredients: [
          Ingredient(name: 'biltong (sliced)', quantity: '100g', estimatedPriceZAR: 45, category: 'protein'),
          Ingredient(name: 'apples', quantity: '1kg bag', estimatedPriceZAR: 25, category: 'produce'),
        ],
      ),
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════
  // 10. PLANT POWER
  // ═══════════════════════════════════════════════════════════════════
  MealPlan(
    id: 'mp10',
    name: 'Plant Power Day',
    description: 'Fully plant-based day using affordable SA ingredients. High fibre, plenty of protein from legumes.',
    category: 'vegetarian',
    budgetTier: 'r50',
    estimatedCostZAR: 42,
    totalCalories: 1800,
    totalProtein: 68,
    totalCarbs: 260,
    totalFat: 52,
    servings: 1,
    prepTimeMin: 40,
    emoji: '🌱',
    tags: ['vegan', 'plant-based', 'budget', 'south-african'],
    meals: [
      PlanMeal(
        id: 'mp10_b', name: 'Mealie Meal Porridge & Fruit', mealType: 'breakfast',
        calories: 380, protein: 10, carbs: 72, fat: 6,
        emoji: '🌾',
        recipe: 'Cook soft pap (mealie meal porridge) with water. Top with sliced banana and a drizzle of golden syrup.',
        ingredients: [
          Ingredient(name: 'maize meal', quantity: '1kg', estimatedPriceZAR: 15, category: 'grain'),
          Ingredient(name: 'bananas', quantity: '1kg', estimatedPriceZAR: 15, category: 'produce'),
          Ingredient(name: 'golden syrup', quantity: '500ml', estimatedPriceZAR: 22, category: 'pantry'),
        ],
      ),
      PlanMeal(
        id: 'mp10_l', name: 'Lentil Curry & Rice', mealType: 'lunch',
        calories: 550, protein: 24, carbs: 82, fat: 14,
        emoji: '🍛',
        recipe: 'Cook red lentils with onion, tomato, garlic, and curry powder until thick. Serve over basmati rice.',
        ingredients: [
          Ingredient(name: 'red lentils', quantity: '500g', estimatedPriceZAR: 22, category: 'pantry'),
          Ingredient(name: 'basmati rice', quantity: '1kg', estimatedPriceZAR: 28, category: 'grain'),
          Ingredient(name: 'onions', quantity: '1kg', estimatedPriceZAR: 12, category: 'produce'),
          Ingredient(name: 'curry powder', quantity: '100g', estimatedPriceZAR: 15, category: 'spice'),
        ],
      ),
      PlanMeal(
        id: 'mp10_d', name: 'Butternut Soup & Bread', mealType: 'dinner',
        calories: 480, protein: 14, carbs: 68, fat: 18,
        emoji: '🎃',
        recipe: 'Roast butternut with onion and garlic. Blend into a creamy soup with vegetable stock. Serve with buttered bread.',
        ingredients: [
          Ingredient(name: 'butternut', quantity: '1 large', estimatedPriceZAR: 20, category: 'produce'),
          Ingredient(name: 'vegetable stock cubes', quantity: '10 pack', estimatedPriceZAR: 10, category: 'pantry'),
          Ingredient(name: 'brown bread', quantity: '1 loaf', estimatedPriceZAR: 16, category: 'grain'),
        ],
      ),
      PlanMeal(
        id: 'mp10_s', name: 'Roasted Chickpeas', mealType: 'snack',
        calories: 390, protein: 20, carbs: 38, fat: 14,
        emoji: '🫘',
        recipe: 'Drain tinned chickpeas. Toss with olive oil, paprika, and salt. Roast at 200°C for 25 min until crunchy.',
        ingredients: [
          Ingredient(name: 'chickpeas (tin)', quantity: '400g x2', estimatedPriceZAR: 24, category: 'pantry'),
          Ingredient(name: 'olive oil', quantity: '250ml', estimatedPriceZAR: 35, category: 'pantry'),
          Ingredient(name: 'paprika', quantity: '50g', estimatedPriceZAR: 10, category: 'spice'),
        ],
      ),
    ],
  ),
];

/// Filter plans by category.
List<MealPlan> plansByCategory(String cat) =>
    kMealPlans.where((p) => p.category == cat).toList();

/// Filter plans by budget tier.
List<MealPlan> plansByBudget(String tier) =>
    kMealPlans.where((p) => p.budgetTier == tier).toList();

/// Filter plans by category AND budget tier (if provided).
List<MealPlan> filterPlans({String? category, String? budgetTier}) {
  return kMealPlans.where((p) {
    if (category != null && category != 'all' && p.category != category) return false;
    if (budgetTier != null && budgetTier != 'all' && p.budgetTier != budgetTier) return false;
    return true;
  }).toList();
}
