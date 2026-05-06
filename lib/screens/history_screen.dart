import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/upgrade_modal.dart';

/// Displays past diary entries grouped by day.
/// Accessible from the TodayScreen via a "View history" link.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _storage = StorageService();
  int _daysToLoad = 30;
  List<({DateTime date, List<DiaryEntry> entries})> _dayEntries = [];
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _loadData();
      _initialized = true;
    }
  }

  void _loadData() {
    final state = context.read<AppState>();
    final maxDays = state.historyRetainDays;
    final loadDays = _daysToLoad.clamp(1, maxDays);
    _dayEntries = _storage.getDiaryRange(days: loadDays);
  }

  void _loadMore() {
    setState(() {
      _daysToLoad += 30;
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final goal = state.calorieGoal;
    final isPro = state.isPremium || state.hasApiKey;
    final isGuest = !state.isSignedIn && !state.hasApiKey;

    return Scaffold(
      backgroundColor: CLColors.bg,
      appBar: AppBar(
        title: const Text('Meal History'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _dayEntries.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _dayEntries.length + 1 + (isPro ? 0 : 1), // +1 load more, +1 banner
              itemBuilder: (context, index) {
                // Tier upgrade banner at the top
                if (!isPro && index == 0) {
                  return _buildRetentionBanner(context, isGuest);
                }
                final adjustedIndex = isPro ? index : index - 1;
                if (adjustedIndex == _dayEntries.length) {
                  return isPro ? _buildLoadMore() : const SizedBox.shrink();
                }
                final day = _dayEntries[adjustedIndex];
                return _buildDayCard(day.date, day.entries, goal);
              },
            ),
    );
  }

  Widget _buildRetentionBanner(BuildContext context, bool isGuest) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CLColors.goldLo,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CLColors.gold.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.history, color: CLColors.gold.withOpacity(0.8), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isGuest
                      ? 'Only showing last 3 days'
                      : 'Only showing last 7 days',
                  style: const TextStyle(color: CLColors.gold, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  isGuest
                      ? 'Sign in to keep 7 days, or go Pro for unlimited history.'
                      : 'Upgrade to Pro for unlimited meal history.',
                  style: TextStyle(color: CLColors.gold.withOpacity(0.7), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => showUpgradeModal(context, source: 'history'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: CLColors.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CLColors.gold.withOpacity(0.3)),
              ),
              child: Text(
                isGuest ? 'Sign in' : 'Go Pro',
                style: const TextStyle(color: CLColors.gold, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          const Text(
            'No meal history yet',
            style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Meals you log will appear here',
            style: TextStyle(color: CLColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(DateTime date, List<DiaryEntry> entries, int goal) {
    final totalCal = entries.fold(0, (s, e) => s + e.calories);
    final totalProtein = entries.fold(0, (s, e) => s + e.protein);
    final totalCarbs = entries.fold(0, (s, e) => s + e.carbs);
    final totalFat = entries.fold(0, (s, e) => s + e.fat);
    final pct = goal > 0 ? (totalCal / goal).clamp(0.0, 1.5) : 0.0;
    final isToday = _isToday(date);
    final isYesterday = _isYesterday(date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isToday ? CLColors.accent.withOpacity(0.4) : CLColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
          initiallyExpanded: isToday,
          leading: _buildDayIndicator(pct, totalCal, goal),
          title: Text(
            isToday
                ? 'Today'
                : isYesterday
                    ? 'Yesterday'
                    : _formatDate(date),
            style: const TextStyle(
              color: CLColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${entries.length} meal${entries.length == 1 ? '' : 's'}  ·  '
            'P:${totalProtein}g  C:${totalCarbs}g  F:${totalFat}g',
            style: const TextStyle(color: CLColors.muted, fontSize: 11),
          ),
          trailing: Text(
            '$totalCal',
            style: TextStyle(
              color: totalCal > goal ? CLColors.red : CLColors.accent,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: entries.map((e) => _buildEntryRow(e)).toList(),
        ),
      ),
    );
  }

  Widget _buildDayIndicator(double pct, int totalCal, int goal) {
    final color = totalCal > goal
        ? CLColors.red
        : totalCal > goal * 0.8
            ? CLColors.accent
            : CLColors.green;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            strokeWidth: 3,
            backgroundColor: CLColors.border,
            valueColor: AlwaysStoppedAnimation(color),
          ),
          Text(
            '${(pct * 100).round()}%',
            style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(DiaryEntry e) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: CLColors.accent.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.name,
                  style: const TextStyle(color: CLColors.text, fontSize: 13, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${e.time}  ·  P:${e.protein}g  C:${e.carbs}g  F:${e.fat}g',
                  style: const TextStyle(color: CLColors.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${e.calories}',
            style: const TextStyle(color: CLColors.accent, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const Text(' kcal', style: TextStyle(color: CLColors.muted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton(
          onPressed: _loadMore,
          child: const Text(
            'Load more days',
            style: TextStyle(color: CLColors.accent, fontSize: 13),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────
  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isYesterday(DateTime d) {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return d.year == y.year && d.month == y.month && d.day == y.day;
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }
}
