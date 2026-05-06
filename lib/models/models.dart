import 'dart:convert';

// ── Safe parsing helpers ─────────────────────────────────────────────
int _toInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

double _toDouble(dynamic v, [double fallback = 0.0]) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

// ── Diary Entry ──────────────────────────────────────────────────────
class DiaryEntry {
  final int id;
  final String time;
  final String name;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int fiber;

  DiaryEntry({
    required this.id,
    required this.time,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber = 0,
  });

  factory DiaryEntry.fromJson(Map<String, dynamic> j) => DiaryEntry(
        id: _toInt(j['id']),
        time: (j['time'] ?? '') as String,
        name: (j['name'] ?? 'Unknown') as String,
        calories: _toInt(j['calories']),
        protein: _toInt(j['protein']),
        carbs: _toInt(j['carbs']),
        fat: _toInt(j['fat']),
        fiber: _toInt(j['fiber']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'time': time,
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };
}

// ── Scan Result ──────────────────────────────────────────────────────
class ScanResult {
  final String mealName;
  final int totalCalories;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final int fiberG;
  final List<FoodItem> items;
  final String overallNotes;

  ScanResult({
    required this.mealName,
    required this.totalCalories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.items,
    required this.overallNotes,
  });

  factory ScanResult.fromJson(Map<String, dynamic> j) => ScanResult(
        mealName: (j['meal_name'] ?? 'Unknown Meal') as String,
        totalCalories: _toInt(j['total_calories']),
        proteinG: _toInt(j['protein_g']),
        carbsG: _toInt(j['carbs_g']),
        fatG: _toInt(j['fat_g']),
        fiberG: _toInt(j['fiber_g']),
        items: (j['items'] as List? ?? [])
            .map((i) => FoodItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        overallNotes: (j['overall_notes'] ?? '') as String,
      );
}

class FoodItem {
  final String name;
  final String portion;
  final int calories;
  final String note;

  FoodItem({
    required this.name,
    required this.portion,
    required this.calories,
    required this.note,
  });

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        name: (j['name'] ?? '') as String,
        portion: (j['portion'] ?? '') as String,
        calories: _toInt(j['calories']),
        note: (j['note'] ?? '') as String,
      );
}

// ── Chat Message ─────────────────────────────────────────────────────
class ChatMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: (j['role'] ?? 'user') as String,
        content: (j['content'] ?? '') as String,
        timestamp: DateTime.tryParse(j['timestamp']?.toString() ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ── User Profile ─────────────────────────────────────────────────────
class UserProfile {
  final String name;
  final int age;
  final double weight; // kg
  final int height;    // cm
  final String sex;    // 'm' | 'f'
  final double activity; // multiplier
  final int calorieGoal;

  UserProfile({
    this.name = '',
    this.age = 0,
    this.weight = 0,
    this.height = 0,
    this.sex = 'm',
    this.activity = 1.55,
    this.calorieGoal = 2000,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: (j['name'] ?? '') as String,
        age: _toInt(j['age']),
        weight: _toDouble(j['weight']),
        height: _toInt(j['height']),
        sex: (j['sex'] ?? 'm') as String,
        activity: _toDouble(j['activity'], 1.55),
        calorieGoal: _toInt(j['calorieGoal'], 2000),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'weight': weight,
        'height': height,
        'sex': sex,
        'activity': activity,
        'calorieGoal': calorieGoal,
      };

  UserProfile copyWith({
    String? name,
    int? age,
    double? weight,
    int? height,
    String? sex,
    double? activity,
    int? calorieGoal,
  }) =>
      UserProfile(
        name: name ?? this.name,
        age: age ?? this.age,
        weight: weight ?? this.weight,
        height: height ?? this.height,
        sex: sex ?? this.sex,
        activity: activity ?? this.activity,
        calorieGoal: calorieGoal ?? this.calorieGoal,
      );
}
