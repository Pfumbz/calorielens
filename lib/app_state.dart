import 'package:flutter/material.dart';
import 'models/models.dart';
import 'services/storage_service.dart';

class AppState extends ChangeNotifier {
  final _storage = StorageService();

  List<DiaryEntry> _diary = [];
  UserProfile _profile = UserProfile();
  int _calorieGoal = 2000;
  int _water = 0;
  bool _isPremium = false;
  String _apiKey = '';

  List<DiaryEntry> get diary => _diary;
  UserProfile get profile => _profile;
  int get calorieGoal => _calorieGoal;
  int get water => _water;
  bool get isPremium => _isPremium;
  String get apiKey => _apiKey;

  int get totalCalories => _diary.fold(0, (s, e) => s + e.calories);
  int get totalProtein  => _diary.fold(0, (s, e) => s + e.protein);
  int get totalCarbs    => _diary.fold(0, (s, e) => s + e.carbs);
  int get totalFat      => _diary.fold(0, (s, e) => s + e.fat);
  int get caloriesLeft  => (_calorieGoal - totalCalories).clamp(0, 9999);
  bool get hasApiKey    => _apiKey.isNotEmpty;
  bool get canScan      => _storage.canScan;

  Future<void> init() async {
    _diary       = _storage.getDiary();
    _profile     = _storage.profile;
    _calorieGoal = _storage.calorieGoal;
    _water       = _storage.waterToday;
    _isPremium   = _storage.isPremium;
    _apiKey      = _storage.apiKey;
    notifyListeners();
  }

  Future<void> addEntry(DiaryEntry entry) async {
    await _storage.addDiaryEntry(entry);
    _diary = _storage.getDiary();
    notifyListeners();
  }

  Future<void> removeEntry(int id) async {
    await _storage.removeDiaryEntry(id);
    _diary = _storage.getDiary();
    notifyListeners();
  }

  Future<void> setWater(int glasses) async {
    await _storage.saveWater(glasses);
    _water = glasses;
    notifyListeners();
  }

  Future<void> saveCalorieGoal(int g) async {
    await _storage.saveCalorieGoal(g);
    _calorieGoal = g;
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile p) async {
    await _storage.saveProfile(p);
    _profile = p;
    notifyListeners();
  }

  Future<void> saveApiKey(String key) async {
    await _storage.saveApiKey(key);
    _apiKey = key;
    notifyListeners();
  }

  Future<void> trackScan() async {
    await _storage.incrementScanCount();
    notifyListeners();
  }

  Future<void> activatePremium() async {
    await _storage.setPremium(true);
    _isPremium = true;
    notifyListeners();
  }

  Future<void> cancelPremium() async {
    await _storage.setPremium(false);
    _isPremium = false;
    notifyListeners();
  }
}
