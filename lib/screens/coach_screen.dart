import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models/models.dart';
import '../services/anthropic_service.dart';
import '../theme.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _loading = false;

  static const _quickPrompts = [
    'How am I doing today?',
    'What should I eat next?',
    'Am I hitting my macros?',
    'Give me a healthy snack idea',
    'Review my week',
    'How much protein should I eat?',
  ];

  String _buildSystemPrompt(AppState state) {
    final diary = state.diary;
    final goal  = state.calorieGoal;
    final used  = state.totalCalories;
    final name  = state.profile.name;
    final p     = state.profile;

    final diaryStr = diary.isEmpty
        ? 'No meals logged yet today.'
        : diary.map((e) => '${e.time} ${e.name}: ${e.calories} Cal (P:${e.protein}g C:${e.carbs}g F:${e.fat}g)').join('\n');

    return '''You are CalorieLens AI — a friendly, expert nutrition and fitness coach.
${name.isNotEmpty ? 'User\'s name: $name.' : ''}
${p.weight > 0 ? 'Weight: ${p.weight}kg, Height: ${p.height}cm, Age: ${p.age}' : ''}

TODAY'S DATA:
Calorie goal: $goal kcal
Consumed: $used kcal | Remaining: ${(goal - used)} kcal
Protein: ${state.totalProtein}g | Carbs: ${state.totalCarbs}g | Fat: ${state.totalFat}g
Water: ${state.water}/8 glasses

TODAY'S MEALS:
$diaryStr

Be concise, warm, and practical. Use specific numbers from their data. Keep responses under 200 words unless asked for more detail.''';
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your Anthropic API key in Settings to use the AI coach.'),
          backgroundColor: CLColors.accentDim,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _msgCtrl.clear();
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text, timestamp: DateTime.now()));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final svc = AnthropicService(state.apiKey);
      final reply = await svc.chat(
        history: _messages.sublist(0, _messages.length - 1),
        userMessage: text,
        systemPrompt: _buildSystemPrompt(state),
      );
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', content: reply, timestamp: DateTime.now()));
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
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Text('AI Coach', style: TextStyle(color: CLColors.text, fontSize: 22, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  if (_messages.isNotEmpty)
                    GestureDetector(
                      onTap: () => setState(() => _messages.clear()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: CLColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CLColors.border),
                        ),
                        child: const Text('Clear', style: TextStyle(color: CLColors.muted, fontSize: 12)),
                      ),
                    ),
                ],
              ),
            ),
            // Messages
            Expanded(
              child: _messages.isEmpty ? _buildEmptyState() : _buildMessages(),
            ),
            // Quick prompts
            if (_messages.isEmpty) _buildQuickPrompts(),
            // Input
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
              color: CLColors.accentLo,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CLColors.accent.withOpacity(0.3)),
            ),
            child: const Icon(Icons.smart_toy_outlined, color: CLColors.accent, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Your AI Nutrition Coach', style: TextStyle(color: CLColors.text, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('Ask anything about your nutrition,\ncalories, or fitness goals', style: TextStyle(color: CLColors.muted, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
        ],
      ),
    );
  }

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
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isUser ? CLColors.accentLo.withOpacity(0.8) : CLColors.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser ? CLColors.accent.withOpacity(0.2) : CLColors.border,
          ),
        ),
        child: Text(
          msg.content,
          style: TextStyle(color: isUser ? CLColors.accent : CLColors.text, fontSize: 14, height: 1.4),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CLColors.surface2,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16), topRight: Radius.circular(16), bottomRight: Radius.circular(16), bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(0), const SizedBox(width: 4), _dot(150), const SizedBox(width: 4), _dot(300),
          ],
        ),
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      builder: (_, v, __) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: CLColors.muted.withOpacity(0.4 + 0.6 * v),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickPrompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _send(_quickPrompts[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: CLColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: CLColors.border),
            ),
            child: Text(_quickPrompts[i], style: const TextStyle(color: CLColors.text, fontSize: 12)),
          ),
        ),
      ),
    );
  }

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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: CLColors.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: CLColors.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: CLColors.accent)),
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
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _loading ? CLColors.muted2 : CLColors.accent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: _loading
                  ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.black, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
