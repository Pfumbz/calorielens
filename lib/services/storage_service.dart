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

  // ── 7-day diary ───────────────────────────────────────────────────
  List<({DateTime date, List<DiaryEntry> entries})> getWeekDiaries() {
    return List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return (date: d, entries: getDiary(date: d));
    });
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

  // ── Water ─────────────────────────────────────────────────────────
  int get waterToday {
    final k = 'cl5_water_${_dateKey(DateTime.now())}';
    return _prefs.getInt(k) ?? 0;
  }

  Future<void> saveWater(int glasses) async {
    final k = 'cl5_water_${_dateKey(DateTime.now())}';
    await _prefs.setInt(k, glasses);
  }

  // ── Workout streak ────────────────────────────────────────────────
  int get workoutStreak => _prefs.getInt('cl5_wo_streak') ?? 0;
  Future<void> saveWorkoutStreak(int v) => _prefs.setInt('cl5_wo_streak', v);

  // ── Steps ─────────────────────────────────────────────────────────
  int get stepsToday {
    final k = 'cl5_steps_${_dateKey(DateTime.now())}';
    return _prefs.getInt(k) ?? 0;
  }

  Future<void> saveSteps(int steps) async {
    final k = 'cl5_steps_${_dateKey(DateTime.now())}';
    await _prefs.setInt(k, steps);
  }

  // ── Onboarded ─────────────────────────────────────────────────────
  bool get isOnboarded => _prefs.getBool('cl5_onboarded') ?? false;
  Future<void> setOnboarded() => _prefs.setBool('cl5_onboarded', true);
}
