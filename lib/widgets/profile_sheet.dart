import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/calorie_goal.dart';

/// Opens the profile editing bottom sheet from anywhere in the app.
void showProfileSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ProfileSheet(),
  );
}

/// StatefulWidget so selections (sex, activity, goal) drive setState and the
/// TextEditingControllers are disposed when the sheet closes.
class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet();

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;

  String _sex = 'm';
  int _activityIdx = 2;
  String _goal = 'maintain';

  @override
  void initState() {
    super.initState();
    final p = context.read<AppState>().profile;
    _nameCtrl = TextEditingController(text: p.name);
    _ageCtrl = TextEditingController(text: p.age > 0 ? '${p.age}' : '');
    _weightCtrl = TextEditingController(
        text: p.weight > 0 ? _trimNum(p.weight) : '');
    _heightCtrl = TextEditingController(text: p.height > 0 ? '${p.height}' : '');
    if (p.sex == 'm' || p.sex == 'f') _sex = p.sex;
    _activityIdx = nearestActivityIndex(p.activity);
    _goal = StorageService().goalDirection;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  Future<void> _save() async {
    final appState = context.read<AppState>();
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final weight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
    final height = int.tryParse(_heightCtrl.text.trim()) ?? 0;

    final activity = kActivityOptions[_activityIdx].mult;
    var p = appState.profile.copyWith(
      name: _nameCtrl.text.trim(),
      age: age,
      weight: weight,
      height: height,
      sex: _sex,
      activity: activity,
    );

    // Recompute the calorie target when we have the full set of inputs.
    if (age > 0 && weight > 0 && height > 0) {
      final goalKcal = computeCalorieGoal(
        sex: _sex,
        age: age,
        weight: weight,
        height: height,
        activity: activity,
        goal: _goal,
      );
      p = p.copyWith(calorieGoal: goalKcal);
      await appState.saveCalorieGoal(goalKcal);
      await StorageService().setGoalDirection(_goal);
    }
    await appState.saveProfile(p);

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Profile saved'),
        backgroundColor: CLColors.green,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CLColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: CLColors.blue.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.person_outline,
                        color: CLColors.blue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Profile',
                            style: TextStyle(
                                color: CLColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text('Used to calculate your calorie target',
                            style:
                                TextStyle(color: CLColors.muted, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: CLColors.text),
                decoration: const InputDecoration(
                  hintText: 'Name',
                  prefixIcon: Icon(Icons.badge_outlined,
                      color: CLColors.muted, size: 18),
                ),
              ),
              const SizedBox(height: 14),

              _label('Sex'),
              Row(
                children: [
                  _pill('Male', _sex == 'm', () => setState(() => _sex = 'm')),
                  const SizedBox(width: 10),
                  _pill('Female', _sex == 'f', () => setState(() => _sex = 'f')),
                ],
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(child: _numField(_ageCtrl, 'Age', 'yrs')),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_weightCtrl, 'Weight', 'kg', decimal: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_heightCtrl, 'Height', 'cm')),
                ],
              ),
              const SizedBox(height: 18),

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
              const SizedBox(height: 18),

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
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text('SAVE CHANGES'),
                ),
              ),
            ],
          ),
        ),
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
}
