/// Shared calorie-goal logic used by onboarding AND the Settings profile sheet,
/// so the two can never drift apart.

class ActivityOption {
  final String label;
  final String sub;
  final double mult;
  const ActivityOption(this.label, this.sub, this.mult);
}

const List<ActivityOption> kActivityOptions = [
  ActivityOption('Sedentary', 'Little or no exercise', 1.2),
  ActivityOption('Lightly active', 'Light exercise 1–3 days/week', 1.375),
  ActivityOption('Moderately active', 'Moderate exercise 3–5 days/week', 1.55),
  ActivityOption('Very active', 'Hard exercise 6–7 days/week', 1.725),
  ActivityOption('Extra active', 'Physical job or training twice a day', 1.9),
];

/// Returns the index of the activity option closest to [mult] (default
/// moderately active when no/unknown value).
int nearestActivityIndex(double mult) {
  int best = 2;
  double bestDiff = double.infinity;
  for (int i = 0; i < kActivityOptions.length; i++) {
    final d = (kActivityOptions[i].mult - mult).abs();
    if (d < bestDiff) {
      bestDiff = d;
      best = i;
    }
  }
  return best;
}

/// Personalised daily calorie target (Mifflin-St Jeor BMR × activity, adjusted
/// for goal direction, with a safety floor). Rounded to the nearest 10.
///
/// [sex] is 'm' or 'f'; [goal] is 'lose' | 'maintain' | 'gain'.
int computeCalorieGoal({
  required String sex,
  required int age,
  required double weight, // kg
  required int height,    // cm
  required double activity,
  required String goal,
}) {
  final bmr = sex == 'm'
      ? 10 * weight + 6.25 * height - 5 * age + 5
      : 10 * weight + 6.25 * height - 5 * age - 161;
  final tdee = bmr * activity;
  double value;
  switch (goal) {
    case 'lose':
      value = tdee * 0.80; // ~20% deficit
      break;
    case 'gain':
      value = tdee * 1.12; // ~12% surplus
      break;
    default:
      value = tdee;
  }
  final floor = sex == 'm' ? 1500.0 : 1200.0;
  if (value < floor) value = floor;
  return (value / 10).round() * 10;
}
