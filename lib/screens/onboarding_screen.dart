import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/calorie_goal.dart';

/// First-run setup that captures the user's profile and computes a personalised
/// daily calorie target (Mifflin-St Jeor BMR × activity, adjusted for goal).
///
/// Shown once, gated by [StorageService.isOnboarded]. Skippable: "Skip for now"
/// marks onboarding done without changing the goal (the Today-screen profile
/// nudge still encourages completion later).
class OnboardingScreen extends StatefulWidget {
  /// Called after the user finishes or skips; the host rebuilds to show the app.
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();

  String _sex = 'm';
  int _activityIdx = 2;   // moderately active
  String _goal = 'maintain';

  int _step = 0;          // 0 = form, 1 = result
  int _computedGoal = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill from any existing profile so editors aren't starting blank.
    final p = context.read<AppState>().profile;
    if (p.age > 0) _ageCtrl.text = '${p.age}';
    if (p.weight > 0) _weightCtrl.text = _trimNum(p.weight);
    if (p.height > 0) _heightCtrl.text = '${p.height}';
    if (p.sex == 'm' || p.sex == 'f') _sex = p.sex;
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  void _onSeeGoal() {
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final height = int.tryParse(_heightCtrl.text.trim()) ?? 0;

    if (age < 13 || age > 100) {
      setState(() => _error = 'Enter a valid age (13–100).');
      return;
    }
    if (weight < 30 || weight > 300) {
      setState(() => _error = 'Enter a valid weight in kg (30–300).');
      return;
    }
    if (height < 100 || height > 250) {
      setState(() => _error = 'Enter a valid height in cm (100–250).');
      return;
    }

    setState(() {
      _error = null;
      _computedGoal = computeCalorieGoal(
        sex: _sex,
        age: age,
        weight: weight,
        height: height,
        activity: kActivityOptions[_activityIdx].mult,
        goal: _goal,
      );
      _step = 1;
    });
  }

  Future<void> _finish() async {
    final state = context.read<AppState>();
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final height = int.tryParse(_heightCtrl.text.trim()) ?? 0;

    await state.saveProfile(state.profile.copyWith(
      age: age,
      weight: weight,
      height: height,
      sex: _sex,
      activity: kActivityOptions[_activityIdx].mult,
      calorieGoal: _computedGoal,
    ));
    await state.saveCalorieGoal(_computedGoal);
    await StorageService().setGoalDirection(_goal);
    await StorageService().setOnboarded();

    // Activate the retention loop: ask for notification permission and turn on
    // meal reminders + smart nudges (the engine was previously dormant).
    try {
      await NotificationService.requestPermission();
      await NotificationService.setRemindersEnabled(true);
      await NotificationService.setNudgesEnabled(
        true,
        caloriesEaten: state.totalCalories,
        calorieGoal: _computedGoal,
      );
    } catch (_) {
      // Never block finishing onboarding on a notification hiccup.
    }

    if (mounted) widget.onComplete();
  }

  Future<void> _skip() async {
    await StorageService().setOnboarded();
    if (mounted) widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: _step == 0 ? _buildForm() : _buildResult(),
      ),
    );
  }

  // ── Step 0: form ───────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Personalise your goal',
                    style: TextStyle(
                        color: CLColors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'A few quick details so CalNova can set a daily calorie target that’s right for you — not a generic number.',
                  style: TextStyle(color: CLColors.muted, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 24),

                _label('Sex'),
                Row(
                  children: [
                    _pill('Male', _sex == 'm', () => setState(() => _sex = 'm')),
                    const SizedBox(width: 10),
                    _pill('Female', _sex == 'f', () => setState(() => _sex = 'f')),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _numField(_ageCtrl, 'Age', 'yrs')),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(_weightCtrl, 'Weight', 'kg', decimal: true)),
                    const SizedBox(width: 12),
                    Expanded(child: _numField(_heightCtrl, 'Height', 'cm')),
                  ],
                ),
                const SizedBox(height: 22),

                _label('Activity level'),
                ...List.generate(kActivityOptions.length, (i) {
                  final a = kActivityOptions[i];
                  return _selectRow(
                    title: a.label,
                    sub: a.sub,
                    selected: _activityIdx == i,
                    onTap: () => setState(() => _activityIdx = i),
                  );
                }),
                const SizedBox(height: 22),

                _label('Your goal'),
                _selectRow(
                  title: 'Lose weight',
                  sub: 'Gradual, sustainable calorie deficit',
                  selected: _goal == 'lose',
                  onTap: () => setState(() => _goal = 'lose'),
                ),
                _selectRow(
                  title: 'Maintain',
                  sub: 'Stay at your current weight',
                  selected: _goal == 'maintain',
                  onTap: () => setState(() => _goal = 'maintain'),
                ),
                _selectRow(
                  title: 'Gain weight',
                  sub: 'Build muscle with a calorie surplus',
                  selected: _goal == 'gain',
                  onTap: () => setState(() => _goal = 'gain'),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(_error!,
                      style: const TextStyle(color: CLColors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
        ),
        _footer(
          primaryLabel: 'See my goal',
          onPrimary: _onSeeGoal,
          onSkip: _skip,
        ),
      ],
    );
  }

  // ── Step 1: result ─────────────────────────────────────────────────────────
  Widget _buildResult() {
    final goalLabel = _goal == 'lose'
        ? 'lose weight'
        : _goal == 'gain'
            ? 'gain weight'
            : 'maintain';
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: CLColors.green, size: 56),
                const SizedBox(height: 20),
                const Text('Your daily calorie target',
                    style: TextStyle(color: CLColors.muted, fontSize: 15)),
                const SizedBox(height: 10),
                Text('$_computedGoal',
                    style: const TextStyle(
                        color: CLColors.accent,
                        fontSize: 64,
                        fontWeight: FontWeight.w800,
                        height: 1.0)),
                const Text('kcal / day',
                    style: TextStyle(color: CLColors.text, fontSize: 16)),
                const SizedBox(height: 20),
                Text(
                  'Personalised from your details to help you $goalLabel. You can change this any time in Settings.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: CLColors.muted, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ),
        _footer(
          primaryLabel: 'Start tracking',
          onPrimary: _finish,
          secondaryLabel: 'Back',
          onSecondary: () => setState(() => _step = 0),
        ),
      ],
    );
  }

  // ── Reusable pieces ────────────────────────────────────────────────────────
  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: const TextStyle(
                color: CLColors.text,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      );

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? CLColors.accentLo : CLColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? CLColors.accent : CLColors.border,
                width: selected ? 1.5 : 1),
          ),
          child: Text(label,
              style: TextStyle(
                  color: selected ? CLColors.accent : CLColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String hint, String suffix,
      {bool decimal = false}) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
      ],
      style: const TextStyle(color: CLColors.text, fontSize: 15),
      decoration: InputDecoration(hintText: hint, suffixText: suffix),
    );
  }

  Widget _selectRow({
    required String title,
    required String sub,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: selected ? CLColors.accentLo : CLColors.surface2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected ? CLColors.accent : CLColors.border,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: selected ? CLColors.accent : CLColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            color: CLColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? CLColors.accent : CLColors.muted2,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footer({
    required String primaryLabel,
    required VoidCallback onPrimary,
    VoidCallback? onSkip,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        color: CLColors.bg,
        border: Border(top: BorderSide(color: CLColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: CLColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: Text(primaryLabel,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 4),
          if (onSkip != null)
            TextButton(
              onPressed: onSkip,
              child: const Text('Skip for now',
                  style: TextStyle(color: CLColors.muted, fontSize: 14)),
            ),
          if (secondaryLabel != null && onSecondary != null)
            TextButton(
              onPressed: onSecondary,
              child: Text(secondaryLabel,
                  style: const TextStyle(color: CLColors.muted, fontSize: 14)),
            ),
        ],
      ),
    );
  }
}
