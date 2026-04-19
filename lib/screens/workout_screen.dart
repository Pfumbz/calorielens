import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../data/exercises.dart';
import '../theme.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  String _selectedCat = 'muscle';

  static const _cats = [
    ('muscle', '💪', 'Build Muscle'),
    ('burn',   '🔥', 'Burn Calories'),
    ('hiit',   '⚡', 'HIIT'),
    ('stretch','🧘', 'Stretch'),
    ('home',   '🏠', 'Home'),
  ];

  @override
  Widget build(BuildContext context) {
    final exercises = exercisesByCategory(_selectedCat);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Workout', style: TextStyle(color: CLColors.text, fontSize: 22, fontWeight: FontWeight.w600)),
                  ElevatedButton.icon(
                    onPressed: () => _startWorkout(context, exercises),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            // Category tabs
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final (id, emoji, label) = _cats[i];
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
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: exercises.length,
                itemBuilder: (_, i) => _ExerciseCard(
                  exercise: exercises[i],
                  onTap: () => _openExModal(context, exercises[i], exercises),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _startWorkout(BuildContext context, List<Exercise> exercises) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutPlayerScreen(exercises: exercises)),
    );
  }

  void _openExModal(BuildContext context, Exercise ex, List<Exercise> all) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CLColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ExerciseDetailSheet(
        exercise: ex,
        onStart: () {
          Navigator.pop(context);
          _startWorkout(context, [ex, ...all.where((e) => e.id != ex.id)]);
        },
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;
  const _ExerciseCard({required this.exercise, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
              child: SizedBox(
                width: 90, height: 90,
                child: CachedNetworkImage(
                  imageUrl: exercise.img0,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: CLColors.surface2, child: const Center(child: Icon(Icons.fitness_center, color: CLColors.muted, size: 28))),
                  errorWidget: (_, __, ___) => Container(color: CLColors.surface2, child: const Center(child: Icon(Icons.fitness_center, color: CLColors.muted, size: 28))),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exercise.name, style: const TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(exercise.muscles, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      _tag('${exercise.sets} sets'),
                      _tag(exercise.reps),
                      _tag('Rest ${exercise.rest}'),
                    ]),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Icon(Icons.chevron_right, color: CLColors.muted, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: CLColors.surface2,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: CLColors.border),
    ),
    child: Text(t, style: const TextStyle(color: CLColors.muted, fontSize: 10)),
  );
}

class _ExerciseDetailSheet extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onStart;
  const _ExerciseDetailSheet({required this.exercise, required this.onStart});

  @override
  State<_ExerciseDetailSheet> createState() => _ExerciseDetailSheetState();
}

class _ExerciseDetailSheetState extends State<_ExerciseDetailSheet> {
  bool _showImg1 = false;
  Timer? _cycleTimer;

  @override
  void initState() {
    super.initState();
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      setState(() => _showImg1 = !_showImg1);
    });
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image crossfade
            SizedBox(
              height: 240,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: _showImg1 ? 0 : 1,
                    duration: const Duration(milliseconds: 700),
                    child: CachedNetworkImage(imageUrl: ex.img0, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: CLColors.surface2)),
                  ),
                  AnimatedOpacity(
                    opacity: _showImg1 ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    child: CachedNetworkImage(imageUrl: ex.img1, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: CLColors.surface2)),
                  ),
                  Positioned(
                    top: 12, right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text(_showImg1 ? 'End position' : 'Start position',
                          style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ex.name, style: const TextStyle(color: CLColors.text, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(ex.muscles, style: const TextStyle(color: CLColors.muted, fontSize: 13)),
                  const SizedBox(height: 14),
                  Row(children: [
                    _infoChip('${ex.sets}', 'Sets'),
                    const SizedBox(width: 10),
                    _infoChip(ex.reps, 'Reps'),
                    const SizedBox(width: 10),
                    _infoChip(ex.rest, 'Rest'),
                  ]),
                  const SizedBox(height: 20),
                  _section('Benefits', ex.benefits.map((b) => '• $b').join('\n')),
                  const SizedBox(height: 16),
                  _section('How to do it', null),
                  const SizedBox(height: 8),
                  ...ex.steps.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: CLColors.accentLo, borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: CLColors.accent.withOpacity(0.4))),
                          child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: CLColors.accent, fontSize: 11, fontWeight: FontWeight.w700))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.value, style: const TextStyle(color: CLColors.text, fontSize: 13, height: 1.4))),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: widget.onStart,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('START THIS WORKOUT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: CLColors.surface2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(children: [
        Text(value, style: const TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
      ]),
    ),
  );

  Widget _section(String title, String? body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
      if (body != null) ...[
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(color: CLColors.muted, fontSize: 13, height: 1.5)),
      ],
    ],
  );
}

// ── Workout Player ────────────────────────────────────────────────────
class WorkoutPlayerScreen extends StatefulWidget {
  final List<Exercise> exercises;
  const WorkoutPlayerScreen({super.key, required this.exercises});

  @override
  State<WorkoutPlayerScreen> createState() => _WorkoutPlayerScreenState();
}

class _WorkoutPlayerScreenState extends State<WorkoutPlayerScreen> {
  int _currentIdx = 0;
  int _currentSet = 1;
  bool _showImg1 = false;
  bool _complete = false;
  Timer? _cycleTimer;
  Timer? _restTimer;
  int _restSeconds = 0;
  bool _inRest = false;
  DateTime? _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _startCycle();
  }

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  void _startCycle() {
    _cycleTimer?.cancel();
    _cycleTimer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      setState(() => _showImg1 = !_showImg1);
    });
  }

  void _nextSet() {
    final ex = widget.exercises[_currentIdx];
    if (_currentSet < ex.sets) {
      _startRest(ex.rest);
    } else {
      _nextExercise();
    }
  }

  void _startRest(String restStr) {
    final secs = restStr == '—' ? 30
        : restStr.contains('2 min') ? 120
        : restStr.contains('90') ? 90
        : restStr.contains('45') ? 45
        : 60;
    setState(() { _inRest = true; _restSeconds = secs; });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_restSeconds <= 1) {
        _restTimer?.cancel();
        setState(() { _inRest = false; _currentSet++; });
      } else {
        setState(() => _restSeconds--);
      }
    });
  }

  void _nextExercise() {
    if (_currentIdx >= widget.exercises.length - 1) {
      setState(() => _complete = true);
    } else {
      setState(() { _currentIdx++; _currentSet = 1; _showImg1 = false; });
      _startCycle();
    }
  }

  void _prevExercise() {
    if (_currentIdx > 0) {
      _restTimer?.cancel();
      setState(() { _currentIdx--; _currentSet = 1; _inRest = false; _showImg1 = false; });
      _startCycle();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_complete) return _buildComplete();
    final ex = widget.exercises[_currentIdx];
    final progress = (_currentIdx) / widget.exercises.length;

    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: CLColors.border,
              color: CLColors.accent,
              minHeight: 3,
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: CLColors.muted),
                  ),
                  Expanded(
                    child: Column(children: [
                      Text('Exercise ${_currentIdx + 1} of ${widget.exercises.length}',
                          style: const TextStyle(color: CLColors.muted, fontSize: 11)),
                      Text(ex.name, style: const TextStyle(color: CLColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  Text('Set $_currentSet/${ex.sets}',
                      style: const TextStyle(color: CLColors.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            // Image crossfade
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: _showImg1 ? 0 : 1,
                    duration: const Duration(milliseconds: 700),
                    child: CachedNetworkImage(imageUrl: ex.img0, fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => const Icon(Icons.fitness_center, color: CLColors.muted, size: 60)),
                  ),
                  AnimatedOpacity(
                    opacity: _showImg1 ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    child: CachedNetworkImage(imageUrl: ex.img1, fit: BoxFit.contain,
                      errorWidget: (_, __, ___) => Container()),
                  ),
                ],
              ),
            ),
            // Rest timer overlay
            if (_inRest)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: CLColors.accentLo,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: CLColors.accent.withOpacity(0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, color: CLColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text('Rest: $_restSeconds s', style: const TextStyle(color: CLColors.accent, fontSize: 15, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () { _restTimer?.cancel(); setState(() { _inRest = false; _currentSet++; }); },
                      child: const Text('Skip →', style: TextStyle(color: CLColors.muted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            // Set dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(ex.sets, (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _currentSet - 1
                        ? CLColors.green
                        : i == _currentSet - 1
                            ? CLColors.accent
                            : CLColors.border,
                  ),
                )),
              ),
            ),
            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _currentIdx > 0 ? _prevExercise : null,
                    icon: const Icon(Icons.arrow_back_ios),
                    color: CLColors.muted,
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _inRest ? null : _nextSet,
                      child: Text(_currentSet < ex.sets ? 'LOG SET $_currentSet' : 'NEXT EXERCISE →'),
                    ),
                  ),
                  IconButton(
                    onPressed: _nextExercise,
                    icon: const Icon(Icons.arrow_forward_ios),
                    color: CLColors.muted,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplete() {
    final elapsed = _startTime != null
        ? DateTime.now().difference(_startTime!).inMinutes
        : 0;
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 20),
                const Text('Workout Complete!', style: TextStyle(color: CLColors.text, fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Great session. Recover well.', style: TextStyle(color: CLColors.muted, fontSize: 14)),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _completeStat('Exercises', '${widget.exercises.length}'),
                    _completeStat('Duration', '${elapsed}m'),
                    _completeStat('Calories', '~${widget.exercises.length * 30 + elapsed * 5}'),
                  ],
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(200, 50)),
                  child: const Text('DONE'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _completeStat(String label, String value) => Column(
    children: [
      Text(value, style: const TextStyle(color: CLColors.accent, fontSize: 24, fontWeight: FontWeight.w700)),
      Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 12)),
    ],
  );
}
