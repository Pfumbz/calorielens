import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  // Secure storage for sensitive values (uses Android Keystore / iOS Keychain).
  static const _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // One-time migration: move legacy plain-text API key into secure storage.
    await _migrateApiKey();
  }

  /// Migrates a key previously stored in SharedPreferences into secure storage,
  /// then removes the plain-text copy. Safe to call on every init — no-ops once done.
  Future<void> _migrateApiKey() async {
    final legacyKey = _prefs.getString('cl_api_key');
    if (legacyKey != null && legacyKey.isNotEmpty) {
      await _secure.write(key: 'cl_api_key', value: legacyKey);
      await _prefs.remove('cl_api_key');
    }
  }

  // ── API Key (stored in encrypted secure storage) ──────────────────
  /// Async — reads from Android Keystore / iOS Keychain.
  Future<String> getApiKey() async {
    return await _secure.read(key: 'cl_api_key') ?? '';
  }

  Future<void> saveApiKey(String key) async {
    if (key.isEmpty) {
      await _secure.delete(key: 'cl_api_key');
    } else {
      await _secure.write(key: 'cl_api_key', value: key);
    }
  }

  // ── Premium ───────────────────────────────────────────────────────
  bool get isPremium => _prefs.getString('cl5_premium') == '1';
  Future<void> setPremium(bool v) =>
      v ? _prefs.setString('cl5_premium', '1') : _prefs.remove('cl5_premium');

  // ── Scan count (daily) ────────────────────────────────────────────
  int get scanCountToday {
    final k = 'cl5_scans_${_dateKey(DateTime.now())}';
    return _prefs.getInt(k) ?? 0;
  }

  Future<void> incrementScanCount() async {
    final k = 'cl5_scans_${_dateKey(DateTime.now())}';
    await _prefs.setInt(k, scanCountToday + 1);
  }

  bool get canScan => isPremium || scanCountToday < 3;

  // ── Cloud scan/chat count cache (survives restarts for offline) ───
  String get _cloudScanKey => 'cl6_cloud_scans_${_dateKey(DateTime.now())}';
  String get _cloudChatKey => 'cl6_cloud_chats_${_dateKey(DateTime.now())}';

  int get cachedCloudScans => _prefs.getInt(_cloudScanKey) ?? 0;
  int get cachedCloudChats => _prefs.getInt(_cloudChatKey) ?? 0;

  Future<void> setCachedCloudScans(int v) => _prefs.setInt(_cloudScanKey, v);
  Future<void> setCachedCloudChats(int v) => _prefs.setInt(_cloudChatKey, v);

  // ── Diary ─────────────────────────────────────────────────────────
  List<DiaryEntry> getDiary({DateTime? date}) {
    final k = 'cl3_diary_${_dateKey(date ?? DateTime.now())}';
    final raw = _prefs.getString(k);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((j) => DiaryEntry.fromJson(j as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDiary(List<DiaryEntry> entries, {DateTime? date}) async {
    final k = 'cl3_diary_${_dateKey(date ?? DateTime.now())}';
    await _prefs.setString(k, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  Future<void> addDiaryEntry(DiaryEntry entry, {DateTime? date}) async {
    final entries = getDiary(date: date);
    entries.add(entry);
    await saveDiary(entries, date: date);
  }

  Future<void> removeDiaryEntry(int id, {DateTime? date}) async {
    final entries = getDiary(date: date);
    entries.removeWhere((e) => e.id == id);
    await saveDiary(entries, date: date);
  }

  // ── Diary pruning (tier-based retention) ───────────────────────────
  /// Removes diary entries older than [retainDays] from SharedPreferences.
  /// Returns the number of days pruned.
  Future<int> pruneOldDiaries({required int retainDays}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retainDays));
    final keys = _prefs.getKeys().where((k) => k.startsWith('cl3_diary_')).toList();
    int pruned = 0;
    for (final key in keys) {
      // Extract date from key: cl3_diary_2026-05-01
      final dateStr = key.replaceFirst('cl3_diary_', '');
      try {
        final parts = dateStr.split('-');
        if (parts.length != 3) continue;
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        if (date.isBefore(cutoff)) {
          await _prefs.remove(key);
          pruned++;
        }
      } catch (_) {
        // Malformed key — skip
      }
    }
    return pruned;
  }

  /// Also prune old water, scan count, health, and cloud-cache keys.
  Future<void> pruneOldMeta({required int retainDays}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retainDays));
    // Expanded: also prune health and cloud-counter date-keyed entries that
    // previously accumulated indefinitely.
    final prefixes = [
      'cl5_water_', 'cl5_scans_',
      'cl6_health_steps_', 'cl6_health_cal_',
      'cl6_cloud_scans_', 'cl6_cloud_chats_',
    ];
    for (final prefix in prefixes) {
      final keys = _prefs.getKeys().where((k) => k.startsWith(prefix)).toList();
      for (final key in keys) {
        final dateStr = key.replaceFirst(prefix, '');
        try {
          final parts = dateStr.split('-');
          if (parts.length != 3) continue;
          final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
          if (date.isBefore(cutoff)) {
            await _prefs.remove(key);
          }
        } catch (_) {}
      }
    }
  }

  // ── 7-day diary ───────────────────────────────────────────────────
  List<({DateTime date, List<DiaryEntry> entries})> getWeekDiaries() {
    return List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return (date: d, entries: getDiary(date: d));
    });
  }

  // ── N-day diary (for history screen) ──────────────────────────────
  /// Returns diary entries for the last [days] days, most recent first.
  /// Only returns days that have at least one entry.
  List<({DateTime date, List<DiaryEntry> entries})> getDiaryRange({int days = 30}) {
    final results = <({DateTime date, List<DiaryEntry> entries})>[];
    for (int i = 0; i < days; i++) {
      final d = DateTime.now().subtract(Duration(days: i));
      final entries = getDiary(date: d);
      if (entries.isNotEmpty) {
        results.add((date: d, entries: entries));
      }
    }
    return results;
  }

  /// Returns the total calories for a given date.
  int totalCaloriesForDate(DateTime date) {
    return getDiary(date: date).fold(0, (sum, e) => sum + e.calories);
  }

  // ── Profile ───────────────────────────────────────────────────────
  UserProfile get profile {
    final raw = _prefs.getString('cl5_profile');
    if (raw == null) return UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UserProfile();
    }
  }

  Future<void> saveProfile(UserProfile p) async {
    await _prefs.setString('cl5_profile', jsonEncode(p.toJson()));
  }

  // ── Calorie goal ──────────────────────────────────────────────────
  int get calorieGoal => _prefs.getInt('cl3_goal') ?? 2000;
  Future<void> saveCalorieGoal(int g) => _prefs.setInt('cl3_goal', g);

  // ── Onboarded ─────────────────────────────────────────────────────
  bool get isOnboarded => _prefs.getBool('cl5_onboarded') ?? false;
  Future<void> setOnboarded() => _prefs.setBool('cl5_onboarded', true);

  // ── Goal direction ('lose' | 'maintain' | 'gain') ─────────────────
  // Stored locally (not in UserProfile/cloud) so the profile sheet can
  // re-select it and recompute the calorie target consistently.
  String get goalDirection => _prefs.getString('cl6_goal_dir') ?? 'maintain';
  Future<void> setGoalDirection(String v) => _prefs.setString('cl6_goal_dir', v);

  // ── In-app review tracking ─────────────────────────────────────────
  /// Lifetime count of successful scans — drives the "positive moment" that
  /// triggers the Play in-app review prompt.
  int get totalSuccessfulScans => _prefs.getInt('cl6_total_scans') ?? 0;
  Future<void> incrementTotalScans() =>
      _prefs.setInt('cl6_total_scans', totalSuccessfulScans + 1);

  /// Whether we've already asked for a review (so we never nag).
  bool get reviewRequested => _prefs.getBool('cl6_review_requested') ?? false;
  Future<void> setReviewRequested() =>
      _prefs.setBool('cl6_review_requested', true);

  // ── Logging streak ─────────────────────────────────────────────────
  int get _streakValue => _prefs.getInt('cl6_streak') ?? 0;
  int get longestStreak => _prefs.getInt('cl6_streak_best') ?? 0;
  String get _streakDate => _prefs.getString('cl6_streak_date') ?? '';

  /// The streak as it should be *displayed*: valid only if the last logged day
  /// was today or yesterday, otherwise the streak has lapsed and reads 0.
  int get currentStreak {
    final last = _streakDate;
    if (last.isEmpty) return 0;
    final now = DateTime.now();
    final today = _dateKey(now);
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    return (last == today || last == yesterday) ? _streakValue : 0;
  }

  /// Call when the user logs a meal. No-op if already counted today; increments
  /// for a consecutive day; resets to 1 if a day was missed. Returns the streak.
  Future<int> registerMealLoggedToday() async {
    final now = DateTime.now();
    final today = _dateKey(now);
    if (_streakDate == today) return _streakValue; // already counted today
    final yesterday = _dateKey(now.subtract(const Duration(days: 1)));
    final streak = (_streakDate == yesterday) ? _streakValue + 1 : 1;
    await _prefs.setInt('cl6_streak', streak);
    await _prefs.setString('cl6_streak_date', today);
    if (streak > longestStreak) await _prefs.setInt('cl6_streak_best', streak);
    return streak;
  }

  // ── Cloud migration flag ─────────────────────────────────────────
  bool get cloudMigrationDone => _prefs.getBool('cl5_cloud_migrated') ?? false;
  Future<void> setCloudMigrationDone() => _prefs.setBool('cl5_cloud_migrated', true);

  // ── Saved meal plans ─────────────────────────────────────────────
  List<String> get savedPlanIds {
    return _prefs.getStringList('cl5_saved_plans') ?? [];
  }

  Future<void> savePlanId(String planId) async {
    final ids = savedPlanIds;
    if (!ids.contains(planId)) {
      ids.add(planId);
      await _prefs.setStringList('cl5_saved_plans', ids);
    }
  }

  Future<void> removePlanId(String planId) async {
    final ids = savedPlanIds;
    ids.remove(planId);
    await _prefs.setStringList('cl5_saved_plans', ids);
  }

  bool isPlanSaved(String planId) => savedPlanIds.contains(planId);

  // ── Health Connect preferences ───────────────────────────────────
  bool get healthConnectEnabled => _prefs.getBool('cl6_health_enabled') ?? false;
  Future<void> setHealthConnectEnabled(bool v) => _prefs.setBool('cl6_health_enabled', v);

  bool get autoAdjustGoal => _prefs.getBool('cl6_health_auto_adjust') ?? false;
  Future<void> setAutoAdjustGoal(bool v) => _prefs.setBool('cl6_health_auto_adjust', v);

  /// Activity multiplier: how much of burned calories to add back (0.0–1.0).
  double get activityMultiplier => _prefs.getDouble('cl6_health_multiplier') ?? 0.6;
  Future<void> setActivityMultiplier(double v) => _prefs.setDouble('cl6_health_multiplier', v);

  /// Cached health data (survives restarts for offline display).
  String get _healthStepsKey => 'cl6_health_steps_${_dateKey(DateTime.now())}';
  String get _healthCalKey => 'cl6_health_cal_${_dateKey(DateTime.now())}';

  int get cachedHealthSteps => _prefs.getInt(_healthStepsKey) ?? 0;
  int get cachedHealthCalories => _prefs.getInt(_healthCalKey) ?? 0;

  Future<void> setCachedHealthSteps(int v) => _prefs.setInt(_healthStepsKey, v);
  Future<void> setCachedHealthCalories(int v) => _prefs.setInt(_healthCalKey, v);

  /// Whether the user has dismissed the Health Connect onboarding prompt.
  bool get healthOnboardingDismissed => _prefs.getBool('cl6_health_onboard_dismissed') ?? false;
  Future<void> setHealthOnboardingDismissed(bool v) => _prefs.setBool('cl6_health_onboard_dismissed', v);

  /// Whether the user has dismissed the profile completion nudge.
  bool get profileNudgeDismissed => _prefs.getBool('cl6_profile_nudge_dismissed') ?? false;
  Future<void> setProfileNudgeDismissed(bool v) => _prefs.setBool('cl6_profile_nudge_dismissed', v);

  /// Synchronous read of whether meal reminders are on (key owned by
  /// NotificationService) — lets the Today screen decide whether to show the
  /// "turn on reminders" prompt without an async call.
  bool get remindersOn => _prefs.getBool('notif_reminders_on') ?? false;

  /// Whether the user has dismissed the "turn on reminders" prompt.
  bool get remindersPromptDismissed => _prefs.getBool('cl6_reminders_prompt_dismissed') ?? false;
  Future<void> setRemindersPromptDismissed(bool v) => _prefs.setBool('cl6_reminders_prompt_dismissed', v);

  // ── AI-generated meal plans (JSON strings) ───────────────────────
  List<String> get generatedPlansJson {
    return _prefs.getStringList('cl5_gen_plans') ?? [];
  }

  Future<void> saveGeneratedPlan(String planJson) async {
    final plans = generatedPlansJson;
    plans.insert(0, planJson); // newest first
    // Keep max 10 generated plans
    if (plans.length > 10) plans.removeRange(10, plans.length);
    await _prefs.setStringList('cl5_gen_plans', plans);
  }

  Future<void> clearGeneratedPlans() async {
    await _prefs.remove('cl5_gen_plans');
  }
}
