import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../theme.dart';
import '../utils/pricing.dart';
import '../widgets/upgrade_modal.dart';
import 'auth/login_screen.dart';
import 'workout_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl    = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _ageCtrl    = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  bool _keyVisible  = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _keyCtrl.text    = state.apiKey;
    _nameCtrl.text   = state.profile.name;
    _ageCtrl.text    = state.profile.age > 0 ? '${state.profile.age}' : '';
    _weightCtrl.text = state.profile.weight > 0 ? '${state.profile.weight}' : '';
    _heightCtrl.text = state.profile.height > 0 ? '${state.profile.height}' : '';
  }

  @override
  void dispose() {
    _keyCtrl.dispose(); _nameCtrl.dispose(); _ageCtrl.dispose();
    _weightCtrl.dispose(); _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAccountSection(context, state),
            const SizedBox(height: 20),
            _buildPremiumCard(context, state),
            const SizedBox(height: 20),
            _buildApiKeySection(context, state),
            const SizedBox(height: 20),
            _buildProfileSection(context, state),
            const SizedBox(height: 20),
            _buildFitnessSection(context),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection(BuildContext context, AppState state) {
    final isSignedIn = state.isSignedIn;
    final user = state.supabaseUser;
    final scansLeft = state.scansRemainingToday;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSignedIn ? Icons.cloud_done_outlined : Icons.person_outline,
                color: isSignedIn ? CLColors.green : CLColors.muted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSignedIn ? 'Signed in' : 'Guest mode',
                      style: const TextStyle(color: CLColors.text, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      isSignedIn
                          ? (user?.email ?? 'Account synced')
                          : 'Sign in for cloud sync & more free scans',
                      style: const TextStyle(color: CLColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isSignedIn) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _usagePill(
                  icon: Icons.camera_alt_outlined,
                  label: state.isPremium || state.hasApiKey
                      ? 'Unlimited scans'
                      : '$scansLeft scans left today',
                  color: scansLeft > 3 || state.isPremium || state.hasApiKey
                      ? CLColors.green
                      : CLColors.gold,
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          if (!isSignedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text('SIGN IN / CREATE ACCOUNT'),
              ),
            )
          else
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: CLColors.surface,
                    title: const Text('Sign out?', style: TextStyle(color: CLColors.text)),
                    content: const Text('Your data stays saved on this device.',
                        style: TextStyle(color: CLColors.muted)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: CLColors.red),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (ok == true && mounted) {
                  await AuthService.signOut();
                  await context.read<AppState>().signOut();
                }
              },
              style: TextButton.styleFrom(foregroundColor: CLColors.red),
              child: const Text('Sign out'),
            ),
        ],
      ),
    );
  }

  Widget _usagePill({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildPremiumCard(BuildContext context, AppState state) {
    final isPro = state.isPremium;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? [const Color(0xFF1A1508), const Color(0xFF0E0C06)]
              : [CLColors.surface, CLColors.surface2],
          begin: Alignment.topLeft,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPro ? CLColors.gold.withOpacity(0.4) : CLColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(isPro ? '⭐' : '🔓', style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPro ? 'CalorieLens Pro' : 'CalorieLens Free',
                      style: const TextStyle(color: CLColors.text, fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      isPro ? 'All features unlocked' : '3 scans/day · limited features',
                      style: const TextStyle(color: CLColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPro ? CLColors.goldLo : CLColors.surface2,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isPro ? CLColors.gold.withOpacity(0.5) : CLColors.border),
                ),
                child: Text(
                  isPro ? 'ACTIVE' : 'FREE',
                  style: TextStyle(
                    color: isPro ? CLColors.gold : CLColors.muted,
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ..._featureRow('Unlimited meal scans', isPro),
          ..._featureRow('AI Budget Coach', isPro),
          ..._featureRow('Weekly Progress Report', isPro),
          ..._featureRow('Unlimited AI Coach history', isPro),
          const SizedBox(height: 14),
          if (!isPro)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => showUpgradeModal(context, source: 'settings'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: CLColors.gold,
                  foregroundColor: const Color(0xFF0E0C06),
                ),
                child: Text('UPGRADE TO PRO — ${getLocalPricing().fullPrice.toUpperCase()}'),
              ),
            )
          else
            TextButton(
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: CLColors.surface,
                    title: const Text('Cancel Pro?', style: TextStyle(color: CLColors.text)),
                    content: const Text('You will return to the free tier with 3 scans/day.', style: TextStyle(color: CLColors.muted)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Pro')),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: CLColors.red),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
                if (ok == true && mounted) {
                  await context.read<AppState>().cancelPremium();
                }
              },
              style: TextButton.styleFrom(foregroundColor: CLColors.red),
              child: const Text('Cancel Pro subscription'),
            ),
        ],
      ),
    );
  }

  Iterable<Widget> _featureRow(String label, bool unlocked) sync* {
    yield Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.check_circle : Icons.lock_outline,
            color: unlocked ? CLColors.green : CLColors.muted2,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: unlocked ? CLColors.text : CLColors.muted2,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeySection(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('🔑  API Key (Optional — Power Users)', style: TextStyle(color: CLColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Leave blank to use the built-in backend (10 free scans/day). Add your own Anthropic key for unlimited, direct access at your cost.',
            style: TextStyle(color: CLColors.muted, fontSize: 11, height: 1.4)),
        const SizedBox(height: 12),
        TextField(
          controller: _keyCtrl,
          obscureText: !_keyVisible,
          style: const TextStyle(color: CLColors.text, fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'sk-ant-api03-…',
            suffixIcon: IconButton(
              icon: Icon(_keyVisible ? Icons.visibility_off : Icons.visibility, color: CLColors.muted, size: 18),
              onPressed: () => setState(() => _keyVisible = !_keyVisible),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () async {
                  await context.read<AppState>().saveApiKey(_keyCtrl.text.trim());
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API key saved'), behavior: SnackBarBehavior.floating),
                    );
                  }
                },
                child: const Text('SAVE KEY'),
              ),
            ),
            if (state.hasApiKey) ...[
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  _keyCtrl.clear();
                  await context.read<AppState>().saveApiKey('');
                },
                style: TextButton.styleFrom(foregroundColor: CLColors.red),
                child: const Text('Remove'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        const Text('💡 BYOK: ~\$0.001 per scan/message (Claude Haiku). Get a key at console.anthropic.com',
            style: TextStyle(color: CLColors.muted, fontSize: 11, height: 1.4)),
      ],
    );
  }

  Widget _buildFitnessSection(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WorkoutScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CLColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CLColors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: CLColors.blue.withOpacity(0.25)),
              ),
              child: const Center(
                child: Text('💪', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Workout Library',
                      style: TextStyle(
                          color: CLColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text('Browse exercises and start a workout',
                      style: TextStyle(color: CLColors.muted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: CLColors.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('👤  Your Profile', style: TextStyle(color: CLColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text('Used to calculate your personalised calorie target.',
            style: TextStyle(color: CLColors.muted, fontSize: 11)),
        const SizedBox(height: 12),
        TextField(controller: _nameCtrl, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Name (optional)')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(controller: _ageCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Age', suffixText: 'yrs'))),
          const SizedBox(width: 10),
          Expanded(child: TextField(controller: _weightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Weight', suffixText: 'kg'))),
        ]),
        const SizedBox(height: 10),
        TextField(controller: _heightCtrl, keyboardType: TextInputType.number, style: const TextStyle(color: CLColors.text), decoration: const InputDecoration(hintText: 'Height', suffixText: 'cm')),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              final p = state.profile.copyWith(
                name: _nameCtrl.text.trim(),
                age: int.tryParse(_ageCtrl.text) ?? 0,
                weight: double.tryParse(_weightCtrl.text) ?? 0,
                height: int.tryParse(_heightCtrl.text) ?? 0,
              );
              // Auto-calculate calorie goal
              if (p.age > 0 && p.weight > 0 && p.height > 0) {
                final bmr = p.sex == 'm'
                    ? 10 * p.weight + 6.25 * p.height - 5 * p.age + 5
                    : 10 * p.weight + 6.25 * p.height - 5 * p.age - 161;
                final tdee = (bmr * p.activity).round();
                await context.read<AppState>().saveCalorieGoal(tdee);
              }
              await context.read<AppState>().saveProfile(p);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile saved'), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: const Text('SAVE PROFILE'),
          ),
        ),
      ],
    );
  }
}
