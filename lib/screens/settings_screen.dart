import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../utils/pricing.dart';
import '../widgets/upgrade_modal.dart';
import 'auth/login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Notification state
  bool _remindersOn = false;
  bool _nudgesOn = false;
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 18, minute: 30);

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final remOn = await NotificationService.remindersEnabled;
    final nudOn = await NotificationService.nudgesEnabled;
    final bTime = await NotificationService.getReminderTime('breakfast');
    final lTime = await NotificationService.getReminderTime('lunch');
    final dTime = await NotificationService.getReminderTime('dinner');
    if (mounted) {
      setState(() {
        _remindersOn = remOn;
        _nudgesOn = nudOn;
        _breakfastTime = bTime;
        _lunchTime = lTime;
        _dinnerTime = dTime;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      backgroundColor: CLColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Large header ──────────────────────────────────
              const Text('Settings',
                  style: TextStyle(
                      color: CLColors.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),

              // ── ACCOUNT ──────────────────────────────────────
              _sectionLabel('ACCOUNT'),
              const SizedBox(height: 8),
              _buildAccountSection(state),
              const SizedBox(height: 24),

              // ── SUBSCRIPTION ─────────────────────────────────
              _sectionLabel('SUBSCRIPTION'),
              const SizedBox(height: 8),
              _buildSubscriptionSection(state),
              const SizedBox(height: 24),

              // ── PREFERENCES ──────────────────────────────────
              _sectionLabel('PREFERENCES'),
              const SizedBox(height: 8),
              _buildPreferencesSection(),
              const SizedBox(height: 24),

              // ── PROFILE ──────────────────────────────────────
              _sectionLabel('PROFILE'),
              const SizedBox(height: 8),
              _buildProfileRow(state),
              const SizedBox(height: 24),

              // ── ABOUT ────────────────────────────────────────
              _sectionLabel('ABOUT'),
              const SizedBox(height: 8),
              _buildAboutSection(),

              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── Section label ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text,
          style: const TextStyle(
              color: CLColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2)),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── ACCOUNT SECTION ────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildAccountSection(AppState state) {
    final isRealUser = state.isRealUser; // excludes anonymous guests
    final user = state.supabaseUser;
    final scansLeft = state.scansRemainingToday;

    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // User info row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: CLColors.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: CLColors.accent.withOpacity(0.3), width: 1.5),
                  ),
                  child: Icon(Icons.person,
                      color: CLColors.accent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRealUser
                            ? (state.profile.name.isNotEmpty
                                ? state.profile.name
                                : 'User')
                            : 'Guest',
                        style: const TextStyle(
                            color: CLColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRealUser
                            ? (user?.email ?? 'Signed in')
                            : 'Sign in for cloud sync & more scans',
                        style: const TextStyle(
                            color: CLColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isRealUser)
                  const Icon(Icons.chevron_right,
                      color: CLColors.muted, size: 20),
              ],
            ),
          ),

          // Scans left row
          if (state.isSignedIn) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CLColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: CLColors.muted, size: 16),
                  ),
                  const SizedBox(width: 10),
                  const Text('Scans left',
                      style: TextStyle(
                          color: CLColors.muted, fontSize: 13)),
                  const Spacer(),
                  Text(
                    state.hasApiKey
                        ? 'Unlimited'
                        : state.isPremium
                            ? '$scansLeft of 50'
                            : state.isAnonymous
                                ? '$scansLeft of 3'
                                : '$scansLeft of 5',
                    style: TextStyle(
                      color: (scansLeft > 3 || state.isPremium || state.hasApiKey)
                          ? CLColors.green
                          : CLColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          const Divider(color: CLColors.border, height: 1),

          // Sign in / Sign out row
          if (!isRealUser)
            _tappableRow(
              icon: Icons.login,
              label: 'Sign in / Create account',
              labelColor: CLColors.accent,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
            )
          else
            _tappableRow(
              icon: Icons.logout,
              label: 'Sign out',
              labelColor: CLColors.accent,
              onTap: () => _handleSignOut(state),
            ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(AppState state) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: CLColors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign out?',
            style: TextStyle(color: CLColors.text)),
        content: const Text(
            'Your data stays saved on this device.',
            style: TextStyle(color: CLColors.muted)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
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
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── SUBSCRIPTION SECTION ───────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSubscriptionSection(AppState state) {
    final isPro = state.isPremium || state.hasApiKey;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? [const Color(0xFF1A1508), const Color(0xFF0E0C06)]
              : [CLColors.surface, CLColors.surface],
          begin: Alignment.topLeft,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPro
              ? CLColors.gold.withOpacity(0.35)
              : CLColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row: crown + title + badge
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: GestureDetector(
              onTap: isPro ? null : () => showUpgradeModal(context, source: 'settings'),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isPro
                          ? CLColors.goldLo
                          : CLColors.surface2,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isPro
                          ? Icons.workspace_premium
                          : Icons.lock_outline,
                      color: isPro ? CLColors.gold : CLColors.muted,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isPro ? 'CalorieLens Pro' : 'CalorieLens Free',
                          style: const TextStyle(
                              color: CLColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPro
                              ? "You're enjoying all Pro features"
                              : '${AppState.freeScanLimit} scans/day · limited features',
                          style: const TextStyle(
                              color: CLColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isPro
                          ? CLColors.green.withOpacity(0.15)
                          : CLColors.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isPro ? 'ACTIVE' : 'FREE',
                      style: TextStyle(
                        color: isPro ? CLColors.green : CLColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right,
                      color: CLColors.muted, size: 18),
                ],
              ),
            ),
          ),

          // Feature details — detailed for Pro, icon row for Free
          if (isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: [
                  _proFeatureRow(Icons.camera_alt_outlined, '${AppState.proScanLimit} AI scans per day',
                    '${state.scansRemainingToday} remaining today'),
                  _proFeatureRow(Icons.bar_chart, 'Weekly progress reports',
                    'Detailed nutrition scoring'),
                  _proFeatureRow(Icons.psychology, 'Smart Coach with meal history',
                    'Uses your 7-day patterns'),
                  _proFeatureRow(Icons.restaurant_menu, 'Personalised meal plans',
                    'AI recommendations & fridge scanner'),
                  _proFeatureRow(Icons.block, 'Ad-free experience',
                    'No interruptions'),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              child: Row(
                children: [
                  _featureIcon(Icons.camera_alt_outlined, '${AppState.freeScanLimit} scans\nper day', false),
                  _featureIcon(Icons.restaurant_menu, 'Basic\nlogging', false),
                  _featureIcon(Icons.chat_outlined, 'Limited\ncoach', false),
                  _featureIcon(Icons.history, '7 day\nhistory', false),
                  _featureIcon(Icons.auto_awesome, 'Upgrade\nfor more', false),
                ],
              ),
            ),

          // Manage subscription / Upgrade row
          const Divider(color: CLColors.border, height: 1),
          _tappableRow(
            icon: null,
            label: isPro ? 'Manage subscription' : 'Upgrade to Pro — ${getLocalPricing().fullPrice}',
            labelColor: CLColors.accent,
            onTap: isPro
                ? () => _handleManageSubscription()
                : () => showUpgradeModal(context, source: 'settings'),
          ),
          // Restore purchases option (always visible for signed-in users)
          if (!isPro && state.isSignedIn) ...[
            const Divider(color: CLColors.border, height: 1),
            _tappableRow(
              icon: null,
              label: 'Restore purchases',
              labelColor: CLColors.muted,
              onTap: () async {
                await context.read<AppState>().restorePurchases();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Checking for previous purchases...'),
                      backgroundColor: CLColors.surface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _featureIcon(IconData icon, String label, bool active) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon,
              color: active ? CLColors.muted : CLColors.muted2,
              size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? CLColors.muted : CLColors.muted2,
              fontSize: 9,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _proFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: CLColors.green, size: 16),
          const SizedBox(width: 10),
          Icon(icon, color: CLColors.gold.withOpacity(0.7), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: CLColors.text, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(subtitle, style: TextStyle(color: CLColors.muted.withOpacity(0.6), fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleManageSubscription() async {
    // Open Google Play subscription management page.
    // This lets the user cancel, change payment, or view their subscription.
    final uri = Uri.parse(
      'https://play.google.com/store/account/subscriptions?sku=calorielens_pro_monthly&package=com.pcmacstudios.calorielens',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: open general Play Store subscriptions page
      final fallback = Uri.parse('https://play.google.com/store/account/subscriptions');
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── PREFERENCES SECTION ────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildPreferencesSection() {
    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Reminders toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CLColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: CLColors.accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Reminders',
                          style: TextStyle(
                              color: CLColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 1),
                      Text('Stay on track with meal reminders',
                          style: TextStyle(
                              color: CLColors.muted, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: _remindersOn,
                  onChanged: (val) async {
                    final granted =
                        await NotificationService.requestPermission();
                    if (!granted && val) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please enable notifications in your device settings'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }
                    setState(() => _remindersOn = val);
                    await NotificationService.setRemindersEnabled(val);
                  },
                  activeColor: CLColors.accent,
                  inactiveTrackColor: CLColors.border,
                ),
              ],
            ),
          ),

          // Meal time rows (visible when reminders are on)
          if (_remindersOn) ...[
            const SizedBox(height: 4),
            _mealTimeRow(Icons.wb_sunny_outlined, 'Breakfast',
                _breakfastTime, (t) async {
              setState(() => _breakfastTime = t);
              await NotificationService.setReminderTime('breakfast', t);
            }),
            _mealTimeRow(Icons.restaurant_outlined, 'Lunch',
                _lunchTime, (t) async {
              setState(() => _lunchTime = t);
              await NotificationService.setReminderTime('lunch', t);
            }),
            _mealTimeRow(Icons.nightlight_outlined, 'Dinner',
                _dinnerTime, (t) async {
              setState(() => _dinnerTime = t);
              await NotificationService.setReminderTime('dinner', t);
            }),
          ],

          const Divider(color: CLColors.border, height: 1),

          // Coaching nudges toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: CLColors.gold.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lightbulb_outline,
                      color: CLColors.gold, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Coaching Nudges',
                          style: TextStyle(
                              color: CLColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      SizedBox(height: 1),
                      Text('Get smart tips based on your progress',
                          style: TextStyle(
                              color: CLColors.muted, fontSize: 11)),
                    ],
                  ),
                ),
                Switch(
                  value: _nudgesOn,
                  onChanged: (val) async {
                    final granted =
                        await NotificationService.requestPermission();
                    if (!granted && val) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please enable notifications in your device settings'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                      return;
                    }
                    setState(() => _nudgesOn = val);
                    await NotificationService.setNudgesEnabled(val);
                  },
                  activeColor: CLColors.accent,
                  inactiveTrackColor: CLColors.border,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mealTimeRow(IconData icon, String meal, TimeOfDay time,
      ValueChanged<TimeOfDay> onChanged) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: CLColors.accent,
                surface: CLColors.surface,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 16, 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: CLColors.bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(icon, color: CLColors.accent, size: 16),
              const SizedBox(width: 10),
              Text(meal,
                  style: const TextStyle(
                      color: CLColors.text, fontSize: 13)),
              const Spacer(),
              Text(
                time.format(context),
                style: const TextStyle(
                    color: CLColors.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right,
                  color: CLColors.muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── PROFILE SECTION ────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildProfileRow(AppState state) {
    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      child: _tappableRow(
        icon: Icons.person_outline,
        iconBg: CLColors.blue.withOpacity(0.1),
        iconColor: CLColors.blue,
        label: 'Profile',
        subtitle: 'Manage your personal information',
        labelColor: CLColors.text,
        onTap: () => _showProfileSheet(state),
      ),
    );
  }

  void _showProfileSheet(AppState state) {
    final nameCtrl = TextEditingController(text: state.profile.name);
    final ageCtrl = TextEditingController(
        text: state.profile.age > 0 ? '${state.profile.age}' : '');
    final weightCtrl = TextEditingController(
        text: state.profile.weight > 0 ? '${state.profile.weight}' : '');
    final heightCtrl = TextEditingController(
        text: state.profile.height > 0 ? '${state.profile.height}' : '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: CLColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
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
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Profile',
                            style: TextStyle(
                                color: CLColors.text,
                                fontSize: 18,
                                fontWeight: FontWeight.w700)),
                        Text(
                            'Used to calculate your calorie target',
                            style: TextStyle(
                                color: CLColors.muted, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Fields
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: CLColors.text),
                  decoration: const InputDecoration(
                    hintText: 'Name',
                    prefixIcon: Icon(Icons.badge_outlined,
                        color: CLColors.muted, size: 18),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ageCtrl,
                        keyboardType: TextInputType.number,
                        style:
                            const TextStyle(color: CLColors.text),
                        decoration: const InputDecoration(
                          hintText: 'Age',
                          suffixText: 'yrs',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true),
                        style:
                            const TextStyle(color: CLColors.text),
                        decoration: const InputDecoration(
                          hintText: 'Weight',
                          suffixText: 'kg',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: CLColors.text),
                  decoration: const InputDecoration(
                    hintText: 'Height',
                    suffixText: 'cm',
                  ),
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final p = state.profile.copyWith(
                        name: nameCtrl.text.trim(),
                        age: int.tryParse(ageCtrl.text) ?? 0,
                        weight:
                            double.tryParse(weightCtrl.text) ?? 0,
                        height:
                            int.tryParse(heightCtrl.text) ?? 0,
                      );
                      // Auto-calculate calorie goal
                      if (p.age > 0 &&
                          p.weight > 0 &&
                          p.height > 0) {
                        final bmr = p.sex == 'm'
                            ? 10 * p.weight +
                                6.25 * p.height -
                                5 * p.age +
                                5
                            : 10 * p.weight +
                                6.25 * p.height -
                                5 * p.age -
                                161;
                        final tdee = (bmr * p.activity).round();
                        await context
                            .read<AppState>()
                            .saveCalorieGoal(tdee);
                      }
                      await context
                          .read<AppState>()
                          .saveProfile(p);
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Profile saved'),
                            backgroundColor: CLColors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(10)),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          vertical: 15),
                    ),
                    child: const Text('SAVE CHANGES'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── ABOUT SECTION ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  static const _privacyPolicyUrl =
      'https://pfumbz.github.io/calorielens/privacy-policy.html';

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _tappableRow(
            icon: Icons.info_outline,
            label: 'Privacy Policy',
            labelColor: CLColors.text,
            onTap: () => launchUrl(Uri.parse(_privacyPolicyUrl),
                mode: LaunchMode.externalApplication),
          ),
          const Divider(color: CLColors.border, height: 1),
          _tappableRow(
            icon: Icons.mail_outline,
            label: 'Contact Us',
            labelColor: CLColors.text,
            onTap: () async {
              final uri = Uri(
                scheme: 'mailto',
                path: 'makhuvhap.c@gmail.com',
                queryParameters: {
                  'subject': 'CalorieLens Feedback',
                },
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('No email app found. Reach us at makhuvhap.c@gmail.com'),
                      backgroundColor: CLColors.surface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ── Reusable tappable row ──────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _tappableRow({
    IconData? icon,
    Color? iconBg,
    Color? iconColor,
    required String label,
    String? subtitle,
    required Color labelColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent, // hit area
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg ?? Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon,
                    color: iconColor ?? labelColor, size: 18),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: labelColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: CLColors.muted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: CLColors.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
