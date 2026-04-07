import 'dart:convert';

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
        id: j['id'] as int,
        time: j['time'] as String,
        name: j['name'] as String,
        calories: j['calories'] as int,
        protein: j['protein'] as int,
        carbs: j['carbs'] as int,
        fat: j['fat'] as int,
        fiber: (j['fiber'] ?? 0) as int,
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
        mealName: j['meal_name'] ?? 'Unknown Meal',
        totalCalories: (j['total_calories'] ?? 0) as int,
        proteinG: (j['protein_g'] ?? 0) as int,
        carbsG: (j['carbs_g'] ?? 0) as int,
        fatG: (j['fat_g'] ?? 0) as int,
        fiberG: (j['fiber_g'] ?? 0) as int,
        items: (j['items'] as List? ?? [])
            .map((i) => FoodItem.fromJson(i as Map<String, dynamic>))
            .toList(),
        overallNotes: j['overall_notes'] ?? '',
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
        name: j['name'] ?? '',
        portion: j['portion'] ?? '',
        calories: (j['calories'] ?? 0) as int,
        note: j['note'] ?? '',
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
        role: j['role'] as String,
        content: j['content'] as String,
        timestamp: DateTime.parse(j['timestamp'] as String),
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
        name: j['name'] ?? '',
        age: (j['age'] ?? 0) as int,
        weight: (j['weight'] ?? 0.0).toDouble(),
        height: (j['height'] ?? 0) as int,
        sex: j['sex'] ?? 'm',
        activity: (j['activity'] ?? 1.55).toDouble(),
        calorieGoal: (j['calorieGoal'] ?? 2000) as int,
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
