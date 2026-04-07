const String _cdnBase =
    'https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@main/exercises/';

class Exercise {
  final String id;
  final String cat; // muscle | burn | hiit | stretch | home
  final String name;
  final String muscles;
  final int sets;
  final String reps;
  final String rest;
  final String gifBase; // base path, append /0.jpg and /1.jpg
  final List<String> benefits;
  final List<String> steps;

  const Exercise({
    required this.id,
    required this.cat,
    required this.name,
    required this.muscles,
    required this.sets,
    required this.reps,
    required this.rest,
    required this.gifBase,
    required this.benefits,
    required this.steps,
  });

  String get img0 => '$_cdnBase$gifBase/0.jpg';
  String get img1 => '$_cdnBase$gifBase/1.jpg';
}

const List<Exercise> kExercises = [
  // ── BUILD MUSCLE ──────────────────────────────────────────────────
  Exercise(
    id: 'm1', cat: 'muscle', name: 'Barbell Bench Press', muscles: 'Chest · Triceps · Front Delts',
    sets: 4, reps: '6–10', rest: '90s',
    gifBase: 'Barbell_Bench_Press_-_Medium_Grip',
    benefits: ['Primary chest builder for mass and strength', 'Activates entire anterior chain', 'Supports shoulder joint stability'],
    steps: ['Lie on bench, grip bar slightly wider than shoulder-width', 'Lower bar to lower chest — elbows at 75° to body', 'Press through chest explosively to full extension', 'Control the negative — 2 seconds down'],
  ),
  Exercise(
    id: 'm2', cat: 'muscle', name: 'Pull-Ups', muscles: 'Lats · Biceps · Rear Delts',
    sets: 4, reps: '6–10', rest: '90s',
    gifBase: 'Pullups',
    benefits: ['Best compound movement for lat development', 'Builds thick back and strong biceps', 'Improves grip strength and posture'],
    steps: ['Hang from bar with overhand grip, hands shoulder-width', 'Initiate by depressing shoulder blades', 'Pull elbows to hips — chin above bar', 'Lower fully with control — no kipping'],
  ),
  Exercise(
    id: 'm3', cat: 'muscle', name: 'Barbell Squat', muscles: 'Quads · Glutes · Hamstrings · Core',
    sets: 4, reps: '6–10', rest: '2 min',
    gifBase: 'Barbell_Full_Squat',
    benefits: ['King of all compound exercises', 'Builds full lower body mass and strength', 'Releases growth hormone systemically'],
    steps: ['Bar on upper traps, feet shoulder-width, toes out 15°', 'Brace core and break at hips and knees simultaneously', 'Descend until thighs parallel or below', 'Drive through entire foot to stand — squeeze glutes at top'],
  ),
  Exercise(
    id: 'm4', cat: 'muscle', name: 'Overhead Press', muscles: 'Shoulders · Triceps · Upper Traps',
    sets: 4, reps: '6–10', rest: '90s',
    gifBase: 'Standing_Military_Press',
    benefits: ['Best overhead strength builder', 'Creates shoulder width and definition', 'Trains core stability under load'],
    steps: ['Stand with bar at collarbone, grip just outside shoulders', 'Brace core and press bar directly overhead', 'Lock out fully — biceps by ears at top', 'Lower under control to start position'],
  ),
  Exercise(
    id: 'm5', cat: 'muscle', name: 'Bent-Over Row', muscles: 'Lats · Rhomboids · Biceps · Rear Delts',
    sets: 4, reps: '8–12', rest: '90s',
    gifBase: 'Reverse_Grip_Bent-Over_Rows',
    benefits: ['Builds thick mid-back and lats', 'Counteracts bench press imbalances', 'Improves posture and shoulder health'],
    steps: ['Hinge to 45°, bar hanging at shins, overhand grip', 'Row bar to lower chest — lead with elbows', 'Squeeze shoulder blades at top for 1 second', 'Lower slowly to full arm extension'],
  ),
  Exercise(
    id: 'm6', cat: 'muscle', name: 'Romanian Deadlift', muscles: 'Hamstrings · Glutes · Lower Back',
    sets: 3, reps: '10–12', rest: '90s',
    gifBase: 'Romanian_Deadlift',
    benefits: ['Targets hamstrings through full range of motion', 'Builds posterior chain strength', 'Improves hip hinge mechanics'],
    steps: ['Stand holding bar at hips, slight knee bend', 'Hinge hips back — bar stays close to legs', 'Lower until you feel hamstring stretch (mid-shin)', 'Drive hips forward to return — squeeze glutes at top'],
  ),
  Exercise(
    id: 'm7', cat: 'muscle', name: 'Lateral Raise', muscles: 'Side Delts · Upper Traps',
    sets: 3, reps: '12–15', rest: '60s',
    gifBase: 'Lateral_Raise_-_With_Bands',
    benefits: ['Isolates the medial deltoid for shoulder width', 'Light exercise great for shoulder health', 'Adds finishing detail to shoulder development'],
    steps: ['Stand holding bands at sides, slight elbow bend', 'Raise arms out to sides until parallel to floor', 'Lead with elbows, not wrists', 'Lower slowly — avoid shrugging or swinging'],
  ),
  Exercise(
    id: 'm8', cat: 'muscle', name: 'Bicep Curl', muscles: 'Biceps · Forearms',
    sets: 3, reps: '12–15', rest: '60s',
    gifBase: 'Dumbbell_Bicep_Curl',
    benefits: ['Isolates and builds bicep peak', 'Strengthens elbow flexors', 'Improves arm aesthetics and grip strength'],
    steps: ['Stand holding dumbbells, palms facing forward', 'Curl weights toward shoulders, keeping elbows fixed', 'Squeeze at the top for 1 second', 'Lower slowly to full extension'],
  ),

  // ── BURN CALORIES ─────────────────────────────────────────────────
  Exercise(
    id: 'b1', cat: 'burn', name: 'Treadmill Run', muscles: 'Full Body · Cardiovascular',
    sets: 1, reps: '20–30 min', rest: '—',
    gifBase: 'Jogging_Treadmill',
    benefits: ['Burns 250–400 calories per session', 'Improves cardiovascular fitness', 'Strengthens legs and boosts mood'],
    steps: ['Warm up at brisk walk for 3–5 minutes', 'Increase to jogging pace', 'Run at moderate effort for 20–30 min', 'Cool down with 3 min walk and stretch'],
  ),
  Exercise(
    id: 'b2', cat: 'burn', name: 'Rowing Machine', muscles: 'Back · Arms · Legs · Core',
    sets: 1, reps: '20 min', rest: '—',
    gifBase: 'Seated_Cable_Rows',
    benefits: ['Burns ~300 calories in 20 min', 'Works 86% of muscles', 'Low impact — safe for knees and joints'],
    steps: ['Sit with feet strapped in, hold handle overhand', 'Drive with legs first, then lean back, then pull arms', 'Return: arms extend, lean forward, bend knees', 'Maintain smooth rhythm'],
  ),
  Exercise(
    id: 'b3', cat: 'burn', name: 'Jump Rope', muscles: 'Calves · Shoulders · Coordination',
    sets: 5, reps: '1 min on / 30s off', rest: '30s',
    gifBase: 'Rope_Jumping',
    benefits: ['Burns 200 calories in 20 minutes', 'Improves coordination and footwork', 'Portable — train anywhere'],
    steps: ['Hold handles at hip height, rope behind feet', 'Swing rope overhead with wrists — not arms', 'Jump 2–3 cm off floor as rope passes', 'Land softly on balls of feet'],
  ),
  Exercise(
    id: 'b4', cat: 'burn', name: 'Stationary Bike', muscles: 'Quads · Calves · Cardiovascular',
    sets: 1, reps: '30 min', rest: '—',
    gifBase: 'Bicycling_Stationary',
    benefits: ['Low impact — easy on joints', 'Burns 200–350 calories per session', 'Builds leg endurance'],
    steps: ['Adjust seat so leg is 90% extended at bottom', 'Warm up 5 min at easy resistance', 'Cycle at moderate-high resistance for 25 min', 'Cool down 5 min at easy pace'],
  ),

  // ── HIIT ──────────────────────────────────────────────────────────
  Exercise(
    id: 'h1', cat: 'hiit', name: 'Inchworm', muscles: 'Core · Shoulders · Hamstrings',
    sets: 3, reps: '10', rest: '30s',
    gifBase: 'Inchworm',
    benefits: ['Full-body dynamic warm-up', 'Improves flexibility and stability', 'Activates core and upper body'],
    steps: ['Stand tall, hinge forward and touch floor', 'Walk hands out to push-up position', 'Hold 1 second, walk feet to hands', 'Return to standing — repeat'],
  ),
  Exercise(
    id: 'h2', cat: 'hiit', name: 'Star Jump', muscles: 'Full Body · Cardiovascular',
    sets: 4, reps: '20', rest: '20s',
    gifBase: 'Star_Jump',
    benefits: ['Burns maximum calories in minimal time', 'Improves coordination and agility', 'Elevates heart rate rapidly'],
    steps: ['Start in standing position, arms at sides', 'Jump up spreading legs wide and arms overhead', 'Form a star shape at peak of jump', 'Land softly and return to start'],
  ),
  Exercise(
    id: 'h3', cat: 'hiit', name: 'Mountain Climbers', muscles: 'Core · Shoulders · Hip Flexors',
    sets: 4, reps: '30s', rest: '15s',
    gifBase: 'Mountain_Climbers',
    benefits: ['Builds core strength and cardiovascular endurance', 'Burns 8–10 calories per minute', 'No equipment needed'],
    steps: ['Start in push-up position', 'Drive right knee toward chest', 'Switch legs explosively — alternate', 'Keep hips level — do not bounce'],
  ),
  Exercise(
    id: 'h4', cat: 'hiit', name: 'Plank', muscles: 'Core · Shoulders · Glutes',
    sets: 4, reps: '30–60s hold', rest: '30s',
    gifBase: 'Plank',
    benefits: ['Builds deep core stability', 'Improves posture and spinal alignment', 'Reduces lower back pain risk'],
    steps: ['Forearms on floor, elbows under shoulders', 'Body in straight line from head to heels', 'Brace abs — do not let hips sag or rise', 'Breathe steadily throughout hold'],
  ),

  // ── STRETCH & RECOVER ─────────────────────────────────────────────
  Exercise(
    id: 's1', cat: 'stretch', name: 'Hip Flexor Stretch', muscles: 'Hip Flexors · Quads',
    sets: 2, reps: '30s each side', rest: '10s',
    gifBase: 'Kneeling_Hip_Flexor',
    benefits: ['Relieves tight hips from sitting', 'Improves stride length and posture', 'Reduces lower back tension'],
    steps: ['Kneel on right knee, left foot forward', 'Shift hips forward until you feel a hip stretch', 'Keep torso upright and core braced', 'Hold 30s then switch sides'],
  ),
  Exercise(
    id: 's2', cat: 'stretch', name: 'Hamstring Stretch', muscles: 'Hamstrings · Lower Back',
    sets: 2, reps: '30s each side', rest: '10s',
    gifBase: '90_90_Hamstring',
    benefits: ['Reduces injury risk from tight hamstrings', 'Improves running and hinge mechanics', 'Relieves lower back tightness'],
    steps: ['Lie on back, one leg straight on floor', 'Raise other leg and hold behind the knee', 'Gently pull toward chest until you feel the stretch', 'Hold 30s — breathe deeply'],
  ),
  Exercise(
    id: 's3', cat: 'stretch', name: "Child's Pose", muscles: 'Lower Back · Hips · Shoulders',
    sets: 1, reps: '60–90s hold', rest: '—',
    gifBase: 'Childs_Pose',
    benefits: ['Deep spinal decompression and relaxation', 'Relieves tension in hips and lower back', 'Calms the nervous system'],
    steps: ['Kneel and sit back on heels', 'Walk hands forward until forehead touches floor', 'Arms extended or alongside body', 'Breathe deeply — relax into the position'],
  ),
  Exercise(
    id: 's4', cat: 'stretch', name: 'Cat-Cow Stretch', muscles: 'Spine · Core · Hip Flexors',
    sets: 2, reps: '10 slow reps', rest: '—',
    gifBase: 'Cat_Stretch',
    benefits: ['Improves spinal mobility and flexibility', 'Warms up the entire spine', 'Reduces back stiffness'],
    steps: ['On hands and knees, wrists under shoulders', 'Exhale: round back upward (cat)', 'Inhale: arch back and lift head (cow)', 'Move slowly — 3 seconds each direction'],
  ),

  // ── HOME WORKOUT ──────────────────────────────────────────────────
  Exercise(
    id: 'hw1', cat: 'home', name: 'Decline Push-Up', muscles: 'Chest · Triceps · Shoulders',
    sets: 4, reps: '12–20', rest: '60s',
    gifBase: 'Decline_Push-Up',
    benefits: ['Builds upper chest and arm strength', 'Scalable — feet elevated for more challenge', 'Strengthens core as a stabilising movement'],
    steps: ['Hands wider than shoulder-width, feet on chair/surface', 'Lower chest to floor, elbows at 45° to body', 'Push through palms explosively to start', 'Keep body in straight line throughout'],
  ),
  Exercise(
    id: 'hw2', cat: 'home', name: 'Bodyweight Squat', muscles: 'Quads · Glutes · Hamstrings',
    sets: 4, reps: '15–20', rest: '60s',
    gifBase: 'Chair_Squat',
    benefits: ['Builds leg strength and muscle without equipment', 'Improves mobility and functional movement', 'Great foundation before adding external load'],
    steps: ['Stand feet shoulder-width, toes slightly out', 'Push hips back and bend knees', 'Keep chest tall, knees tracking over toes', 'Drive through heels to stand, squeeze glutes at top'],
  ),
  Exercise(
    id: 'hw3', cat: 'home', name: 'Glute Bridge', muscles: 'Glutes · Hamstrings · Lower Back',
    sets: 3, reps: '15–20', rest: '45s',
    gifBase: 'Barbell_Glute_Bridge',
    benefits: ['Activates and builds glutes', 'Improves hip extension for running and jumping', 'Relieves anterior pelvic tilt'],
    steps: ['Lie on back, knees bent, feet flat on floor', 'Drive hips up until body forms a straight line', 'Squeeze glutes hard at the top for 2 seconds', 'Lower hips slowly — do not touch floor between reps'],
  ),
  Exercise(
    id: 'hw4', cat: 'home', name: 'Superman', muscles: 'Lower Back · Glutes · Rear Delts',
    sets: 3, reps: '12–15', rest: '45s',
    gifBase: 'Superman',
    benefits: ['Strengthens posterior chain without equipment', 'Improves spinal extension strength', 'Counteracts sitting and forward posture'],
    steps: ['Lie face down, arms extended overhead', 'Simultaneously lift arms, chest, and legs off floor', 'Squeeze glutes and upper back at top', 'Hold 2 seconds, lower slowly'],
  ),
];

List<Exercise> exercisesByCategory(String cat) =>
    kExercises.where((e) => e.cat == cat).toList();
