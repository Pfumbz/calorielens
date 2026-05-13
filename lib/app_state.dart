import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/models.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'services/backend_service.dart';
import 'services/purchase_service.dart';

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final _storage = StorageService();
  final _purchases = PurchaseService();

  /// Tracks the date when data was last loaded so we can detect day rollover.
  String _lastLoadedDate = '';

  // ── Local state (always populated — offline-first) ──────────────────────
  List<DiaryEntry> _diary = [];
  UserProfile _profile = UserProfile();
  int _calorieGoal = 2000;
  bool _isPremium = false;
  String _apiKey = '';

  // ── Auth / cloud state ──────────────────────────────────────────────────
  User? _supabaseUser;
  int _backendScansToday = 0;
  int _backendChatsToday = 0;

  // ── Meal plan state ───────────────────────────────────────────────────
  List<String> _savedPlanIds = [];

  // ── Getters ─────────────────────────────────────────────────────────────
  List<DiaryEntry> get diary => _diary;
  UserProfile get profile => _profile;
  int get calorieGoal => _calorieGoal;
  bool get isPremium => _isPremium;
  String get apiKey => _apiKey;
  User? get supabaseUser => _supabaseUser;
  bool get isSignedIn => _supabaseUser != null;
  bool get isAnonymous => SupabaseService.isAnonymous;
  bool get isRealUser => SupabaseService.isRealUser;

  List<String> get savedPlanIds => _savedPlanIds;
  bool isPlanSaved(String planId) => _savedPlanIds.contains(planId);

  int get totalCalories => _diary.fold(0, (s, e) => s + e.calories);
  int get totalProtein  => _diary.fold(0, (s, e) => s + e.protein);
  int get totalCarbs    => _diary.fold(0, (s, e) => s + e.carbs);
  int get totalFat      => _diary.fold(0, (s, e) => s + e.fat);
  int get caloriesLeft  => (_calorieGoal - totalCalories).clamp(0, 9999);
  bool get hasApiKey    => _apiKey.isNotEmpty;

  // Scan limits per tier (public for UI copy)
  static const int guestScanLimit = 3;
  static const int freeScanLimit = 5;
  static const int proScanLimit = 50;

  /// Remaining AI scans today (shown in UI).
  int get scansRemainingToday {
    if (_apiKey.isNotEmpty) return 999; // BYOK = unlimited
    if (_isPremium) return (proScanLimit - _backendScansToday).clamp(0, proScanLimit);
    if (isAnonymous) return (guestScanLimit - _backendScansToday).clamp(0, guestScanLimit);
    if (isSignedIn) return (freeScanLimit - _backendScansToday).clamp(0, freeScanLimit);
    return 0; // not signed in at all
  }

  /// Whether the user can attempt a scan right now.
  /// Note: backend enforces the real limit (429 response). This is for UI gating.
  bool get canScan {
    if (_apiKey.isNotEmpty) return true; // BYOK = unlimited
    if (_isPremium) return _backendScansToday < proScanLimit;
    if (isAnonymous) return _backendScansToday < guestScanLimit;
    if (isSignedIn) return _backendScansToday < freeScanLimit;
    return false; // not signed in at all
  }

  /// Returns a ready-to-use BackendService with the current BYOK key (if any).
  BackendService get backend => BackendService(byokApiKey: _apiKey.isNotEmpty ? _apiKey : null);

  /// Build a 7-day meal history summary for Pro AI context.
  /// Returns null for non-Pro users (they only get today's context).
  String? get weeklyMealContext {
    if (!_isPremium && _apiKey.isEmpty) return null;
    final week = _storage.getWeekDiaries();
    final buf = StringBuffer();
    for (final day in week) {
      final dateStr = '${day.date.year}-${day.date.month.toString().padLeft(2, '0')}-${day.date.day.toString().padLeft(2, '0')}';
      if (day.entries.isEmpty) {
        buf.writeln('$dateStr: No meals logged');
        continue;
      }
      final totalCal = day.entries.fold(0, (s, e) => s + e.calories);
      final totalP = day.entries.fold(0, (s, e) => s + e.protein);
      final totalC = day.entries.fold(0, (s, e) => s + e.carbs);
      final totalF = day.entries.fold(0, (s, e) => s + e.fat);
      buf.writeln('$dateStr (${totalCal}kcal, P:${totalP}g C:${totalC}g F:${totalF}g):');
      for (final e in day.entries) {
        buf.writeln('  - ${e.time} ${e.name}: ${e.calories}kcal (P:${e.protein}g C:${e.carbs}g F:${e.fat}g)');
      }
    }
    return buf.toString().trim();
  }

  // ── Diary retention limits per tier ──────────────────────────────────────
  static const int _guestRetainDays = 3;
  static const int _freeRetainDays = 7;
  // Pro / BYOK = unlimited (no pruning)

  /// Returns the diary retention limit in days for the current user tier.
  int get _diaryRetainDays {
    if (_isPremium || _apiKey.isNotEmpty) return 365 * 5; // effectively unlimited
    if (_supabaseUser != null) return _freeRetainDays;
    return _guestRetainDays;
  }

  /// The maximum history days the user's tier allows (for UI display).
  int get historyRetainDays => _diaryRetainDays;

  // ── Initialisation ───────────────────────────────────────────────────────
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    // Always load local data first (works offline)
    _diary       = _storage.getDiary();
    _profile     = _storage.profile;
    _calorieGoal = _storage.calorieGoal;
    _isPremium   = _storage.isPremium;
    _apiKey      = _storage.apiKey;
    _savedPlanIds = _storage.savedPlanIds;
    _lastLoadedDate = _todayString();

    // Load cached cloud counters (so offline mode shows correct values)
    _backendScansToday = _storage.cachedCloudScans;
    _backendChatsToday = _storage.cachedCloudChats;

    // Sync current Supabase user
    _supabaseUser = SupabaseService.currentUser;

    if (_supabaseUser != null) {
      // Refresh from cloud if online — updates counters from server
      await _refreshFromCloud();
    }

    // Initialise in-app purchases and listen for subscription changes
    _purchases.onPremiumChanged = (isPremium) async {
      _isPremium = isPremium;
      await _storage.setPremium(isPremium);
      if (isSignedIn) {
        unawaited(SupabaseService.updateProfile({'is_premium': isPremium}));
      }
      notifyListeners();
    };
    unawaited(_purchases.init());

    // Prune old diary entries based on user tier
    unawaited(_pruneDiaryForTier());

    // Check if coaching nudge should fire on app open
    unawaited(NotificationService.checkAndScheduleNudge(
      caloriesEaten: totalCalories,
      calorieGoal: _calorieGoal,
    ));

    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── App lifecycle — refresh on resume ─────────────────────────────────
  static String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  /// Called when the app returns to the foreground.
  /// Reloads today's diary and resets scan counters if the date has rolled over.
  Future<void> _onAppResumed() async {
    final today = _todayString();
    final dateChanged = today != _lastLoadedDate;

    // Always reload today's diary (user may have been away for a while)
    _diary = _storage.getDiary();

    if (dateChanged) {
      // Date rolled over — reset local scan/chat counters
      _backendScansToday = 0;
      _backendChatsToday = 0;
      _lastLoadedDate = today;
    }

    // Refresh from cloud if signed in (gets accurate scan count for today)
    if (isSignedIn) {
      unawaited(_refreshFromCloud());
    }

    notifyListeners();
  }

  /// Prune diary entries that exceed the current tier's retention limit.
  Future<void> _pruneDiaryForTier() async {
    final retain = _diaryRetainDays;
    await _storage.pruneOldDiaries(retainDays: retain);
    await _storage.pruneOldMeta(retainDays: retain);
  }

  // ── Called by main.dart when auth state becomes signed-in ──────────────
  Future<void> onSignIn() async {
    _supabaseUser = SupabaseService.currentUser;
    if (_supabaseUser == null) return;

    // Migrate local diary data to cloud (one-time, persisted)
    if (!_storage.cloudMigrationDone) {
      await _migrateLocalDataToCloud();
      await _storage.setCloudMigrationDone();
    }

    await _refreshFromCloud();
    notifyListeners();
  }

  // ── Refresh data from cloud ─────────────────────────────────────────────
  Future<void> _refreshFromCloud() async {
    try {
      // Fetch usage stats (for rate limit display) and cache locally
      final usage = await SupabaseService.fetchTodayUsage();
      _backendScansToday = usage.scans;
      _backendChatsToday = usage.chats;
      unawaited(_storage.setCachedCloudScans(usage.scans));
      unawaited(_storage.setCachedCloudChats(usage.chats));

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

    // Check if a coaching nudge should be scheduled
    unawaited(NotificationService.checkAndScheduleNudge(
      caloriesEaten: totalCalories,
      calorieGoal: _calorieGoal,
    ));

    notifyListeners();
  }

  Future<void> removeEntry(int id) async {
    await _storage.removeDiaryEntry(id);
    _diary = _storage.getDiary();
    notifyListeners();
  }

  Future<void> clearAllEntries() async {
    await _storage.saveDiary([]);
    _diary = [];
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
    // Always increment device-level counter so guest limit survives
    // sign-in / sign-out cycling on the same day.
    await _storage.incrementScanCount();

    if (isSignedIn) {
      // Cloud counter is incremented by the Edge Function — just update local cache
      _backendScansToday = (_backendScansToday + 1).clamp(0, 999);
      unawaited(_storage.setCachedCloudScans(_backendScansToday));
    }
    notifyListeners();
  }

  /// Called after a successful chat message to update local cache.
  void trackChat() {
    if (isSignedIn) {
      _backendChatsToday = (_backendChatsToday + 1).clamp(0, 999);
      unawaited(_storage.setCachedCloudChats(_backendChatsToday));
    }
    notifyListeners();
  }

  // ── Premium / Purchases ──────────────────────────────────────────────────

  /// Access the purchase service (for UI to trigger purchases).
  PurchaseService get purchases => _purchases;

  /// Activate premium (called by PurchaseService callback or for BYOK users).
  Future<void> activatePremium() async {
    await _storage.setPremium(true);
    _isPremium = true;
    if (isSignedIn) {
      unawaited(SupabaseService.updateProfile({'is_premium': true}));
    }
    notifyListeners();
  }

  /// Cancel premium locally (subscription cancellation is handled via Play Store).
  Future<void> cancelPremium() async {
    await _storage.setPremium(false);
    _isPremium = false;
    if (isSignedIn) {
      unawaited(SupabaseService.updateProfile({'is_premium': false}));
    }
    notifyListeners();
  }

  /// Restore previous purchases from Google Play.
  Future<void> restorePurchases() async {
    await _purchases.restorePurchases();
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

    // Restore device-level scan count so guest limit reflects ALL scans
    // made today (prevents exploit: guest→sign-in→sign-out→fresh counter).
    _backendScansToday = _storage.scanCountToday;
    _backendChatsToday = 0;

    // Prune diary down to guest limits
    unawaited(_storage.pruneOldDiaries(retainDays: _guestRetainDays));
    unawaited(_storage.pruneOldMeta(retainDays: _guestRetainDays));

    notifyListeners();
  }
}

/// Fire-and-forget helper — logs errors instead of crashing.
void unawaited(Future<void> future) {
  future.catchError((e) => debugPrint('Background sync error: $e'));
}
