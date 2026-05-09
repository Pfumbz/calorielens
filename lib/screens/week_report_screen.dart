import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/upgrade_modal.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// PAYWALL SCREEN — shown to free users
// ═══════════════════════════════════════════════════════════════════════════════

class WeekReportPaywall extends StatelessWidget {
  const WeekReportPaywall({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: CLColors.text, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text('Weekly Report',
                      style: TextStyle(color: CLColors.text, fontSize: 18, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFC4A040), Color(0xFFA08030)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('PRO',
                        style: TextStyle(color: Color(0xFF0E0C08), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            const Divider(color: CLColors.border, height: 1),

            // Blurred preview + lock overlay
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Lock icon
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: CLColors.goldLo,
                        shape: BoxShape.circle,
                        border: Border.all(color: CLColors.gold.withOpacity(0.3), width: 2),
                      ),
                      child: const Icon(Icons.lock_outline, color: CLColors.gold, size: 36),
                    ),
                    const SizedBox(height: 24),
                    // Title
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
                        children: [
                          TextSpan(text: 'Unlock Your Full\n', style: TextStyle(color: CLColors.text)),
                          TextSpan(text: 'Weekly Report', style: TextStyle(color: CLColors.accent)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Feature checklist
                    _paywallFeature('Detailed 7-day calorie analysis'),
                    _paywallFeature('Macro breakdown & trends'),
                    _paywallFeature('Goal adherence & consistency'),
                    _paywallFeature('Smart insights & recommendations'),
                    const SizedBox(height: 36),
                    // Upgrade button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          showUpgradeModal(context, source: 'week_report');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CLColors.accent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Upgrade to Pro'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: CLColors.muted, fontSize: 14)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _paywallFeature(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 22, height: 22,
            decoration: BoxDecoration(
              color: CLColors.accent.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: CLColors.accent, size: 14),
          ),
          const SizedBox(width: 12),
          Text(text, style: const TextStyle(color: CLColors.text, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// FULL WEEKLY REPORT — Pro users
// ═══════════════════════════════════════════════════════════════════════════════

class WeekReportScreen extends StatefulWidget {
  const WeekReportScreen({super.key});

  @override
  State<WeekReportScreen> createState() => _WeekReportScreenState();
}

class _WeekReportScreenState extends State<WeekReportScreen> {
  // AI insights
  List<_InsightCard> _insightCards = [];
  bool _loadingInsight = false;
  final _insightPageCtrl = PageController(viewportFraction: 0.78);
  int _insightPage = 0;

  // Week offset for navigation (0 = current week)
  int _weekOffset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _generateInsights());
  }

  @override
  void dispose() {
    _insightPageCtrl.dispose();
    super.dispose();
  }

  // ── Data helpers ──────────────────────────────────────────────────────
  List<({DateTime date, List<DiaryEntry> entries})> get _week =>
      StorageService().getWeekDiaries();

  List<int> _dayCals(List<({DateTime date, List<DiaryEntry> entries})> week) =>
      week.map((d) => d.entries.fold(0, (s, e) => s + e.calories)).toList();

  int _totalMacro(List<({DateTime date, List<DiaryEntry> entries})> week,
      int Function(DiaryEntry) selector) {
    int total = 0;
    for (final day in week) {
      for (final e in day.entries) {
        total += selector(e);
      }
    }
    return total;
  }

  // ── Date range label ─────────────────────────────────────────────────
  String _dateRangeLabel(List<({DateTime date, List<DiaryEntry> entries})> week) {
    if (week.isEmpty) return '';
    final start = week.first.date;
    final end = week.last.date;
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    if (start.month == end.month) {
      return '${months[start.month - 1]} ${start.day} – ${end.day}, ${end.year}';
    }
    return '${months[start.month - 1]} ${start.day} – ${months[end.month - 1]} ${end.day}, ${end.year}';
  }

  // ── Nutrition Score (0–100) ──────────────────────────────────────────
  int _nutritionScore(List<int> cals, int goal, int logged, int totalProtein, int totalCarbs, int totalFat) {
    if (logged == 0) return 0;
    // Consistency (max 30): how many days logged out of 7
    final consistencyScore = (logged / 7 * 30).round();
    // Goal adherence (max 40): how close to goal on average
    final avg = cals.where((c) => c > 0).reduce((a, b) => a + b) ~/ logged;
    final deviation = (avg - goal).abs() / goal;
    final goalScore = ((1 - deviation.clamp(0.0, 1.0)) * 40).round();
    // Macro balance (max 30): protein 25-35%, carbs 40-55%, fat 20-35%
    final totalMacro = totalProtein + totalCarbs + totalFat;
    if (totalMacro == 0) return consistencyScore + goalScore;
    final pPct = totalProtein / totalMacro;
    final cPct = totalCarbs / totalMacro;
    final fPct = totalFat / totalMacro;
    double macroDeviation = 0;
    macroDeviation += (pPct < 0.25 ? 0.25 - pPct : pPct > 0.35 ? pPct - 0.35 : 0);
    macroDeviation += (cPct < 0.40 ? 0.40 - cPct : cPct > 0.55 ? cPct - 0.55 : 0);
    macroDeviation += (fPct < 0.20 ? 0.20 - fPct : fPct > 0.35 ? fPct - 0.35 : 0);
    final macroScore = ((1 - (macroDeviation * 3).clamp(0.0, 1.0)) * 30).round();
    return (consistencyScore + goalScore + macroScore).clamp(0, 100);
  }

  String _scoreLabel(int score) {
    if (score >= 80) return 'Great progress!';
    if (score >= 60) return 'Good progress!';
    if (score >= 40) return 'Getting there!';
    if (score >= 20) return 'Keep going!';
    return 'Just starting!';
  }

  // ── AI Insight generation ─────────────────────────────────────────────
  Future<void> _generateInsights() async {
    if (_loadingInsight) return;
    setState(() {
      _loadingInsight = true;
      _insightCards = []; // Clear old cards
    });

    final state = context.read<AppState>();

    // Check prerequisites before calling backend
    if (!state.isSignedIn && !state.hasApiKey) {
      if (mounted) {
        setState(() {
          _loadingInsight = false;
          _insightCards = [
            _InsightCard(
              title: 'Sign In Required',
              body: 'AI insights need a signed-in account or API key. Tap to retry after signing in.',
              stat: '',
              icon: Icons.lock_outline,
              color: CLColors.muted,
            ),
          ];
        });
      }
      return;
    }

    final week = _week;
    final cals = _dayCals(week);
    final goal = state.calorieGoal;
    final logged = cals.where((c) => c > 0).length;

    // No data to analyse
    if (logged == 0) {
      if (mounted) {
        setState(() {
          _loadingInsight = false;
          _insightCards = [
            _InsightCard(
              title: 'No Data Yet',
              body: 'Log some meals first, then come back for AI-powered weekly insights.',
              stat: '',
              icon: Icons.restaurant_menu,
              color: CLColors.muted,
            ),
          ];
        });
      }
      return;
    }

    final avg = cals.where((c) => c > 0).reduce((a, b) => a + b) ~/ logged;
    final totalProtein = _totalMacro(week, (e) => e.protein);
    final totalCarbs = _totalMacro(week, (e) => e.carbs);
    final totalFat = _totalMacro(week, (e) => e.fat);

    final dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dayBreakdown = StringBuffer();
    for (int i = 0; i < week.length; i++) {
      final d = week[i].date;
      final cal = cals[i];
      final label = dayLabels[d.weekday - 1];
      final meals = week[i].entries.map((e) => '${e.name} (${e.calories} kcal)').join(', ');
      dayBreakdown.writeln('$label: ${cal > 0 ? "$cal kcal" : "not logged"}${meals.isNotEmpty ? " — $meals" : ""}');
    }

    final prompt = '''Analyse this user's week and generate exactly 4 insight cards. Each card must be on its own line and follow this exact format:
CARD_TITLE | CARD_BODY | STAT_VALUE

User's calorie goal: $goal kcal/day
Days logged: $logged / 7
Average daily calories: $avg kcal
Total protein: ${totalProtein}g | Total carbs: ${totalCarbs}g | Total fat: ${totalFat}g

Day-by-day:
$dayBreakdown

Generate 4 cards covering: 1) Protein Intake observation, 2) Consistency score, 3) Eating Pattern observation, 4) Top Recommendation.
Keep each card body under 30 words. STAT_VALUE should be a short metric like "$logged / 7 days" or "${totalProtein}g avg".
Output ONLY the 4 lines, nothing else.''';

    try {
      debugPrint('[WeekReport] Generating AI insights...');
      final response = await state.backend.chat(
        history: [],
        userMessage: prompt,
        systemPrompt: 'You are CalorieLens, an AI nutrition coach. Output exactly 4 lines in the requested format. No extra text.',
      );
      debugPrint('[WeekReport] AI response received: ${response.substring(0, response.length.clamp(0, 100))}');
      if (mounted) {
        final cards = <_InsightCard>[];
        final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final icons = [Icons.fitness_center, Icons.check_circle_outline, Icons.schedule, Icons.lightbulb_outline];
        final colors = [CLColors.blue, CLColors.green, CLColors.accent, CLColors.purple];
        for (int i = 0; i < lines.length && i < 4; i++) {
          final parts = lines[i].split('|').map((s) => s.trim()).toList();
          if (parts.length >= 2) {
            cards.add(_InsightCard(
              title: parts[0],
              body: parts[1],
              stat: parts.length > 2 ? parts[2] : '',
              icon: icons[i % 4],
              color: colors[i % 4],
            ));
          }
        }
        if (cards.isEmpty) {
          // AI returned something but couldn't parse cards
          cards.add(_InsightCard(
            title: 'Processing Error',
            body: 'Tap to retry — AI response format was unexpected.',
            stat: '',
            icon: Icons.refresh,
            color: CLColors.accent,
          ));
        }
        setState(() => _insightCards = cards);
      }
    } catch (e) {
      debugPrint('[WeekReport] AI insight error: $e');
      if (mounted) {
        final errorMsg = e.toString().replaceFirst('Exception: ', '');
        setState(() {
          _insightCards = [
            _InsightCard(
              title: 'Insights Unavailable',
              body: errorMsg.length > 80 ? 'Tap to retry. Check your connection.' : errorMsg,
              stat: 'Tap to retry',
              icon: Icons.refresh,
              color: CLColors.accent,
            ),
          ];
        });
      }
    } finally {
      if (mounted) setState(() => _loadingInsight = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final week = _week;
    final cals = _dayCals(week);
    final logged = cals.where((c) => c > 0).length;
    final avg = logged > 0 ? cals.where((c) => c > 0).reduce((a, b) => a + b) ~/ logged : 0;
    final best = cals.reduce((a, b) => a > b ? a : b);
    final goal = state.calorieGoal;

    // Find best day name
    final bestIdx = cals.indexOf(best);
    const dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final bestDayName = best > 0 && bestIdx >= 0 && bestIdx < week.length
        ? dayNames[week[bestIdx].date.weekday - 1]
        : '—';

    // Macro totals
    final totalProtein = _totalMacro(week, (e) => e.protein);
    final totalCarbs = _totalMacro(week, (e) => e.carbs);
    final totalFat = _totalMacro(week, (e) => e.fat);
    final totalFiber = _totalMacro(week, (e) => e.fiber);
    final totalMacroGrams = totalProtein + totalCarbs + totalFat;

    // Goal adherence
    final daysAtOrUnder = cals.where((c) => c > 0 && c <= goal).length;
    final adherencePercent = logged > 0 ? (daysAtOrUnder / logged * 100).round() : 0;

    // Nutrition score
    final score = _nutritionScore(cals, goal, logged, totalProtein, totalCarbs, totalFat);

    // Macro percentages
    final proteinPct = totalMacroGrams > 0 ? (totalProtein / totalMacroGrams * 100).round() : 0;
    final carbsPct = totalMacroGrams > 0 ? (totalCarbs / totalMacroGrams * 100).round() : 0;
    final fatPct = totalMacroGrams > 0 ? (totalFat / totalMacroGrams * 100).round() : 0;

    // Macro targets (weekly)
    final proteinTarget = (goal * 0.25 / 4 * logged).round();
    final carbsTarget = (goal * 0.50 / 4 * logged).round();
    final fatTarget = (goal * 0.25 / 9 * logged).round();
    final fiberTarget = 25 * logged;

    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, color: CLColors.text, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Weekly Progress Report',
                        style: TextStyle(color: CLColors.text, fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFC4A040), Color(0xFFA08030)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.emoji_events, color: Color(0xFF0E0C08), size: 12),
                        const SizedBox(width: 4),
                        const Text('PRO',
                            style: TextStyle(color: Color(0xFF0E0C08), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Date range selector ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {}, // Future: navigate weeks
                    child: Icon(Icons.chevron_left, color: CLColors.muted, size: 22),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.calendar_today, color: CLColors.muted, size: 14),
                  const SizedBox(width: 6),
                  Text(_dateRangeLabel(week),
                      style: const TextStyle(color: CLColors.text, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {},
                    child: Icon(Icons.chevron_right, color: CLColors.muted, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Scrollable content ──────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // ── Nutrition Score ──────────────────────────────
                    _buildScoreCard(score, logged),
                    const SizedBox(height: 14),

                    // ── Summary cards ────────────────────────────────
                    Row(children: [
                      _summaryCard(Icons.local_fire_department, 'Avg Daily', avg > 0 ? '$avg' : '—', 'kcal',
                        logged < 3 ? '$logged day${logged == 1 ? '' : 's'} logged' : '7-day average', CLColors.accent),
                      const SizedBox(width: 8),
                      _summaryCard(Icons.trending_up, 'Best Day', best > 0 ? '$best' : '—', 'kcal', bestDayName, CLColors.green),
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      _summaryCard(Icons.calendar_today, 'Days Logged', '$logged', '/ 7',
                        logged >= 5 ? 'Great consistency!' : logged < 3 ? 'Log 3+ for insights' : 'Keep it up!', CLColors.blue),
                      const SizedBox(width: 8),
                      _summaryCard(Icons.check_circle_outline, 'Goal Hit', '$adherencePercent', '%',
                        logged < 3 ? 'On $logged logged day${logged == 1 ? '' : 's'}' : 'On logged days',
                        adherencePercent >= 70 ? CLColors.green : CLColors.accent),
                    ]),

                    const SizedBox(height: 24),

                    // ── Calorie Trend (Bar Chart) ────────────────────
                    _sectionTitle('Calorie Trend'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                      decoration: _cardDecoration(),
                      child: Column(
                        children: [
                          // Goal label
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Container(width: 16, height: 2, color: CLColors.accent.withOpacity(0.5)),
                              const SizedBox(width: 4),
                              const Text('Goal', style: TextStyle(color: CLColors.muted, fontSize: 10)),
                              const SizedBox(width: 6),
                              Text('$goal kcal',
                                  style: const TextStyle(color: CLColors.accent, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 200,
                            child: _buildBarChart(cals, week, goal),
                          ),
                        ],
                      ),
                    ),

                    // ── AI Tip card ──────────────────────────────────
                    if (_insightCards.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildAiTipCard(),
                    ],

                    const SizedBox(height: 24),

                    // ── Macro Breakdown + Nutrient Highlights ─────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Macro breakdown
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: _cardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Macro Breakdown',
                                    style: TextStyle(color: CLColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                                Text('Weekly Avg',
                                    style: TextStyle(color: CLColors.muted.withOpacity(0.6), fontSize: 10)),
                                const SizedBox(height: 12),
                                if (totalMacroGrams > 0) ...[
                                  // Mini pie chart
                                  SizedBox(
                                    width: double.infinity,
                                    height: 100,
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 2,
                                        centerSpaceRadius: 22,
                                        sections: [
                                          PieChartSectionData(value: totalProtein.toDouble(), color: CLColors.blue, radius: 24, title: ''),
                                          PieChartSectionData(value: totalCarbs.toDouble(), color: const Color(0xFFFFBE0B), radius: 24, title: ''),
                                          PieChartSectionData(value: totalFat.toDouble(), color: const Color(0xFFFF6B6B), radius: 24, title: ''),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _macroLegendRow('Protein', '${totalProtein}g', '$proteinPct%', _macroRating(proteinPct, 25, 35), CLColors.blue),
                                  const SizedBox(height: 6),
                                  _macroLegendRow('Carbs', '${totalCarbs}g', '$carbsPct%', _macroRating(carbsPct, 40, 55), const Color(0xFFFFBE0B)),
                                  const SizedBox(height: 6),
                                  _macroLegendRow('Fat', '${totalFat}g', '$fatPct%', _macroRating(fatPct, 20, 35), const Color(0xFFFF6B6B)),
                                ] else
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Center(child: Text('No data', style: TextStyle(color: CLColors.muted, fontSize: 12))),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Nutrient highlights
                        Expanded(
                          flex: 3,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: _cardDecoration(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Nutrient Highlights',
                                    style: TextStyle(color: CLColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 14),
                                _nutrientBar('Protein', totalProtein, proteinTarget, CLColors.blue),
                                const SizedBox(height: 10),
                                _nutrientBar('Carbs', totalCarbs, carbsTarget, const Color(0xFFFFBE0B)),
                                const SizedBox(height: 10),
                                _nutrientBar('Fat', totalFat, fatTarget, const Color(0xFFFF6B6B)),
                                const SizedBox(height: 10),
                                _nutrientBar('Fiber', totalFiber, fiberTarget, CLColors.green),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── AI Insights (swipeable cards) ─────────────────
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: CLColors.accent, size: 16),
                        const SizedBox(width: 6),
                        _sectionTitle('AI Insights'),
                        const Spacer(),
                        if (_insightCards.length > 1)
                          Text('← Swipe →', style: TextStyle(color: CLColors.muted.withOpacity(0.5), fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInsightCarousel(),

                    const SizedBox(height: 24),

                    // ── Day-by-Day Log (today first, swipe for older) ─
                    _sectionTitle('Day-by-Day Log'),
                    const SizedBox(height: 12),
                    Builder(
                      builder: (_) {
                        // Reverse so today appears first on the left
                        final reversedWeek = week.reversed.toList();
                        final reversedCals = cals.reversed.toList();
                        return SizedBox(
                          height: 140,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: reversedWeek.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => _dayLogCard(reversedWeek[i], reversedCals[i], goal, best),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, color: CLColors.muted.withOpacity(0.5), size: 12),
                          const SizedBox(width: 4),
                          Text('Logging more days = more accurate insights',
                              style: TextStyle(color: CLColors.muted.withOpacity(0.5), fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WIDGETS
  // ═══════════════════════════════════════════════════════════════════════

  Widget _sectionTitle(String title) {
    return Text(title, style: const TextStyle(color: CLColors.text, fontSize: 15, fontWeight: FontWeight.w600));
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: CLColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: CLColors.border),
    );
  }

  // ── Score card ─────────────────────────────────────────────────────
  Widget _buildScoreCard(int score, int logged) {
    final isLowData = logged < 3;
    final label = isLowData ? 'Just starting' : _scoreLabel(score);
    final scoreColor = isLowData
        ? CLColors.muted
        : score >= 70 ? CLColors.green : score >= 40 ? CLColors.accent : CLColors.red;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1510), Color(0xFF141210)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isLowData ? CLColors.border : CLColors.accent.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 90, height: 90,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                progress: isLowData ? 0.0 : score / 100,
                color: scoreColor,
              ),
              child: Center(
                child: isLowData
                    ? Icon(Icons.trending_up, color: CLColors.muted, size: 28)
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('$score', style: TextStyle(
                            color: scoreColor,
                            fontSize: 28, fontWeight: FontWeight.w800, height: 1,
                          )),
                          const Text('/100', style: TextStyle(color: CLColors.muted, fontSize: 10)),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(label,
                        style: TextStyle(color: isLowData ? CLColors.muted : CLColors.green, fontSize: 16, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    if (!isLowData) ...[
                      const SizedBox(width: 4),
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      const Text('🏆', style: TextStyle(fontSize: 18)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isLowData
                      ? 'Log 3+ days to unlock a reliable nutrition score. Keep going!'
                      : logged >= 5
                          ? 'Consistency is your superpower.'
                          : 'Log more days for better insights.',
                  style: TextStyle(color: CLColors.muted.withOpacity(0.7), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 6),
                Text(
                  isLowData ? 'Preliminary · $logged of 7 days logged' : 'Nutrition Score',
                  style: TextStyle(color: CLColors.muted.withOpacity(0.5), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────
  Widget _summaryCard(IconData icon, String label, String value, String unit, String subtitle, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 14),
                const SizedBox(width: 6),
                Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700, height: 1)),
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(unit, style: TextStyle(color: color.withOpacity(0.6), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: CLColors.muted, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  // ── Bar chart ─────────────────────────────────────────────────────
  Widget _buildBarChart(List<int> cals, List<({DateTime date, List<DiaryEntry> entries})> week, int goal) {
    final maxVal = cals.reduce((a, b) => a > b ? a : b);
    final maxY = math.max(maxVal * 1.2, goal * 1.2).toDouble().clamp(1500.0, 8000.0);
    const dayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1000,
          getDrawingHorizontalLine: (_) => const FlLine(color: CLColors.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1000,
              getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: CLColors.muted, fontSize: 9)),
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= cals.length) return const SizedBox();
                final isToday = idx == 6;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 4),
                    Text(dayLabels[idx],
                        style: TextStyle(color: isToday ? CLColors.accent : CLColors.muted, fontSize: 10, fontWeight: FontWeight.w500)),
                    if (cals[idx] > 0)
                      Text('${cals[idx]}',
                          style: TextStyle(color: isToday ? CLColors.accent : CLColors.muted, fontSize: 8)),
                  ],
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
                toY: v > 0 ? v : 0,
                color: v == 0
                    ? CLColors.border
                    : overGoal
                        ? CLColors.accent
                        : isToday
                            ? CLColors.green
                            : CLColors.green.withOpacity(0.6),
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              ),
            ],
          );
        }),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(
              y: goal.toDouble(),
              color: CLColors.red.withOpacity(0.5),
              strokeWidth: 1.5,
              dashArray: [5, 4],
            ),
          ],
        ),
      ),
    );
  }

  // ── AI Tip card (tappable to expand) ────────────────────────────────
  Widget _buildAiTipCard() {
    final tipCard = _insightCards.isNotEmpty ? _insightCards.last : null;
    return GestureDetector(
      onTap: tipCard != null ? () => _showInsightDetail(tipCard) : null,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: CLColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.tips_and_updates_outlined, color: CLColors.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipCard?.title ?? 'Tip',
                    style: const TextStyle(color: CLColors.text, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tipCard?.body ?? 'Loading...',
                    style: TextStyle(color: CLColors.muted.withOpacity(0.7), fontSize: 11, height: 1.3),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: CLColors.accent, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Macro legend row with rating badge ─────────────────────────────
  Widget _macroLegendRow(String label, String grams, String pct, String rating, Color color) {
    final ratingColor = rating == 'Good' ? CLColors.green : rating == 'Low' ? CLColors.blue : CLColors.red;
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: CLColors.text, fontSize: 10), maxLines: 1),
        const Spacer(),
        Text(grams, style: const TextStyle(color: CLColors.text, fontSize: 10, fontWeight: FontWeight.w600)),
        const SizedBox(width: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: ratingColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(rating, style: TextStyle(color: ratingColor, fontSize: 7, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  String _macroRating(int pct, int low, int high) {
    if (pct < low) return 'Low';
    if (pct > high) return 'High';
    return 'Good';
  }

  // ── Nutrient bar ──────────────────────────────────────────────────
  Widget _nutrientBar(String label, int value, int target, Color color) {
    final pct = target > 0 ? (value / target).clamp(0.0, 1.5) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(color: CLColors.muted, fontSize: 10)),
            const Spacer(),
            Text('${value}g', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            Text(' / ${target}g', style: const TextStyle(color: CLColors.muted, fontSize: 9)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct.clamp(0.0, 1.0),
            backgroundColor: CLColors.border,
            color: pct > 1.0 ? CLColors.red : color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── AI Insight carousel ───────────────────────────────────────────
  Widget _buildInsightCarousel() {
    if (_loadingInsight) {
      return Container(
        height: 130,
        decoration: _cardDecoration(),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: CLColors.accent)),
              SizedBox(height: 8),
              Text('Generating insights...', style: TextStyle(color: CLColors.muted, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_insightCards.isEmpty) {
      return Container(
        height: 130,
        decoration: _cardDecoration(),
        child: Center(
          child: GestureDetector(
            onTap: _generateInsights,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, color: CLColors.accent, size: 24),
                const SizedBox(height: 8),
                const Text('Tap to generate insights', style: TextStyle(color: CLColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }

    // Check if this is a single error/retry card
    final isRetryable = _insightCards.length == 1 &&
        (_insightCards[0].icon == Icons.refresh ||
         _insightCards[0].icon == Icons.lock_outline ||
         _insightCards[0].icon == Icons.restaurant_menu);

    return Column(
      children: [
        SizedBox(
          height: 140,
          child: PageView.builder(
            controller: _insightPageCtrl,
            onPageChanged: (i) => setState(() => _insightPage = i),
            itemCount: _insightCards.length,
            itemBuilder: (_, i) {
              final card = _insightCards[i];
              final child = Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CLColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: card.color.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(card.icon, color: card.color, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(card.title,
                              style: TextStyle(color: card.color, fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(card.body,
                          style: const TextStyle(color: CLColors.text, fontSize: 12, height: 1.4),
                          maxLines: 3, overflow: TextOverflow.ellipsis),
                    ),
                    Row(
                      children: [
                        if (card.stat.isNotEmpty)
                          Expanded(child: Text(card.stat, style: TextStyle(color: CLColors.muted, fontSize: 10))),
                        if (!isRetryable)
                          Text('Tap to read more', style: TextStyle(color: card.color.withOpacity(0.5), fontSize: 9)),
                      ],
                    ),
                  ],
                ),
              );
              // Error cards → retry; real insight cards → expand
              if (isRetryable && card.icon == Icons.refresh) {
                return GestureDetector(onTap: _generateInsights, child: child);
              }
              return GestureDetector(
                onTap: () => _showInsightDetail(card),
                child: child,
              );
            },
          ),
        ),
        if (_insightCards.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_insightCards.length, (i) => Container(
              width: 6, height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == _insightPage ? CLColors.accent : CLColors.border,
                shape: BoxShape.circle,
              ),
            )),
          ),
        ],
      ],
    );
  }

  // ── Insight detail bottom sheet ────────────────────────────────────
  void _showInsightDetail(_InsightCard card) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: CLColors.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            // Icon + title
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: card.color.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(card.icon, color: card.color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(card.title,
                      style: TextStyle(color: card.color, fontSize: 17, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            // Full body text — no truncation
            Text(card.body,
                style: const TextStyle(color: CLColors.text, fontSize: 14, height: 1.6)),
            if (card.stat.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: card.color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: card.color.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_outlined, color: card.color, size: 14),
                    const SizedBox(width: 6),
                    Text(card.stat, style: TextStyle(color: card.color, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            // Close button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: CLColors.muted, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Day-by-day log card ───────────────────────────────────────────
  Widget _dayLogCard(({DateTime date, List<DiaryEntry> entries}) day, int cal, int goal, int bestCal) {
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final label = dayNames[day.date.weekday - 1];
    final dateStr = '${day.date.day}/${day.date.month}';
    final isToday = _isToday(day.date);
    final isBest = cal > 0 && cal == bestCal;
    final atGoal = cal > 0 && cal <= goal;
    final protein = day.entries.fold(0, (s, e) => s + e.protein);
    final carbs = day.entries.fold(0, (s, e) => s + e.carbs);
    final fat = day.entries.fold(0, (s, e) => s + e.fat);

    return Container(
      width: 100,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isToday ? CLColors.accent.withOpacity(0.06) : CLColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isToday ? CLColors.accent.withOpacity(0.3) : CLColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(
                color: isToday ? CLColors.accent : CLColors.text,
                fontSize: 13, fontWeight: FontWeight.w600,
              )),
              const Spacer(),
              if (isBest)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: CLColors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(3)),
                  child: const Text('Best', style: TextStyle(color: CLColors.red, fontSize: 7, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          Text(dateStr, style: const TextStyle(color: CLColors.muted, fontSize: 10)),
          const Spacer(),
          if (cal > 0) ...[
            Text('$cal', style: TextStyle(
              color: isToday ? CLColors.accent : CLColors.text,
              fontSize: 18, fontWeight: FontWeight.w700,
            )),
            Text('kcal', style: TextStyle(color: CLColors.muted.withOpacity(0.6), fontSize: 9)),
            const SizedBox(height: 4),
            if (atGoal)
              Icon(Icons.check_circle, color: CLColors.green, size: 14)
            else
              Icon(Icons.warning_amber_rounded, color: CLColors.accent, size: 14),
            const SizedBox(height: 4),
            // Mini macros
            Wrap(
              spacing: 3,
              children: [
                _tinyMacro('P', protein, CLColors.blue),
                _tinyMacro('C', carbs, const Color(0xFFFFBE0B)),
                _tinyMacro('F', fat, const Color(0xFFFF6B6B)),
              ],
            ),
          ] else ...[
            const Text('Not logged', style: TextStyle(color: CLColors.muted, fontSize: 11)),
            const Spacer(),
            const Center(child: Text('—', style: TextStyle(color: CLColors.muted, fontSize: 20))),
          ],
        ],
      ),
    );
  }

  Widget _tinyMacro(String letter, int g, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 2),
        Text('$letter ${g}g', style: const TextStyle(color: CLColors.muted, fontSize: 7)),
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HELPER CLASSES
// ═══════════════════════════════════════════════════════════════════════════════

class _InsightCard {
  final String title;
  final String body;
  final String stat;
  final IconData icon;
  final Color color;

  _InsightCard({required this.title, required this.body, required this.stat, required this.icon, required this.color});
}

/// Ring painter for the nutrition score
class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 8) / 2;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress;

    // Track
    canvas.drawCircle(
      centre, radius,
      Paint()..color = CLColors.border..style = PaintingStyle.stroke..strokeWidth = 6,
    );
    // Progress
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        startAngle, sweepAngle, false,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 6..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}
