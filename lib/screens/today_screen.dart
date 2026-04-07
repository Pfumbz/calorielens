import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../theme.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              _buildTitle(state),
              const SizedBox(height: 20),
              _buildCalorieRing(context, state),
              const SizedBox(height: 16),
              _buildMacroBars(state),
              const SizedBox(height: 16),
              _buildWaterTracker(context, state),
              const SizedBox(height: 20),
              const Text('Today\'s Meals', style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              if (state.diary.isEmpty) _buildEmptyState(context) else _buildDiaryList(context, state),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        backgroundColor: CLColors.accent,
        foregroundColor: Colors.black,
        onPressed: () => _showAddManual(context, state),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTitle(AppState state) {
    final name = state.profile.name;
    final greeting = name.isNotEmpty ? 'Hey, $name 👋' : 'Today';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(greeting, style: const TextStyle(color: CLColors.text, fontSize: 22, fontWeight: FontWeight.w600)),
        Text(
          _formatDate(DateTime.now()),
          style: const TextStyle(color: CLColors.muted, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  Widget _buildCalorieRing(BuildContext context, AppState state) {
    final used = state.totalCalories;
    final goal = state.calorieGoal;
    final pct  = (used / goal).clamp(0.0, 1.0);
    final left = (goal - used);
    final color = left < 0
        ? CLColors.red
        : left < goal * 0.1
            ? CLColors.accent
            : CLColors.green;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CLColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: pct),
                  duration: const Duration(milliseconds: 800),
                  builder: (_, v, __) => CircularProgressIndicator(
                    value: v,
                    strokeWidth: 9,
                    backgroundColor: CLColors.border,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$used', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700, height: 1)),
                    const Text('eaten', style: TextStyle(color: CLColors.muted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _statRow('Goal', '$goal kcal', CLColors.muted),
                const SizedBox(height: 8),
                _statRow('Consumed', '$used kcal', CLColors.text),
                const SizedBox(height: 8),
                _statRow(left < 0 ? 'Over by' : 'Remaining', '${left.abs()} kcal', color),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => _showGoalEditor(context, context.read<AppState>()),
                  child: Text('Edit goal', style: TextStyle(color: CLColors.accent.withOpacity(0.8), fontSize: 11, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildMacroBars(AppState state) {
    final goal = state.calorieGoal;
    final proteinTarget = (goal * 0.25 / 4).round();
    final carbsTarget   = (goal * 0.50 / 4).round();
    final fatTarget     = (goal * 0.25 / 9).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        children: [
          _macroBar('Protein', state.totalProtein, proteinTarget, CLColors.blue),
          const SizedBox(height: 10),
          _macroBar('Carbs', state.totalCarbs, carbsTarget, CLColors.green),
          const SizedBox(height: 10),
          _macroBar('Fat', state.totalFat, fatTarget, CLColors.accent),
        ],
      ),
    );
  }

  Widget _macroBar(String label, int value, int target, Color color) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(width: 52, child: Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 12))),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: CLColors.border,
              color: color,
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('${value}g', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildWaterTracker(BuildContext context, AppState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CLColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop_outlined, color: CLColors.blue, size: 18),
          const SizedBox(width: 10),
          const Text('Water', style: TextStyle(color: CLColors.text, fontSize: 13)),
          const Spacer(),
          Row(
            children: List.generate(8, (i) {
              final filled = i < state.water;
              return GestureDetector(
                onTap: () {
                  final newVal = i < state.water ? i : i + 1;
                  context.read<AppState>().setWater(newVal);
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: filled ? CLColors.blue.withOpacity(0.3) : CLColors.surface2,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: filled ? CLColors.blue.withOpacity(0.5) : CLColors.border),
                  ),
                  child: filled ? const Icon(Icons.water_drop, size: 10, color: CLColors.blue) : null,
                ),
              );
            }),
          ),
          const SizedBox(width: 8),
          Text('${state.water}/8', style: const TextStyle(color: CLColors.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        children: [
          const Text('🍽️', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          const Text('No meals logged yet', style: TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          const Text('Scan a meal or add manually', style: TextStyle(color: CLColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDiaryList(BuildContext context, AppState state) {
    return Column(
      children: state.diary.map((e) => _entryCard(context, e, state)).toList(),
    );
  }

  Widget _entryCard(BuildContext context, DiaryEntry e, AppState state) {
    return Dismissible(
      key: Key(e.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: CLColors.redLo,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: CLColors.red),
      ),
      onDismissed: (_) => context.read<AppState>().removeEntry(e.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.name, style: const TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(
                  '${e.time} · P:${e.protein}g  C:${e.carbs}g  F:${e.fat}g',
                  style: const TextStyle(color: CLColors.muted, fontSize: 11),
                ),
              ],
            ),
            const Spacer(),
            Text('${e.calories}', style: const TextStyle(color: CLColors.accent, fontSize: 16, fontWeight: FontWeight.w700)),
            const Text(' kcal', style: TextStyle(color: CLColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showGoalEditor(BuildContext context, AppState state) {
    final ctrl = TextEditingController(text: state.calorieGoal.toString());
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CLColors.surface,
        title: const Text('Daily Calorie Goal', style: TextStyle(color: CLColors.text)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: CLColors.text),
          decoration: const InputDecoration(hintText: '2000', suffixText: 'kcal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text) ?? state.calorieGoal;
              context.read<AppState>().saveCalorieGoal(v.clamp(500, 6000));
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showAddManual(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final calCtrl  = TextEditingController();
    final protCtrl = TextEditingController();
    final carbCtrl = TextEditingController();
    final fatCtrl  = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CLColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Meal Manually', style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            TextField(controller: nameCtrl, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Meal name')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: calCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Calories', suffixText: 'kcal'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: protCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Protein', suffixText: 'g'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: carbCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Carbs', suffixText: 'g'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: fatCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Fat', suffixText: 'g'))),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) return;
                  final now = TimeOfDay.now();
                  context.read<AppState>().addEntry(DiaryEntry(
                    id: DateTime.now().millisecondsSinceEpoch,
                    time: '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}',
                    name: name,
                    calories: int.tryParse(calCtrl.text) ?? 0,
                    protein: int.tryParse(protCtrl.text) ?? 0,
                    carbs: int.tryParse(carbCtrl.text) ?? 0,
                    fat: int.tryParse(fatCtrl.text) ?? 0,
                  ));
                  Navigator.pop(context);
                },
                child: const Text('ADD MEAL'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
