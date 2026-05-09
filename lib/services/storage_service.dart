import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ── API Key ───────────────────────────────────────────────────────
  String get apiKey => _prefs.getString('cl_api_key') ?? '';
  Future<void> saveApiKey(String key) => _prefs.setString('cl_api_key', key);

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

  /// Also prune old water and scan count keys to keep storage clean.
  Future<void> pruneOldMeta({required int retainDays}) async {
    final cutoff = DateTime.now().subtract(Duration(days: retainDays));
    final prefixes = ['cl5_water_', 'cl5_scans_'];
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
