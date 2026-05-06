import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../screens/auth/login_screen.dart';
import '../theme.dart';
import '../utils/pricing.dart';

/// Call this from anywhere to show the Pro upgrade sheet.
/// [source] controls the contextual message shown:
///   'scan_limit' | 'week_report' | 'budget_coach' | 'settings'
///
/// If the user is a guest (not signed in, no API key), they are redirected
/// to the login screen instead — Pro requires an account.
void showUpgradeModal(BuildContext context, {String source = 'generic'}) {
  final state = context.read<AppState>();
  final isGuest = !state.isSignedIn && !state.hasApiKey;

  if (isGuest) {
    // Capture navigator before showing dialog so it stays valid
    final navigator = Navigator.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: CLColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.lock_outline, color: CLColors.gold, size: 22),
            const SizedBox(width: 10),
            const Text('Account Required',
                style: TextStyle(color: CLColors.text, fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
        content: const Text(
          'You need a free account before you can upgrade to Pro. It only takes a minute!',
          style: TextStyle(color: CLColors.muted, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Not now', style: TextStyle(color: CLColors.muted, fontSize: 14)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogCtx);
              navigator.push(MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CLColors.gold,
              foregroundColor: const Color(0xFF0E0C08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Sign in / Sign up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => UpgradeModal(source: source),
  );
}

class UpgradeModal extends StatelessWidget {
  final String source;
  const UpgradeModal({super.key, required this.source});

  // Detect local pricing once per modal build
  PricingInfo get _pricing => getLocalPricing();

  String get _contextMessage {
    switch (source) {
      case 'scan_limit':
        return "You've used all 5 free scans for today. Upgrade to Pro for up to 50 scans/day — never miss logging a meal.";
      case 'week_report':
        return "The Weekly Progress Report is a Pro feature. Unlock your full 7-day analysis with trends and AI insights.";
      case 'budget_coach':
        return "The AI Smart Coach is a Pro feature. Get personalised meal suggestions, weekly insights, and smarter prompts.";
      case 'generate_plan':
        return "AI Meal Plan Generation is a Pro feature. Get personalised meal plans tailored to your calorie goal, budget, and dietary preferences.";
      case 'fridge_scan':
        return "Fridge Scanner is a Pro feature. Snap a photo of your fridge and AI will identify your ingredients and suggest meal plans.";
      case 'history':
        return "Free accounts keep 7 days of meal history. Upgrade to Pro for unlimited history — never lose your progress.";
      default:
        return "Upgrade to Pro to remove all limits and unlock the complete CalorieLens experience.";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131210),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0x40C4A040))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: CLColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          // Logo + PRO chip
          Row(
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: CLColors.text),
                  children: [
                    TextSpan(text: 'Calorie'),
                    TextSpan(text: 'Lens', style: TextStyle(color: CLColors.accent, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFC4A040), Color(0xFFA08030)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('PRO', style: TextStyle(color: Color(0xFF0E0C08), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Headline
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Unlock Your Full\nPotential',
              style: TextStyle(color: CLColors.text, fontSize: 26, fontWeight: FontWeight.w700, height: 1.1),
            ),
          ),
          const SizedBox(height: 12),
          // Context message
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CLColors.goldLo,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CLColors.gold.withOpacity(0.25)),
            ),
            child: Text(_contextMessage,
                style: const TextStyle(color: CLColors.gold, fontSize: 13, height: 1.45)),
          ),
          const SizedBox(height: 16),
          // Feature list
          ..._features.map((f) => _FeatureRow(text: f)),
          const SizedBox(height: 20),
          // Price — locale-aware
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _pricing.fullPrice.replaceAll('/month', ''),
                    style: const TextStyle(
                      color: CLColors.text,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6, left: 4),
                    child: Text('/month',
                        style: TextStyle(color: CLColors.muted, fontSize: 14)),
                  ),
                ],
              ),
              Text(
                '${_pricing.currency} · Cancel anytime · 7-day free trial',
                style: const TextStyle(color: CLColors.muted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // CTA — only signed-in users reach this modal (guests are
          // redirected to LoginScreen by showUpgradeModal before it opens)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.read<AppState>().activatePremium();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('⭐  Pro activated! Enjoy unlimited access.'),
                    backgroundColor: CLColors.gold,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: CLColors.gold,
                foregroundColor: const Color(0xFF0E0C08),
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
              child: const Text('START 7-DAY FREE TRIAL  →'),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe later', style: TextStyle(color: CLColors.muted, fontSize: 13)),
          ),
        ],
      ),
      ),
    );
  }

  static const _features = [
    'Up to 50 meal scans per day',
    'AI-generated personalised meal plans',
    'Fridge Scanner — snap & get recipe ideas',
    'AI Smart Coach — personalised meal advice',
    'Weekly Progress Report — full 7-day analysis',
    'Unlimited Smart Coach with full history',
    'No ads',
  ];
}

class _FeatureRow extends StatelessWidget {
  final String text;
  const _FeatureRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
              color: CLColors.goldLo,
              shape: BoxShape.circle,
              border: Border.all(color: CLColors.gold.withOpacity(0.4)),
            ),
            child: const Center(
              child: Text('✓', style: TextStyle(color: CLColors.gold, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFFC8BFB0), fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }
}
