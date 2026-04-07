import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/upgrade_modal.dart';

class TrendsScreen extends StatelessWidget {
  const TrendsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final week  = StorageService().getWeekDiaries();
    final cals  = week.map((d) => d.entries.fold(0, (s, e) => s + e.calories)).toList();
    final logged= cals.where((c) => c > 0).length;
    final avg   = logged > 0 ? cals.where((c) => c > 0).reduce((a,b) => a+b) ~/ logged : 0;
    final best  = cals.reduce((a,b) => a > b ? a : b);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              const Text('Trends', style: TextStyle(color: CLColors.text, fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // Weekly report button
              GestureDetector(
                onTap: () => state.isPremium
                    ? _showWeekReport(context, week, avg, logged, best, state.calorieGoal)
                    : showUpgradeModal(context, source: 'week_report'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: CLColors.goldLo,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: CLColors.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('📊', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('View My Week — Full 7-Day Report',
                            style: TextStyle(color: CLColors.gold, fontSize: 13, fontWeight: FontWeight.w500)),
                      ),
                      Icon(state.isPremium ? Icons.arrow_forward_ios : Icons.lock_outline,
                          color: CLColors.gold, size: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Summary stats
              Row(children: [
                _statCard('7-day avg', avg > 0 ? '$avg kcal' : '—'),
                const SizedBox(width: 10),
                _statCard('Best day', best > 0 ? '$best kcal' : '—'),
                const SizedBox(width: 10),
                _statCard('Days logged', '$logged / 7'),
              ]),
              const SizedBox(height: 16),
              // Bar chart
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: CLColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: CLColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('7-Day Calorie History', style: TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 180,
                      child: _buildChart(cals, week, state.calorieGoal),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Streak card
              _buildStreakCard(logged),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(List<int> cals, List<dynamic> week, int goal) {
    const dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (cals.reduce((a,b) => a>b?a:b) * 1.2).toDouble().clamp(2500, 5000),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 500,
          getDrawingHorizontalLine: (_) => const FlLine(color: CLColors.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                final isToday = idx == 6;
                return Text(
                  idx >= 0 && idx < dayLabels.length ? dayLabels[idx] : '',
                  style: TextStyle(color: isToday ? CLColors.accent : CLColors.muted, fontSize: 11, fontWeight: FontWeight.w500),
                );
              },
            ),
          ),
        ),
        barGroups: List.generate(cals.length, (i) {
          final v = cals[i].toDouble();
          final isToday = i == 6;
          final overGoal = v > goal;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: v,
                color: v == 0
                    ? CLColors.border
                    : overGoal
                        ? CLColors.red.withOpacity(0.8)
                        : isToday
                            ? CLColors.accent
                            : CLColors.green.withOpacity(0.7),
                width: 20,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              )
            ],
          );
        }),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goal.toDouble(),
              color: CLColors.accent.withOpacity(0.4),
              strokeWidth: 1.5,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                labelResolver: (_) => 'Goal',
                style: const TextStyle(color: CLColors.accent, fontSize: 9),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(int logged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Row(
        children: [
          const Text('🔥', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$logged-day streak', style: const TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
              const Text('Keep logging every day!', style: TextStyle(color: CLColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  void _showWeekReport(BuildContext context, List<dynamic> week, int avg, int logged, int best, int goal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CLColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: CLColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('📊 Your Week in Review', style: TextStyle(color: CLColors.text, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              _reportStat('Average daily calories', '$avg kcal', CLColors.accent),
              _reportStat('Days logged', '$logged / 7', CLColors.blue),
              _reportStat('Best day', '$best kcal', CLColors.green),
              _reportStat('Calorie goal', '$goal kcal', CLColors.muted),
              const SizedBox(height: 16),
              const Divider(color: CLColors.border),
              const SizedBox(height: 12),
              const Text('Day Breakdown', style: TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              ...week.asMap().entries.map((entry) {
                final d   = entry.value.date as DateTime;
                final cal = (entry.value.entries as List).fold(0, (s, e) => s + (e as dynamic).calories as int);
                const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
                final label = '${days[d.weekday - 1]} ${d.day}/${d.month}';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 70, child: Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 12))),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: goal > 0 ? (cal / goal).clamp(0.0, 1.0) : 0,
                            backgroundColor: CLColors.border,
                            color: cal == 0 ? CLColors.border : cal > goal ? CLColors.red : CLColors.green,
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(cal > 0 ? '$cal' : '—', style: TextStyle(color: cal > 0 ? CLColors.text : CLColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reportStat(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 13)),
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
