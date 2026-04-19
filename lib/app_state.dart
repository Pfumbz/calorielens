import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/models.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'services/backend_service.dart';

class AppState extends ChangeNotifier {
  final _storage = StorageService();

  // ── Local state (always populated — offline-first) ──────────────────────
  List<DiaryEntry> _diary = [];
  UserProfile _profile = UserProfile();
  int _calorieGoal = 2000;
  int _water = 0;
  bool _isPremium = false;
  String _apiKey = '';

  // ── Auth / cloud state ──────────────────────────────────────────────────
  User? _supabaseUser;
  int _backendScansToday = 0;
  int _backendChatsToday = 0;
  bool _migrationDone = false; // local → cloud migration flag

  // ── Meal plan state ───────────────────────────────────────────────────
  List<String> _savedPlanIds = [];

  // ── Getters ─────────────────────────────────────────────────────────────
  List<DiaryEntry> get diary => _diary;
  UserProfile get profile => _profile;
  int get calorieGoal => _calorieGoal;
  int get water => _water;
  bool get isPremium => _isPremium;
  String get apiKey => _apiKey;
  User? get supabaseUser => _supabaseUser;
  bool get isSignedIn => _supabaseUser != null;

  List<String> get savedPlanIds => _savedPlanIds;
  bool isPlanSaved(String planId) => _savedPlanIds.contains(planId);

  int get totalCalories => _diary.fold(0, (s, e) => s + e.calories);
  int get totalProtein  => _diary.fold(0, (s, e) => s + e.protein);
  int get totalCarbs    => _diary.fold(0, (s, e) => s + e.carbs);
  int get totalFat      => _diary.fold(0, (s, e) => s + e.fat);
  int get caloriesLeft  => (_calorieGoal - totalCalories).clamp(0, 9999);
  bool get hasApiKey    => _apiKey.isNotEmpty;

  /// Remaining free AI scans today (shown in UI).
  int get scansRemainingToday {
    if (_apiKey.isNotEmpty || _isPremium) return 999;
    if (isSignedIn) return (10 - _backendScansToday).clamp(0, 10);
    return (3 - _storage.scanCountToday).clamp(0, 3);
  }

  /// Whether the user can attempt a scan right now.
  /// Note: backend enforces the real limit (429 response). This is for UI gating.
  bool get canScan {
    if (_apiKey.isNotEmpty || _isPremium) return true;
    if (isSignedIn) return _backendScansToday < 10;
    return _storage.canScan; // local 3/day for guests
  }

  /// Returns a ready-to-use BackendService with the current BYOK key (if any).
  BackendService get backend => BackendService(byokApiKey: _apiKey.isNotEmpty ? _apiKey : null);

  // ── Initialisation ───────────────────────────────────────────────────────
  Future<void> init() async {
    // Always load local data first (works offline)
    _diary       = _storage.getDiary();
    _profile     = _storage.profile;
    _calorieGoal = _storage.calorieGoal;
    _water       = _storage.waterToday;
    _isPremium   = _storage.isPremium;
    _apiKey      = _storage.apiKey;
    _savedPlanIds = _storage.savedPlanIds;

    // Sync current Supabase user
    _supabaseUser = SupabaseService.currentUser;

    if (_supabaseUser != null) {
      await _refreshFromCloud();
    }

    notifyListeners();
  }

  // ── Called by main.dart when auth state becomes signed-in ──────────────
  Future<void> onSignIn() async {
    _supabaseUser = SupabaseService.currentUser;
    if (_supabaseUser == null) return;

    // Migrate local diary data to cloud (one-time)
    if (!_migrationDone) {
      await _migrateLocalDataToCloud();
      _migrationDone = true;
    }

    await _refreshFromCloud();
    notifyListeners();
  }

  // ── Refresh data from cloud ─────────────────────────────────────────────
  Future<void> _refreshFromCloud() async {
    try {
      // Fetch usage stats (for rate limit display)
      final usage = await SupabaseService.fetchTodayUsage();
      _backendScansToday = usage.scans;
      _backendChatsToday = usage.chats;

      // Fetch profile from cloud (overrides local if cloud is newer)
      final cloudProfile = await SupabaseService.fetchProfile();
      if (cloudProfile != null) {
        _isPremium = cloudProfile['is_premium'] as bool? ?? false;
        await _storage.setPremium(_isPremium);

        final goal = cloudProfile['calorie_goal'] as int?;
        if (goal != null && goal > 0) {
          _calorieGoal = goal;
          await _storage.saveCalorieGoal(goal);
        }

        // Merge profile fields if non-empty
        final cp = UserProfile(
          name: cloudProfile['name'] as String? ?? _profile.name,
          age: cloudProfile['age'] as int? ?? _profile.age,
          weight: (cloudProfile['weight_kg'] as num?)?.toDouble() ?? _profile.weight,
          height: cloudProfile['height_cm'] as int? ?? _profile.height,
          sex: cloudProfile['sex'] as String? ?? _profile.sex,
          activity: (cloudProfile['activity'] as num?)?.toDouble() ?? _profile.activity,
          calorieGoal: goal ?? _profile.calorieGoal,
        );
        _profile = cp;
        await _storage.saveProfile(cp);
      }

      // Fetch today's cloud diary and merge with local
      final cloudEntries = await SupabaseService.fetchTodayDiary();
      if (cloudEntries.isNotEmpty) {
        final cloudDiary = cloudEntries.map((e) => DiaryEntry(
          id: (e['id'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
          time: e['time'] as String? ?? '',
          name: e['meal_name'] as String? ?? '',
          calories: e['calories'] as int? ?? 0,
          protein: e['protein_g'] as int? ?? 0,
          carbs: e['carbs_g'] as int? ?? 0,
          fat: e['fat_g'] as int? ?? 0,
          fiber: e['fiber_g'] as int? ?? 0,
        )).toList();

        // Use cloud diary as authoritative (it has the full history)
        _diary = cloudDiary;
        await _storage.saveDiary(cloudDiary);
      }
    } catch (_) {
      // Cloud unavailable — silently continue with local data
    }
  }

  // ── Migrate local → cloud (first sign-in) ──────────────────────────────
  Future<void> _migrateLocalDataToCloud() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final localEntries = _storage.getDiary();
      if (localEntries.isEmpty) return;

      final rows = localEntries.map((e) => {
        'date': today,
        'time': e.time,
        'meal_name': e.name,
        'calories': e.calories,
        'protein_g': e.protein,
        'carbs_g': e.carbs,
        'fat_g': e.fat,
        'fiber_g': e.fiber,
      }).toList();

      await SupabaseService.bulkInsertDiaryEntries(rows);

      // Also push profile to cloud
      await SupabaseService.updateProfile({
        'name': _profile.name,
        'age': _profile.age,
        'weight_kg': _profile.weight,
        'height_cm': _profile.height,
        'sex': _profile.sex,
        'activity': _profile.activity,
        'calorie_goal': _calorieGoal,
        'is_premium': _isPremium,
      });
    } catch (_) {
      // Migration failed silently — will retry next sign-in
    }
  }

  // ── Diary operations ────────────────────────────────────────────────────
  Future<void> addEntry(DiaryEntry entry) async {
    await _storage.addDiaryEntry(entry);
    _diary = _storage.getDiary();

    // Sync to cloud if signed in
    if (isSignedIn) {
      final today = DateTime.now().toIso8601String().split('T')[0];
      unawaited(SupabaseService.insertDiaryEntry(
        date: today,
        time: entry.time,
        mealName: entry.name,
        calories: entry.calories,
        proteinG: entry.protein,
        carbsG: entry.carbs,
        fatG: entry.fat,
        fiberG: entry.fiber,
      ));
    }

    notifyListeners();
  }

  Future<void> removeEntry(int id) async {
    await _storage.removeDiaryEntry(id);
    _diary = _storage.getDiary();
    notifyListeners();
  }

  // ── Water ────────────────────────────────────────────────────────────────
  Future<void> setWater(int glasses) async {
    await _storage.saveWater(glasses);
    _water = glasses;
    notifyListeners();
  }

  // ── Goals & profile ──────────────────────────────────────────────────────
  Future<void> saveCalorieGoal(int g) async {
    await _storage.saveCalorieGoal(g);
    _calorieGoal = g;
    if (isSignedIn) {
      unawaited(SupabaseService.updateProfile({'calorie_goal': g}));
    }
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    await _storage.saveProfile(p);
    _profile = p;
    if (isSignedIn) {
      unawaited(SupabaseService.updateProfile({
        'name': p.name,
        'age': p.age,
        'weight_kg': p.weight,
        'height_cm': p.height,
        'sex': p.sex,
        'activity': p.activity,
      }));
    }
    notifyListeners();
  }

  // ── API Key (BYOK) ──────────────────────────────────────────────────────
  Future<void> saveApiKey(String key) async {
    await _storage.saveApiKey(key);
    _apiKey = key;
    notifyListeners();
  }

  // ── Scan tracking ────────────────────────────────────────────────────────
  /// Called after a successful scan to update local/cloud counters.
  Future<void> trackScan() async {
    if (isSignedIn) {
      // Cloud counter is incremented by the Edge Function — just update local cache
      _backendScansToday = (_backendScansToday + 1).clamp(0, 999);
    } else {
      await _storage.incrementScanCount();
    }
    notifyListeners();
  }

  /// Called after a successful chat message to update local cache.
  void trackChat() {
    if (isSignedIn) {
      _backendChatsToday = (_backendChatsToday + 1).clamp(0, 999);
    }
    notifyListeners();
  }

  // ── Premium ──────────────────────────────────────────────────────────────
  Future<void> activatePremium() async {
    await _storage.setPremium(true);
    _isPremium = true;
    if (isSignedIn) {
      unawaited(SupabaseService.updateProfile({'is_premium': true}));
    }
    notifyListeners();
  }

  Future<void> cancelPremium() async {
    await _storage.setPremium(false);
    _isPremium = false;
    if (isSignedIn) {
      unawaited(SupabaseService.updateProfile({'is_premium': false}));
    }
    notifyListeners();
  }

  // ── Meal plan favourites ──────────────────────────────────────────────────
  Future<void> toggleSavedPlan(String planId) async {
    if (_savedPlanIds.contains(planId)) {
      await _storage.removePlanId(planId);
      _savedPlanIds.remove(planId);
    } else {
      await _storage.savePlanId(planId);
      _savedPlanIds.add(planId);
    }
    notifyListeners();
  }

  // ── Sign out ─────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    _supabaseUser = null;
    _backendScansToday = 0;
    _backendChatsToday = 0;
    _migrationDone = false;
    notifyListeners();
  }
}

/// Fire-and-forget helper — logs errors instead of crashing.
void unawaited(Future<void> future) {
  future.catchError((e) => debugPrint('Background sync error: $e'));
}
