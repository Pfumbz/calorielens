import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/ad_banner.dart';
import 'history_screen.dart';
import 'week_report_screen.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isPro = state.isPremium || state.hasApiKey;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildTitle(state),
              const SizedBox(height: 16),
              _buildCalorieRing(context, state),
              const SizedBox(height: 12),
              _buildMacroBars(state),
              const SizedBox(height: 12),
              _buildInsightsSection(context, state, isPro),
              const SizedBox(height: 16),
              // Today's Meals header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Today's Meals",
                      style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (state.diary.length > 3)
                        GestureDetector(
                          onTap: () => _showClearAll(context),
                          child: Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Text('Clear all',
                                style: TextStyle(color: CLColors.red.withOpacity(0.8), fontSize: 12)),
                          ),
                        ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistoryScreen()),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('History',
                                style: TextStyle(color: CLColors.accent.withOpacity(0.8), fontSize: 12)),
                            const SizedBox(width: 3),
                            Icon(Icons.chevron_right, color: CLColors.accent.withOpacity(0.8), size: 16),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (state.diary.isEmpty)
                _buildEmptyState(context)
              else
                _buildDiaryListWithAd(context, state, isPro),
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

  // ═══════════════════════════════════════════════════════════════════════════
  // TITLE
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTitle(AppState state) {
    final name = state.profile.name;
    final greeting = name.isNotEmpty ? 'Hey, $name 👋' : 'Today';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(greeting,
            style: const TextStyle(color: CLColors.text, fontSize: 22, fontWeight: FontWeight.w600)),
        Text(_formatDate(DateTime.now()),
            style: const TextStyle(color: CLColors.muted, fontSize: 12)),
      ],
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALORIE RING
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCalorieRing(BuildContext context, AppState state) {
    final used = state.totalCalories;
    final goal = state.calorieGoal;
    final pct  = goal > 0 ? (used / goal).clamp(0.0, 1.5) : 0.0;
    final left = goal - used;
    final isOver = left < 0;
    final ringColor = isOver
        ? CLColors.red
        : left < goal * 0.1
            ? CLColors.accent
            : CLColors.green;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: pct.clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, animVal, child) => CustomPaint(
                painter: _CalorieRingPainter(
                  progress: animVal,
                  ringColor: ringColor,
                  trackColor: CLColors.border,
                  strokeWidth: 12,
                ),
                child: child,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${left.abs()}',
                        style: TextStyle(color: ringColor, fontSize: 28, fontWeight: FontWeight.w800, height: 1.1)),
                    Text(isOver ? 'kcal over' : 'kcal left',
                        style: const TextStyle(color: CLColors.muted, fontSize: 11, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ringStatCol('$used', 'Eaten', CLColors.text),
              Container(width: 1, height: 28, color: CLColors.border),
              _ringStatCol('$goal', 'Goal', CLColors.muted),
              Container(width: 1, height: 28, color: CLColors.border),
              GestureDetector(
                onTap: () => _showGoalEditor(context, context.read<AppState>()),
                child: _ringStatCol('Edit', 'goal', CLColors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ringStatCol(String value, String label, Color valueColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: TextStyle(color: valueColor, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MACRO BARS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMacroBars(AppState state) {
    final goal = state.calorieGoal;
    final proteinTarget = (goal * 0.25 / 4).round();
    final carbsTarget   = (goal * 0.50 / 4).round();
    final fatTarget     = (goal * 0.25 / 9).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Row(
        children: [
          _compactMacro('Protein', state.totalProtein, proteinTarget, CLColors.blue),
          const SizedBox(width: 16),
          _compactMacro('Carbs', state.totalCarbs, carbsTarget, CLColors.green),
          const SizedBox(width: 16),
          _compactMacro('Fat', state.totalFat, fatTarget, CLColors.accent),
        ],
      ),
    );
  }

  Widget _compactMacro(String label, int value, int target, Color color) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.0) : 0.0;
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
              Text('${value}g', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: CLColors.border,
              color: color,
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INSIGHTS SECTION — premium, compact, prominent
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildInsightsSection(BuildContext context, AppState state, bool isPro) {
    final week = StorageService().getWeekDiaries();
    final cals = week.map((d) => d.entries.fold(0, (s, e) => s + e.calories)).toList();
    final logged = cals.where((c) => c > 0).length;
    final avg = logged > 0 ? cals.where((c) => c > 0).reduce((a, b) => a + b) ~/ logged : 0;
    final maxCal = cals.reduce((a, b) => a > b ? a : b);
    final barMax = maxCal > 0 ? maxCal.toDouble() : state.calorieGoal.toDouble();

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => isPro ? const WeekReportScreen() : const WeekReportPaywall(),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CLColors.surface,
              isPro ? CLColors.accent.withOpacity(0.04) : CLColors.goldLo.withOpacity(0.6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPro ? CLColors.accent.withOpacity(0.15) : CLColors.gold.withOpacity(0.2),
          ),
        ),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.insights, color: CLColors.accent, size: 18),
                const SizedBox(width: 8),
                const Text('Insights',
                    style: TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                if (!isPro)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFC4A040), Color(0xFFA08030)]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(color: Color(0xFF0E0C08), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
                  ),
                const Spacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, color: CLColors.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(avg > 0 ? '$avg kcal' : '— kcal',
                        style: const TextStyle(color: CLColors.accent, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 4),
                    const Text('avg', style: TextStyle(color: CLColors.muted, fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Mini bar chart
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final v = cals[i].toDouble();
                  final barH = barMax > 0 ? (v / barMax * 50).clamp(0.0, 50.0) : 0.0;
                  final isToday = i == 6;
                  final overGoal = v > state.calorieGoal && v > 0;
                  const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: v == 0 ? 4 : barH,
                            decoration: BoxDecoration(
                              color: v == 0
                                  ? CLColors.border
                                  : overGoal
                                      ? CLColors.red.withOpacity(0.7)
                                      : isToday
                                          ? CLColors.accent
                                          : CLColors.green.withOpacity(0.6),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(labels[i],
                              style: TextStyle(
                                color: isToday ? CLColors.accent : CLColors.muted,
                                fontSize: 10, fontWeight: FontWeight.w500,
                              )),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // CTA
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isPro
                    ? CLColors.accent.withOpacity(0.08)
                    : CLColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPro
                      ? CLColors.accent.withOpacity(0.2)
                      : CLColors.gold.withOpacity(0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isPro ? Icons.bar_chart_rounded : Icons.lock_outline,
                    color: isPro ? CLColors.accent : CLColors.gold,
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPro ? 'View Weekly Report' : 'Unlock Weekly Report',
                    style: TextStyle(
                      color: isPro ? CLColors.accent : CLColors.gold,
                      fontSize: 13, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right,
                      color: isPro ? CLColors.accent.withOpacity(0.6) : CLColors.gold.withOpacity(0.6),
                      size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIARY
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: const Column(
        children: [
          Text('🍽️', style: TextStyle(fontSize: 36)),
          SizedBox(height: 10),
          Text('No meals logged yet',
              style: TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
          SizedBox(height: 4),
          Text('Scan a meal or add manually',
              style: TextStyle(color: CLColors.muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildDiaryListWithAd(BuildContext context, AppState state, bool isPro) {
    final entries = state.diary;
    final widgets = <Widget>[];

    for (int i = 0; i < entries.length; i++) {
      widgets.add(_entryCard(context, entries[i], state));

      // Insert ad banner after the first entry (for free users)
      if (i == 0 && !isPro) {
        widgets.add(
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: AdBanner(),
            ),
          ),
        );
      }
    }

    // If no entries but still free, show ad at the end (fallback)
    if (entries.isEmpty && !isPro) {
      widgets.add(const AdBanner());
    }

    return Column(children: widgets);
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text('${e.time} · P:${e.protein}g  C:${e.carbs}g  F:${e.fat}g',
                      style: const TextStyle(color: CLColors.muted, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('${e.calories}',
                style: const TextStyle(color: CLColors.accent, fontSize: 16, fontWeight: FontWeight.w700)),
            const Text(' kcal', style: TextStyle(color: CLColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════════════════

  void _showClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CLColors.surface,
        title: const Text('Clear all meals?', style: TextStyle(color: CLColors.text)),
        content: Text(
          'This will remove all ${context.read<AppState>().diary.length} meals logged today. This cannot be undone.',
          style: const TextStyle(color: CLColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<AppState>().clearAllEntries();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: CLColors.red),
            child: const Text('Clear all'),
          ),
        ],
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
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20, right: 20, top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Meal Manually',
                style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            TextField(
                controller: nameCtrl,
                style: const TextStyle(color: CLColors.text),
                decoration: const InputDecoration(hintText: 'Meal name')),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: calCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: CLColors.text),
                      decoration: const InputDecoration(hintText: 'Calories', suffixText: 'kcal'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: protCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: CLColors.text),
                      decoration: const InputDecoration(hintText: 'Protein', suffixText: 'g'))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: TextField(
                      controller: carbCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: CLColors.text),
                      decoration: const InputDecoration(hintText: 'Carbs', suffixText: 'g'))),
              const SizedBox(width: 10),
              Expanded(
                  child: TextField(
                      controller: fatCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: CLColors.text),
                      decoration: const InputDecoration(hintText: 'Fat', suffixText: 'g'))),
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
                    time: '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
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

// ═══════════════════════════════════════════════════════════════════════════════
// Custom ring painter
// ═══════════════════════════════════════════════════════════════════════════════

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  final Color ringColor;
  final Color trackColor;
  final double strokeWidth;

  _CalorieRingPainter({
    required this.progress,
    required this.ringColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..color = trackColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round);

    if (progress > 0) {
      canvas.drawArc(
          Rect.fromCircle(center: centre, radius: radius),
          startAngle,
          sweepAngle,
          false,
          Paint()
            ..color = ringColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _CalorieRingPainter old) =>
      old.progress != progress || old.ringColor != ringColor;
}
