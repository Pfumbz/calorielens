import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_state.dart';
import '../services/auth_service.dart';
import '../services/health_service.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../utils/pricing.dart';
import '../widgets/profile_sheet.dart';
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

  // Collapsible section state
  bool _expandedSubscription = false;
  bool _expandedHealth = false;
  bool _expandedPreferences = false;

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

              // ── HEALTH CONNECT ─────────────────────────────────
              _sectionLabel('HEALTH CONNECT'),
              const SizedBox(height: 8),
              _buildHealthSection(state),
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
          // Header row: crown + title + badge (tap to expand)
          GestureDetector(
            onTap: () => setState(() => _expandedSubscription = !_expandedSubscription),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
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
                          isPro ? 'CalNova Pro' : 'CalNova Free',
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
                  AnimatedRotation(
                    turns: _expandedSubscription ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right,
                        color: CLColors.muted, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // Expandable details
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expandedSubscription
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(color: CLColors.border, height: 1),
                // Feature details
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
          ),
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
    // Build status summary
    final statusParts = <String>[];
    if (_remindersOn) statusParts.add('Reminders on');
    if (_nudgesOn) statusParts.add('Nudges on');
    final statusText = statusParts.isEmpty
        ? 'All notifications off'
        : statusParts.join(' · ');

    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row (tap to expand)
          GestureDetector(
            onTap: () => setState(() => _expandedPreferences = !_expandedPreferences),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: CLColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_outlined,
                        color: CLColors.accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notifications',
                            style: TextStyle(
                                color: CLColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(statusText,
                            style: const TextStyle(
                                color: CLColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expandedPreferences ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right,
                        color: CLColors.muted, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // Expandable details
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expandedPreferences
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                const Divider(color: CLColors.border, height: 1),

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
                        child: const Icon(Icons.alarm,
                            color: CLColors.accent, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Meal Reminders',
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
                          final state = Provider.of<AppState>(context, listen: false);
                          await NotificationService.setNudgesEnabled(
                            val,
                            caloriesEaten: state.totalCalories,
                            calorieGoal: state.calorieGoal,
                          );
                        },
                        activeColor: CLColors.accent,
                        inactiveTrackColor: CLColors.border,
                      ),
                    ],
                  ),
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
  // ── HEALTH CONNECT SECTION ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildHealthSection(AppState state) {
    final isEnabled = state.healthEnabled;

    // Build status summary for collapsed view
    final statusText = isEnabled
        ? (state.stepsToday > 0
            ? 'Connected · ${state.stepsToday} steps today'
            : 'Connected')
        : 'Not connected';

    return Container(
      decoration: BoxDecoration(
        color: CLColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CLColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header row (tap to expand)
          GestureDetector(
            onTap: () => setState(() => _expandedHealth = !_expandedHealth),
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? CLColors.green.withOpacity(0.1)
                          : CLColors.accent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.monitor_heart_outlined,
                        color: isEnabled ? CLColors.green : CLColors.accent,
                        size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Health Connect',
                            style: TextStyle(
                                color: CLColors.text,
                                fontSize: 16,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(statusText,
                            style: const TextStyle(
                                color: CLColors.muted, fontSize: 11)),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expandedHealth ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.chevron_right,
                        color: CLColors.muted, size: 18),
                  ),
                ],
              ),
            ),
          ),

          // Expandable details
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _expandedHealth
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Column(
              children: [
                // Connect button (when not connected)
                if (!isEnabled) ...[
                  const Divider(color: CLColors.border, height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      children: [
                        const Text(
                          'Track steps and calories burned from your fitness watch or phone sensors.',
                          style: TextStyle(color: CLColors.muted, fontSize: 12, height: 1.4),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _connectHealthConnect(),
                            icon: const Icon(Icons.link, size: 18),
                            label: const Text('Connect'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: CLColors.accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Sub-settings + disconnect (only visible when connected)
                if (isEnabled) ...[
                  const Divider(color: CLColors.border, height: 1),

                  // Auto-adjust goal toggle
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: CLColors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.track_changes,
                              color: CLColors.green, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('Auto-adjust calorie goal',
                                  style: TextStyle(
                                      color: CLColors.text,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              SizedBox(height: 1),
                              Text('Add activity bonus to daily target',
                                  style: TextStyle(
                                      color: CLColors.muted, fontSize: 11)),
                            ],
                          ),
                        ),
                        Switch(
                          value: state.autoAdjustGoal,
                          onChanged: (val) =>
                              context.read<AppState>().setAutoAdjustGoal(val),
                          activeColor: CLColors.accent,
                          inactiveTrackColor: CLColors.border,
                        ),
                      ],
                    ),
                  ),

                  // Activity multiplier
                  if (state.autoAdjustGoal) ...[
                    const Divider(color: CLColors.border, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: CLColors.muted.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.tune,
                                color: CLColors.muted, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text('Activity multiplier',
                                    style: TextStyle(
                                        color: CLColors.text,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600)),
                                SizedBox(height: 1),
                                Text('How much of burned calories to add back',
                                    style: TextStyle(
                                        color: CLColors.muted, fontSize: 11)),
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showMultiplierPicker(state),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: CLColors.accentLo,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${(state.activityMultiplier * 100).round()}%',
                                style: const TextStyle(
                                    color: CLColors.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Status line
                  if (state.stepsToday > 0) ...[
                    const Divider(color: CLColors.border, height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 14, color: CLColors.green),
                          const SizedBox(width: 8),
                          Text(
                            '${state.stepsToday} steps · ${state.activeCaloriesToday} kcal burned today',
                            style: const TextStyle(
                                color: CLColors.green,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Disconnect option
                  const Divider(color: CLColors.border, height: 1),
                  GestureDetector(
                    onTap: () async {
                      await context.read<AppState>().setHealthEnabled(false);
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: CLColors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.link_off,
                                color: CLColors.red, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Text('Disconnect',
                              style: TextStyle(
                                  color: CLColors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Connect to Health Connect — same flow as Today tab banner.
  Future<void> _connectHealthConnect() async {
    final health = HealthService();
    final granted = await health.requestPermissions();
    if (granted) {
      if (mounted) {
        await context.read<AppState>().setHealthEnabled(true);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Could not connect. Make sure Health Connect is installed and permissions are allowed.'),
            backgroundColor: CLColors.surface,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showMultiplierPicker(AppState state) {
    final options = [
      (0.4, '40%', 'Conservative — eat back less'),
      (0.5, '50%', 'Moderate — balanced approach'),
      (0.6, '60%', 'Recommended — good default'),
      (0.7, '70%', 'Active — eat back more'),
      (0.8, '80%', 'High — for very active users'),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: CLColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: CLColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Activity multiplier',
                style: TextStyle(
                    color: CLColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text(
              'How much of your burned calories should be added back to your daily goal?',
              textAlign: TextAlign.center,
              style: TextStyle(color: CLColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...options.map((opt) {
              final isSelected =
                  (state.activityMultiplier - opt.$1).abs() < 0.01;
              return GestureDetector(
                onTap: () {
                  context.read<AppState>().setActivityMultiplier(opt.$1);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? CLColors.accentLo : CLColors.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? CLColors.accent.withOpacity(0.3)
                          : CLColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(opt.$2,
                          style: TextStyle(
                              color: isSelected
                                  ? CLColors.accent
                                  : CLColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(opt.$3,
                            style: const TextStyle(
                                color: CLColors.muted, fontSize: 12)),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle,
                            color: CLColors.accent, size: 18),
                    ],
                  ),
                ),
              );
            }),
          ],
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
        onTap: () => showProfileSheet(context),
      ),
    );
  }


  // ═══════════════════════════════════════════════════════════════════════
  // ── ABOUT SECTION ──────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════════════════
  static const _privacyPolicyUrl =
      'https://pfumbz.github.io/calorielens/privacy-policy.html';
  static const _termsOfServiceUrl =
      'https://pfumbz.github.io/calorielens/terms-of-service.html';
  static const _faqUrl =
      'https://pfumbz.github.io/calorielens/faq.html';

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
            icon: Icons.description_outlined,
            label: 'Terms of Service',
            labelColor: CLColors.text,
            onTap: () => launchUrl(Uri.parse(_termsOfServiceUrl),
                mode: LaunchMode.externalApplication),
          ),
          const Divider(color: CLColors.border, height: 1),
          _tappableRow(
            icon: Icons.help_outline,
            label: 'FAQ & Support',
            labelColor: CLColors.text,
            onTap: () => launchUrl(Uri.parse(_faqUrl),
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
                path: 'pcmacstudios@gmail.com',
                queryParameters: {
                  'subject': 'CalNova Feedback',
                },
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('No email app found. Reach us at pcmacstudios@gmail.com'),
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
