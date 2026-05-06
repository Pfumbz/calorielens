import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/pricing.dart';
import '../widgets/upgrade_modal.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  /// Whether the coach chat currently has messages (used by AppShell for back nav).
  static bool hasChatMessages = false;

  /// Clears the chat (called by AppShell when handling back).
  static VoidCallback? clearChat;

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  // ── Meal suggestion state (Pro) ───────────────────────────────────────
  bool _suggestionsLoading = false;
  List<_MealSuggestion>? _mealSuggestions;
  final List<String> _previousSuggestionNames = []; // track for variety

  // ── System Prompt (tiered) ────────────────────────────────────────────
  String _buildSystemPrompt(AppState state) {
    final diary = state.diary;
    final goal = state.calorieGoal;
    final used = state.totalCalories;
    final name = state.profile.name;
    final p = state.profile;
    final isPro = state.isPremium || state.hasApiKey;

    final diaryStr = diary.isEmpty
        ? 'No meals logged yet today.'
        : diary
            .map((e) =>
                '${e.time} ${e.name}: ${e.calories} Cal (P:${e.protein}g C:${e.carbs}g F:${e.fat}g)')
            .join('\n');

    final buf = StringBuffer();
    buf.writeln(
        'You are CalorieLens Smart Coach — an expert AI nutrition coach that is warm, concise, and action-oriented.');
    if (name.isNotEmpty) buf.writeln('User\'s name: $name.');
    if (p.weight > 0) {
      buf.writeln(
          'Profile: ${p.weight}kg, ${p.height}cm, age ${p.age}, sex: ${p.sex.isNotEmpty ? p.sex : 'not set'}, activity level: ${p.activity}');
    }

    buf.writeln('\nTODAY\'S DATA:');
    buf.writeln('Calorie goal: $goal kcal');
    buf.writeln(
        'Consumed: $used kcal | Remaining: ${(goal - used).clamp(0, 9999)} kcal');
    buf.writeln(
        'Protein: ${state.totalProtein}g | Carbs: ${state.totalCarbs}g | Fat: ${state.totalFat}g');
    buf.writeln('Water: ${state.water}/8 glasses');
    buf.writeln('\nTODAY\'S MEALS:\n$diaryStr');

    if (isPro) {
      buf.writeln(
          '\n── PRO CONTEXT (use this to give deeper, personalised advice) ──');

      final weekData = StorageService().getWeekDiaries();
      final weekSummary = <String>[];
      int totalWeekCal = 0, daysWithData = 0;
      int totalWeekProtein = 0, totalWeekCarbs = 0, totalWeekFat = 0;

      for (final day in weekData) {
        final cal = day.entries.fold<int>(0, (s, e) => s + e.calories);
        final pro = day.entries.fold<int>(0, (s, e) => s + e.protein);
        final carb = day.entries.fold<int>(0, (s, e) => s + e.carbs);
        final fat = day.entries.fold<int>(0, (s, e) => s + e.fat);
        if (day.entries.isNotEmpty) {
          daysWithData++;
          totalWeekCal += cal;
          totalWeekProtein += pro;
          totalWeekCarbs += carb;
          totalWeekFat += fat;
          weekSummary.add(
              '${day.date.month}/${day.date.day}: ${day.entries.length} meals, $cal kcal (P:${pro}g C:${carb}g F:${fat}g)');
        }
      }

      if (daysWithData > 0) {
        buf.writeln('\n7-DAY HISTORY:');
        for (final s in weekSummary) {
          buf.writeln(s);
        }
        final avgCal = totalWeekCal ~/ daysWithData;
        buf.writeln(
            '\nWeekly avg ($daysWithData days): $avgCal kcal/day, P:${totalWeekProtein ~/ daysWithData}g C:${totalWeekCarbs ~/ daysWithData}g F:${totalWeekFat ~/ daysWithData}g');
      }

      if (p.weight > 0) {
        final pt = (p.weight * 1.6).round();
        final ft = (goal * 0.25 / 9).round();
        final ct = ((goal - pt * 4 - ft * 9) / 4).round();
        buf.writeln('\nMacro targets: P:${pt}g C:${ct}g F:${ft}g');
      }

      buf.writeln(
          '\nYou are the user\'s PRO Smart Coach. Be direct and action-oriented. Tell them exactly what to eat, not just advice. Reference their weekly patterns. Keep answers focused and under 200 words.\nFormat your responses with markdown: use ## for section headers, **bold** for key numbers and food names, numbered lists for steps, and bullet points for options. This makes responses easy to scan.');
    } else {
      buf.writeln(
          '\nBe concise and practical. Keep responses under 120 words. Use **bold** for key numbers, bullet points for lists. If they ask about detailed analysis, mention Smart Coach Pro gives deeper personalised insights.');
    }

    return buf.toString();
  }

  // ── Macro targets ─────────────────────────────────────────────────────
  _MacroTargets _getTargets(AppState state) {
    final goal = state.calorieGoal;
    final w = state.profile.weight;
    final protein = w > 0 ? (w * 1.6).round() : 120;
    final fat = (goal * 0.25 / 9).round();
    final carbs = ((goal - protein * 4 - fat * 9) / 4).round().clamp(50, 999);
    return _MacroTargets(protein: protein, carbs: carbs, fat: fat);
  }

  // ── Smart Fix (computed locally) ──────────────────────────────────────
  List<_SmartFixItem> _computeSmartFix(AppState state) {
    final targets = _getTargets(state);
    final fixes = <_SmartFixItem>[];

    final proteinGap = targets.protein - state.totalProtein;
    final fatExcess = state.totalFat - targets.fat;
    final carbDiff = state.totalCarbs - targets.carbs;

    if (proteinGap > 10) {
      fixes.add(_SmartFixItem(
        label: '+ Add',
        value: '${proteinGap}g protein',
        color: CLColors.green,
        prompt:
            'I need ${proteinGap}g more protein today. What high-protein foods should I eat with my remaining ${state.caloriesLeft} calories?',
      ));
    }

    if (fatExcess > 10) {
      fixes.add(_SmartFixItem(
        label: '− Reduce',
        value: '${fatExcess}g fat',
        color: CLColors.accent,
        prompt:
            'I\'ve had ${fatExcess}g more fat than ideal today. How should I adjust my remaining meals to balance this out?',
      ));
    } else if (proteinGap <= 10 && state.totalFat < targets.fat - 10) {
      fixes.add(_SmartFixItem(
        label: '+ Add',
        value: '${targets.fat - state.totalFat}g fat',
        color: CLColors.accent,
        prompt:
            'I\'m low on healthy fats today. What should I eat to get more healthy fats with my remaining calories?',
      ));
    }

    if (carbDiff.abs() > 20) {
      fixes.add(_SmartFixItem(
        label: carbDiff > 0 ? 'Balance' : '+ Add',
        value: carbDiff > 0 ? 'Carbs intake' : '${carbDiff.abs()}g carbs',
        color: CLColors.blue,
        prompt: carbDiff > 0
            ? 'I\'ve had more carbs than ideal today. How should I balance my remaining meals?'
            : 'I need ${carbDiff.abs()}g more carbs. What are good carb sources for my remaining calories?',
      ));
    }

    if (fixes.isEmpty) {
      fixes.add(_SmartFixItem(
        label: 'On track',
        value: 'Macros balanced',
        color: CLColors.green,
        prompt: 'My macros look good today. Am I really on track? Any fine-tuning?',
      ));
    }

    return fixes;
  }

  // ── Food emoji mapper ──────────────────────────────────────────────────
  static String _foodEmoji(String name) {
    final n = name.toLowerCase();
    if (n.contains('chicken')) return '🍗';
    if (n.contains('steak') || n.contains('beef')) return '🥩';
    if (n.contains('fish') || n.contains('salmon') || n.contains('tuna')) return '🐟';
    if (n.contains('egg')) return '🍳';
    if (n.contains('salad')) return '🥗';
    if (n.contains('yogurt') || n.contains('yoghurt')) return '🥣';
    if (n.contains('rice')) return '🍚';
    if (n.contains('pasta') || n.contains('noodle')) return '🍝';
    if (n.contains('sandwich') || n.contains('wrap') || n.contains('toast')) return '🥪';
    if (n.contains('soup')) return '🍲';
    if (n.contains('smoothie') || n.contains('shake')) return '🥤';
    if (n.contains('oat') || n.contains('porridge')) return '🥣';
    if (n.contains('fruit') || n.contains('banana') || n.contains('apple')) return '🍎';
    if (n.contains('nut') || n.contains('almond')) return '🥜';
    if (n.contains('bean') || n.contains('lentil')) return '🫘';
    if (n.contains('avocado')) return '🥑';
    if (n.contains('bowl')) return '🥘';
    if (n.contains('burger')) return '🍔';
    if (n.contains('pizza')) return '🍕';
    return '🍽️';
  }

  /// Returns a locale-aware food context hint for the AI prompt.
  static String _countryFoodContext(String code) {
    switch (code) {
      case 'ZA':
        return 'The user is in South Africa. Use locally available ingredients (chicken, boerewors, chakalaka, pap, biltong, butternut, spinach, beans, etc.). ';
      case 'NG':
        return 'The user is in Nigeria. Use locally available ingredients (jollof rice, plantain, beans, yam, egusi, chicken, fish, tomatoes, peppers, garri, etc.). ';
      case 'KE':
        return 'The user is in Kenya. Use locally available ingredients (ugali, sukuma wiki, nyama choma, githeri, chapati, tilapia, kale, beans, etc.). ';
      case 'GH':
        return 'The user is in Ghana. Use locally available ingredients (fufu, banku, groundnut soup, jollof rice, tilapia, plantain, yam, kontomire, etc.). ';
      case 'EG':
        return 'The user is in Egypt. Use locally available ingredients (foul medames, koshari, grilled chicken, rice, lentils, falafel, tahini, etc.). ';
      case 'TZ':
        return 'The user is in Tanzania. Use locally available ingredients (ugali, nyama choma, pilau, ndizi, maharage, dagaa, spinach, etc.). ';
      case 'UG':
        return 'The user is in Uganda. Use locally available ingredients (matoke, groundnut sauce, posho, beans, chicken, cassava, sweet potato, etc.). ';
      case 'IN':
        return 'The user is in India. Use locally available ingredients (dal, paneer, roti, rice, chicken tikka, yogurt, lentils, vegetables, etc.). ';
      case 'GB':
        return 'The user is in the UK. Use locally available ingredients from UK supermarkets. ';
      case 'AU':
      case 'NZ':
        return 'The user is in ${code == "AU" ? "Australia" : "New Zealand"}. Use locally available ingredients. ';
      case 'BR':
        return 'The user is in Brazil. Use locally available ingredients (arroz, feijão, frango, mandioca, ovos, banana, etc.). ';
      case 'MX':
        return 'The user is in Mexico. Use locally available ingredients (frijoles, tortillas, pollo, arroz, aguacate, nopales, etc.). ';
      case 'AE':
      case 'SA':
        return 'The user is in the Middle East. Use locally available ingredients (chicken shawarma, hummus, rice, lentils, lamb, falafel, etc.). ';
      default:
        return 'Use commonly available ingredients. ';
    }
  }

  // ── Generate meal suggestions (Pro) ───────────────────────────────────
  Future<void> _generateSuggestions() async {
    if (_suggestionsLoading) return;
    final state = context.read<AppState>();

    setState(() => _suggestionsLoading = true);

    final remaining = state.calorieGoal - state.totalCalories;
    final hour = DateTime.now().hour;
    final mealTime = hour < 11
        ? 'breakfast'
        : hour < 15
            ? 'lunch'
            : hour < 18
                ? 'afternoon snack'
                : 'dinner';
    final targets = _getTargets(state);
    final proteinGap = targets.protein - state.totalProtein;

    // Variety: tell AI to avoid previously suggested meals
    final excludeStr = _previousSuggestionNames.isNotEmpty
        ? '\nDo NOT suggest these (already suggested): ${_previousSuggestionNames.join(", ")}. Be creative and suggest completely different meals.'
        : '';

    // Random cuisine hint for variety
    const cuisines = ['Mediterranean', 'Asian', 'Mexican', 'Indian', 'American', 'Japanese', 'Middle Eastern', 'African', 'Italian', 'Korean', 'Thai'];
    final rng = Random();
    final cuisineHint = cuisines[rng.nextInt(cuisines.length)];

    // Locale-aware: detect user's country for locally available ingredients
    final pricing = getLocalPricing();
    final countryCode = pricing.countryCode;
    final localeHint = _countryFoodContext(countryCode);

    final prompt =
        'I have $remaining calories left and it\'s $mealTime time. '
        'I need ${proteinGap > 0 ? "$proteinGap more grams of protein" : "to maintain my protein"}. '
        'Consider $cuisineHint-inspired options (but any cuisine is fine). '
        '$localeHint'
        'Give me exactly 2 meal options:\n'
        '1. BEST: a filling, high-quality meal\n'
        '2. ALT: a quick/light alternative\n'
        'Format EXACTLY as (one line per meal):\n'
        'NAME|SHORT_DESCRIPTION|CALORIES|PROTEIN|CARBS|FAT\n'
        'Just the two lines, no numbering, no extra text.$excludeStr';

    try {
      final reply = await state.backend.chat(
        history: [],
        userMessage: prompt,
        systemPrompt: _buildSystemPrompt(state),
      );

      final suggestions = <_MealSuggestion>[];
      final lines = reply.split('\n').where((l) => l.contains('|')).toList();

      for (int i = 0; i < lines.length && i < 2; i++) {
        final parts = lines[i]
            .replaceAll(RegExp(r'^\d+[\.\)]\s*'), '')
            .replaceAll(RegExp(r'^(BEST|ALT|Best|Alt)[:\s]*', caseSensitive: false), '')
            .split('|');
        if (parts.length >= 6) {
          final name = parts[0].trim();
          suggestions.add(_MealSuggestion(
            name: name,
            description: parts[1].trim(),
            calories: int.tryParse(parts[2].trim().replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
            protein: int.tryParse(parts[3].trim().replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
            carbs: int.tryParse(parts[4].trim().replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
            fat: int.tryParse(parts[5].trim().replaceAll(RegExp(r'[^\d]'), '')) ?? 0,
            isBest: i == 0,
          ));
          _previousSuggestionNames.add(name);
        }
      }

      // Keep only the last 10 exclusions to avoid prompt bloat
      if (_previousSuggestionNames.length > 10) {
        _previousSuggestionNames.removeRange(0, _previousSuggestionNames.length - 10);
      }

      if (mounted) {
        setState(() {
          _mealSuggestions = suggestions.isNotEmpty ? suggestions : null;
          _suggestionsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _suggestionsLoading = false);
      }
    }
  }

  // ── Show meal detail (premium bottom sheet) ───────────────────────────
  void _showMealDetail(_MealSuggestion meal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MealDetailSheet(
        meal: meal,
        targets: _getTargets(context.read<AppState>()),
        onSwap: () {
          Navigator.pop(context);
          setState(() => _mealSuggestions = null);
          _generateSuggestions();
        },
        onAskCoach: (prompt) {
          Navigator.pop(context);
          _send(prompt);
        },
      ),
    );
  }

  // ── Send message ──────────────────────────────────────────────────────
  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final state = context.read<AppState>();
    _msgCtrl.clear();
    setState(() {
      _messages.add(
          ChatMessage(role: 'user', content: text, timestamp: DateTime.now()));
      _loading = true;
    });
    _syncChatFlag();
    _scrollToBottom();

    try {
      final reply = await state.backend.chat(
        history: _messages.sublist(0, _messages.length - 1),
        userMessage: text,
        systemPrompt: _buildSystemPrompt(state),
      );
      setState(() {
        _messages.add(ChatMessage(
            role: 'assistant', content: reply, timestamp: DateTime.now()));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          role: 'assistant',
          content: '⚠ Error: ${e.toString().replaceFirst('Exception: ', '')}',
          timestamp: DateTime.now(),
        ));
      });
    } finally {
      setState(() => _loading = false);
      _syncChatFlag();
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    CoachScreen.clearChat = _clearChat;
  }

  @override
  void dispose() {
    CoachScreen.clearChat = null;
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _clearChat() {
    if (_messages.isNotEmpty) {
      setState(() => _messages.clear());
      _syncChatFlag();
    }
  }

  void _syncChatFlag() {
    CoachScreen.hasChatMessages = _messages.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── BUILD ─────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isPro = state.isPremium || state.hasApiKey;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isPro),
            if (_messages.isNotEmpty)
              Expanded(child: _buildMessages())
            else
              Expanded(
                child: isPro
                    ? _buildProDashboard(state)
                    : _buildFreeDashboard(state),
              ),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── HEADER ────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildHeader(bool isPro) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isPro
                    ? [const Color(0xFFD4A840), const Color(0xFFA08030)]
                    : [CLColors.accent, CLColors.accentDim],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.psychology_outlined,
                color: Colors.white, size: 19),
          ),
          const SizedBox(width: 10),
          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Smart Coach',
                    style: TextStyle(
                        color: CLColors.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                Text(
                  isPro
                      ? 'Personalised. Actionable. Built for your goals.'
                      : 'Your AI nutrition assistant',
                  style:
                      const TextStyle(color: CLColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          // Badge
          if (isPro)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFC4A040), Color(0xFFA08030)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.auto_awesome, size: 10, color: Color(0xFF0E0C08)),
                  SizedBox(width: 3),
                  Text('PRO',
                      style: TextStyle(
                          color: Color(0xFF0E0C08),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: CLColors.surface2,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: CLColors.border),
              ),
              child: const Text('FREE',
                  style: TextStyle(
                      color: CLColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8)),
            ),
          // Clear button (when chatting)
          if (_messages.isNotEmpty) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _clearChat,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: CLColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CLColors.border),
                ),
                child: const Text('Clear',
                    style: TextStyle(color: CLColors.muted, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── FREE DASHBOARD ────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFreeDashboard(AppState state) {
    final insight = _getFreeInsight(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 14),
          // ── Today's Insight ──
          _buildFreeInsightCard(insight),
          const SizedBox(height: 20),
          // ── Quick Prompts (vertical) ──
          const Text('Quick prompts',
              style: TextStyle(
                  color: CLColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _buildFreePrompt(Icons.restaurant_outlined, 'What should I eat next?'),
          const SizedBox(height: 8),
          _buildFreePrompt(
              Icons.fitness_center_outlined, 'How much protein should I eat?'),
          const SizedBox(height: 8),
          _buildFreePrompt(
              Icons.pie_chart_outline, 'How can I balance my macros?'),
          const SizedBox(height: 24),
          // ── Smart Suggestions teaser (locked) ──
          _buildSmartSuggestionsTeaser(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _getFreeInsight(AppState state) {
    final prot = state.totalProtein;
    final targets = _getTargets(state);
    final protPct =
        targets.protein > 0 ? (prot / targets.protein * 100).round() : 0;
    final hour = DateTime.now().hour;

    if (hour >= 12 && protPct < 40) {
      return 'You\'re low on protein today.\nTry adding a high-protein meal.';
    }
    if (state.totalCalories > state.calorieGoal) {
      return 'You\'re over your calorie goal.\nFocus on lighter choices.';
    }
    if (state.diary.isEmpty) {
      return 'No meals logged yet.\nStart tracking to get insights.';
    }
    final left = state.calorieGoal - state.totalCalories;
    return 'You have $left kcal remaining.\n${state.diary.length} meal${state.diary.length > 1 ? 's' : ''} logged so far.';
  }

  Widget _buildFreeInsightCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CLColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: CLColors.accentLo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.insights_outlined,
                color: CLColors.accent, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s insight',
                    style: TextStyle(
                        color: CLColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(text,
                    style: const TextStyle(
                        color: CLColors.muted, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: CLColors.muted2, size: 20),
        ],
      ),
    );
  }

  Widget _buildFreePrompt(IconData icon, String text) {
    return GestureDetector(
      onTap: () => _send(text),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: CLColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      color: CLColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartSuggestionsTeaser() {
    return GestureDetector(
      onTap: () => showUpgradeModal(context, source: 'budget_coach'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CLColors.goldLo,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CLColors.gold.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: CLColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: CLColors.gold, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.auto_awesome,
                              size: 14, color: CLColors.gold),
                          const SizedBox(width: 6),
                          const Text('Smart Suggestions',
                              style: TextStyle(
                                  color: CLColors.gold,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: CLColors.gold.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('PRO',
                                style: TextStyle(
                                    color: CLColors.gold,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Get exact meal recommendations\nbased on your calories & goals.',
                        style: TextStyle(
                            color: CLColors.muted,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFFC4A040), Color(0xFFA08030)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text('Unlock Pro',
                      style: TextStyle(
                          color: Color(0xFF0E0C08),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  SizedBox(width: 6),
                  Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFF0E0C08)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── PRO DASHBOARD ─────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildProDashboard(AppState state) {
    final targets = _getTargets(state);
    final fixes = _computeSmartFix(state);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          // 1. Daily Summary — calorie ring + macro bars
          _buildDailySummary(state, targets),
          const SizedBox(height: 16),
          // 2. What should you eat next? (centerpiece)
          _buildWhatToEatCard(state),
          const SizedBox(height: 16),
          // 3. Smart Fix for today
          _buildSmartFixCard(fixes),
          const SizedBox(height: 18),
          // 4. Smart Prompts
          _buildProPrompts(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── 1. Daily Summary ──────────────────────────────────────────────────
  Widget _buildDailySummary(AppState state, _MacroTargets targets) {
    final goal = state.calorieGoal;
    final used = state.totalCalories;
    final remaining = (goal - used).clamp(0, 9999);
    final progress = goal > 0 ? (used / goal).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Row(
        children: [
          // Calorie ring
          SizedBox(
            width: 80,
            height: 80,
            child: CustomPaint(
              painter: _CalorieRingPainter(progress: progress),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$remaining',
                        style: const TextStyle(
                            color: CLColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const Text('kcal left',
                        style:
                            TextStyle(color: CLColors.muted, fontSize: 9)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 18),
          // Macro progress bars
          Expanded(
            child: Column(
              children: [
                _macroBar('Protein', state.totalProtein, targets.protein,
                    CLColors.green),
                const SizedBox(height: 10),
                _macroBar(
                    'Carbs', state.totalCarbs, targets.carbs, CLColors.blue),
                const SizedBox(height: 10),
                _macroBar(
                    'Fat', state.totalFat, targets.fat, CLColors.accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _macroBar(String label, int current, int target, Color color) {
    final pct = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            Text('$current / ${target}g',
                style: const TextStyle(color: CLColors.text, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: color.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. What should you eat next? (CENTERPIECE) ────────────────────────
  Widget _buildWhatToEatCard(AppState state) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CLColors.goldLo,
            CLColors.goldLo.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('What should you eat next?',
                      style: TextStyle(
                          color: CLColors.gold,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
                if (_mealSuggestions == null && !_suggestionsLoading)
                  GestureDetector(
                    onTap: _generateSuggestions,
                    child: const Icon(Icons.chevron_right,
                        color: CLColors.gold, size: 22),
                  ),
                if (_suggestionsLoading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: CLColors.gold),
                  ),
              ],
            ),
          ),

          // Content: either tap-to-generate or suggestions
          if (_mealSuggestions == null && !_suggestionsLoading)
            GestureDetector(
              onTap: _generateSuggestions,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: Text(
                  'Tap to get personalised meal suggestions based on your ${state.caloriesLeft} remaining calories.',
                  style: TextStyle(
                      color: CLColors.gold.withOpacity(0.7),
                      fontSize: 12,
                      height: 1.4),
                ),
              ),
            ),

          if (_suggestionsLoading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Text('Analysing your macros and generating suggestions…',
                  style: TextStyle(
                      color: CLColors.muted, fontSize: 12, height: 1.4)),
            ),

          if (_mealSuggestions != null)
            ..._mealSuggestions!.map((s) => _buildSuggestionRow(s)),

          if (_mealSuggestions != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: GestureDetector(
                onTap: () {
                  setState(() => _mealSuggestions = null);
                  _generateSuggestions();
                },
                child: Text('Tap to refresh',
                    style: TextStyle(
                        color: CLColors.gold.withOpacity(0.5), fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionRow(_MealSuggestion s) {
    final emoji = _foodEmoji(s.name);
    return GestureDetector(
      onTap: () => _showMealDetail(s),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CLColors.surface.withOpacity(0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            // Food emoji visual
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [CLColors.surface2, CLColors.surface3],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CLColors.border),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: s.isBest
                              ? CLColors.green.withOpacity(0.15)
                              : CLColors.blue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          s.isBest ? 'Best option' : 'Alternative',
                          style: TextStyle(
                            color: s.isBest ? CLColors.green : CLColors.blue,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(s.name,
                            style: const TextStyle(
                                color: CLColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text('${s.description} · ${s.calories} kcal',
                      style: const TextStyle(
                          color: CLColors.muted, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('P: ${s.protein}g',
                          style: const TextStyle(
                              color: CLColors.green, fontSize: 10)),
                      const SizedBox(width: 10),
                      Text('C: ${s.carbs}g',
                          style: const TextStyle(
                              color: CLColors.blue, fontSize: 10)),
                      const SizedBox(width: 10),
                      Text('F: ${s.fat}g',
                          style: const TextStyle(
                              color: CLColors.accent, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. Smart Fix ──────────────────────────────────────────────────────
  Widget _buildSmartFixCard(List<_SmartFixItem> fixes) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome, size: 16, color: CLColors.gold),
              SizedBox(width: 8),
              Text('Smart fix for today',
                  style: TextStyle(
                      color: CLColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Spacer(),
              Icon(Icons.chevron_right, size: 18, color: CLColors.muted2),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: fixes.map((f) {
              return Expanded(
                child: GestureDetector(
                  onTap: () => _send(f.prompt),
                  child: Column(
                    children: [
                      Text(f.label,
                          style: TextStyle(
                              color: f.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(f.value,
                          style: const TextStyle(
                              color: CLColors.text, fontSize: 11),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 4. Smart Prompts (Pro) ────────────────────────────────────────────
  Widget _buildProPrompts() {
    const prompts = [
      ('Fix my protein today', Icons.fitness_center_outlined),
      ('Build my next meal', Icons.restaurant_outlined),
      ('Why am I not losing weight?', Icons.help_outline),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('Smart prompts',
                style: TextStyle(
                    color: CLColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            Spacer(),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final p = prompts[i];
              return GestureDetector(
                onTap: () => _send(p.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: CLColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: CLColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(p.$2, size: 14, color: CLColors.accent),
                      const SizedBox(width: 6),
                      Text(p.$1,
                          style: const TextStyle(
                              color: CLColors.text, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── CHAT MESSAGES ─────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildMessages() {
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _messages.length + (_loading ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.role == 'user';

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints:
              BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
          decoration: BoxDecoration(
            color: CLColors.accentLo.withOpacity(0.8),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: CLColors.accent.withOpacity(0.2)),
          ),
          child: Text(
            msg.content,
            style: const TextStyle(
                color: CLColors.accent, fontSize: 14, height: 1.4),
          ),
        ),
      );
    }

    // ── Assistant bubble — rich formatted ──
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coach avatar
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4A840), Color(0xFFA08030)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology_outlined,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          // Message content
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CLColors.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: CLColors.border),
              ),
              child: _RichChatContent(text: msg.content),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFD4A840), Color(0xFFA08030)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.psychology_outlined,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: CLColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: CLColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(150),
                const SizedBox(width: 4),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, v, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: CLColors.muted.withOpacity(0.4 + 0.6 * v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── INPUT ─────────────────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: CLColors.bg,
        border: Border(top: BorderSide(color: CLColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: CLColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask your coach…',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: CLColors.border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: CLColors.border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: CLColors.accent)),
                filled: true,
                fillColor: CLColors.surface,
              ),
              onSubmitted: _send,
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _loading ? null : () => _send(_msgCtrl.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _loading ? CLColors.muted2 : CLColors.accent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded,
                      color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── RICH CHAT CONTENT (markdown-lite renderer) ──────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _RichChatContent extends StatelessWidget {
  final String text;
  const _RichChatContent({required this.text});

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final widgets = <Widget>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i].trim();

      // Skip empty lines (but add small spacing)
      if (line.isEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 6));
        }
        i++;
        continue;
      }

      // ── H1: # Header ──
      if (line.startsWith('# ')) {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isNotEmpty ? 10 : 0, bottom: 4),
          child: Text(
            line.substring(2),
            style: const TextStyle(
              color: CLColors.text,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ));
        i++;
        continue;
      }

      // ── H2: ## Subheader ──
      if (line.startsWith('## ')) {
        widgets.add(Padding(
          padding: EdgeInsets.only(top: widgets.isNotEmpty ? 8 : 0, bottom: 3),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: CLColors.accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Text(
                  line.substring(3),
                  style: const TextStyle(
                    color: CLColors.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ));
        i++;
        continue;
      }

      // ── Numbered list: 1. step ──
      if (RegExp(r'^\d+[\.\)]\s').hasMatch(line)) {
        final numMatch = RegExp(r'^(\d+)[\.\)]\s(.*)').firstMatch(line);
        if (numMatch != null) {
          widgets.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 8, top: 1),
                  decoration: BoxDecoration(
                    color: CLColors.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      numMatch.group(1)!,
                      style: const TextStyle(
                        color: CLColors.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildRichLine(numMatch.group(2)!),
                ),
              ],
            ),
          ));
          i++;
          continue;
        }
      }

      // ── Bullet: - item or • item ──
      if (line.startsWith('- ') || line.startsWith('• ') || line.startsWith('* ')) {
        final content = line.substring(2);
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 5,
                height: 5,
                margin: const EdgeInsets.only(right: 10, top: 7, left: 4),
                decoration: BoxDecoration(
                  color: CLColors.accent.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: _buildRichLine(content)),
            ],
          ),
        ));
        i++;
        continue;
      }

      // ── Separator: --- ──
      if (line == '---' || line == '***') {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Container(height: 1, color: CLColors.border),
        ));
        i++;
        continue;
      }

      // ── Regular paragraph ──
      widgets.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: _buildRichLine(line),
      ));
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  /// Renders inline bold (**text**) and keeps normal text
  static Widget _buildRichLine(String line) {
    final spans = <TextSpan>[];
    final parts = line.split('**');

    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          color: i % 2 == 1 ? CLColors.text : CLColors.text.withOpacity(0.85),
          fontWeight: i % 2 == 1 ? FontWeight.w600 : FontWeight.normal,
          fontSize: 13,
          height: 1.5,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── MEAL DETAIL SHEET ───────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _MealDetailSheet extends StatefulWidget {
  final _MealSuggestion meal;
  final _MacroTargets targets;
  final VoidCallback onSwap;
  final void Function(String prompt) onAskCoach;

  const _MealDetailSheet({
    required this.meal,
    required this.targets,
    required this.onSwap,
    required this.onAskCoach,
  });

  @override
  State<_MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends State<_MealDetailSheet> {
  bool _ingredientsOpen = false;
  bool _prepOpen = false;
  bool _nutritionOpen = false;
  bool _detailLoading = false;
  String? _ingredients;
  String? _prepSteps;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _detailLoading = true);
    try {
      final state = context.read<AppState>();
      final prompt =
          'For the meal "${widget.meal.name}" (${widget.meal.calories} kcal, '
          'P:${widget.meal.protein}g C:${widget.meal.carbs}g F:${widget.meal.fat}g):\n'
          'Give me:\n'
          'INGREDIENTS:\n- list each ingredient with amount\n'
          'PREP:\n- numbered steps, keep each step to one sentence\n'
          'Just the ingredients and prep, nothing else.';

      final reply = await state.backend.chat(
        history: [],
        userMessage: prompt,
        systemPrompt:
            'You are a concise recipe assistant. Give clear, practical instructions. No intro text.',
      );

      if (!mounted) return;

      // Parse ingredients and prep from response
      String ingredients = '';
      String prep = '';
      final lower = reply.toLowerCase();
      final ingIdx = lower.indexOf('ingredient');
      final prepIdx = lower.indexOf('prep');

      if (ingIdx >= 0 && prepIdx > ingIdx) {
        ingredients = reply.substring(ingIdx, prepIdx).trim();
        // Remove the header line
        ingredients = ingredients
            .split('\n')
            .skip(1)
            .where((l) => l.trim().isNotEmpty)
            .join('\n');
        prep = reply
            .substring(prepIdx)
            .split('\n')
            .skip(1)
            .where((l) => l.trim().isNotEmpty)
            .join('\n');
      } else {
        // Fallback: split in half
        final lines = reply.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final mid = lines.length ~/ 2;
        ingredients = lines.take(mid).join('\n');
        prep = lines.skip(mid).join('\n');
      }

      setState(() {
        _ingredients = ingredients.isNotEmpty ? ingredients : 'Tap to load';
        _prepSteps = prep.isNotEmpty ? prep : 'Tap to load';
        _detailLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _ingredients = 'Could not load — try again';
          _prepSteps = 'Could not load — try again';
          _detailLoading = false;
        });
      }
    }
  }

  List<String> _getWhyGood() {
    final reasons = <String>[];
    final m = widget.meal;
    final t = widget.targets;

    if (m.protein >= 20) reasons.add('Helps you hit your protein target');
    if (m.calories <= 700) reasons.add('Keeps calories controlled');
    if (m.fat <= t.fat * 0.4) {
      reasons.add('Low in fat');
    }
    if (reasons.isEmpty || reasons.length < 3) {
      reasons.add('Ideal for your current goal');
    }
    return reasons.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    final emoji = _CoachScreenState._foodEmoji(m.name);
    final reasons = _getWhyGood();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: CLColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Hero: emoji + name + calories ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CLColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CLColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A1810), Color(0xFF252218)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: CLColors.border),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 32)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.name,
                                style: const TextStyle(
                                    color: CLColors.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    height: 1.2),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text('${m.calories}',
                                    style: const TextStyle(
                                        color: CLColors.accent,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(width: 4),
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Text('kcal per serving',
                                      style: TextStyle(
                                          color: CLColors.muted, fontSize: 11)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (m.isBest) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: CLColors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: CLColors.green.withOpacity(0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.check_circle,
                              size: 14, color: CLColors.green),
                          SizedBox(width: 6),
                          Text('Best match for your goal',
                              style: TextStyle(
                                  color: CLColors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Macro breakdown row ──
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: CLColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CLColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _macroColumn('P', '${m.protein}g', 'Protein', CLColors.green),
                  Container(width: 1, height: 30, color: CLColors.border),
                  _macroColumn('C', '${m.carbs}g', 'Carbs', CLColors.blue),
                  Container(width: 1, height: 30, color: CLColors.border),
                  _macroColumn('F', '${m.fat}g', 'Fat', CLColors.accent),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Why this is good for you ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CLColors.greenLo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CLColors.green.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.lightbulb_outline,
                          size: 14, color: CLColors.green),
                      SizedBox(width: 6),
                      Text('Why this is good for you',
                          style: TextStyle(
                              color: CLColors.green,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: reasons.map((r) {
                      return Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 12, color: CLColors.green),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(r,
                                  style: const TextStyle(
                                      color: CLColors.muted,
                                      fontSize: 10,
                                      height: 1.3)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Expandable: Ingredients ──
            _buildExpandableSection(
              icon: Icons.shopping_cart_outlined,
              title: 'Ingredients (1 serving)',
              isOpen: _ingredientsOpen,
              onTap: () =>
                  setState(() => _ingredientsOpen = !_ingredientsOpen),
              content: _detailLoading
                  ? 'Loading...'
                  : (_ingredients ?? 'Tap to load'),
            ),

            const SizedBox(height: 8),

            // ── Expandable: Prep ──
            _buildExpandableSection(
              icon: Icons.menu_book_outlined,
              title: 'Quick Prep Instructions',
              isOpen: _prepOpen,
              onTap: () => setState(() => _prepOpen = !_prepOpen),
              content:
                  _detailLoading ? 'Loading...' : (_prepSteps ?? 'Tap to load'),
            ),

            const SizedBox(height: 8),

            // ── Expandable: Nutrition ──
            _buildExpandableSection(
              icon: Icons.pie_chart_outline,
              title: 'Nutrition Breakdown',
              isOpen: _nutritionOpen,
              onTap: () =>
                  setState(() => _nutritionOpen = !_nutritionOpen),
              content:
                  'Calories: ${m.calories} kcal\nProtein: ${m.protein}g\nCarbs: ${m.carbs}g\nFat: ${m.fat}g',
            ),

            const SizedBox(height: 16),

            // ── Action buttons ──
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    icon: Icons.refresh,
                    label: 'Swap meal',
                    color: CLColors.accent,
                    onTap: widget.onSwap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton(
                    icon: Icons.bookmark_outline,
                    label: 'Save meal',
                    color: CLColors.gold,
                    onTap: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${m.name} saved!'),
                          backgroundColor: CLColors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── What next? ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CLColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CLColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, size: 14, color: CLColors.gold),
                      SizedBox(width: 6),
                      Text('What would you like to do next?',
                          style: TextStyle(
                              color: CLColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _nextActionChip(
                        '⚡',
                        'Faster option',
                        'Suggest a faster/easier version of "${m.name}" with similar macros',
                      ),
                      _nextActionChip(
                        '💰',
                        'Cheaper alternative',
                        'Suggest a more budget-friendly alternative to "${m.name}" with similar nutrition',
                      ),
                      _nextActionChip(
                        '↓',
                        'Lower calories (${(m.calories * 0.7).round()} kcal)',
                        'Suggest a lower-calorie version of "${m.name}", around ${(m.calories * 0.7).round()} kcal',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macroColumn(
      String letter, String value, String label, Color color) {
    return Column(
      children: [
        RichText(
          text: TextSpan(children: [
            TextSpan(
                text: '$letter ',
                style: TextStyle(
                    color: color, fontSize: 13, fontWeight: FontWeight.w700)),
            TextSpan(
                text: value,
                style: const TextStyle(
                    color: CLColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: CLColors.muted, fontSize: 10)),
      ],
    );
  }

  Widget _buildExpandableSection({
    required IconData icon,
    required String title,
    required bool isOpen,
    required VoidCallback onTap,
    required String content,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CLColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CLColors.border),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: CLColors.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: CLColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ),
                Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  size: 20,
                  color: CLColors.muted,
                ),
              ],
            ),
            if (isOpen) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: CLColors.border),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Text(content,
                    style: const TextStyle(
                        color: CLColors.muted,
                        fontSize: 12,
                        height: 1.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _nextActionChip(String emoji, String label, String prompt) {
    return GestureDetector(
      onTap: () => widget.onAskCoach(prompt),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: CLColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: CLColors.text, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ── PAINTERS & DATA CLASSES ─────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════════════

class _CalorieRingPainter extends CustomPainter {
  final double progress;
  _CalorieRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 5;
    const stroke = 7.0;

    canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = CLColors.surface2
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);

    final color = progress >= 1.0
        ? CLColors.gold
        : progress >= 0.7
            ? CLColors.green
            : CLColors.accent;

    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_CalorieRingPainter old) => old.progress != progress;
}

class _MacroTargets {
  final int protein, carbs, fat;
  const _MacroTargets(
      {required this.protein, required this.carbs, required this.fat});
}

class _MealSuggestion {
  final String name, description;
  final int calories, protein, carbs, fat;
  final bool isBest;
  const _MealSuggestion({
    required this.name,
    required this.description,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.isBest,
  });
}

class _SmartFixItem {
  final String label, value, prompt;
  final Color color;
  const _SmartFixItem({
    required this.label,
    required this.value,
    required this.prompt,
    required this.color,
  });
}
