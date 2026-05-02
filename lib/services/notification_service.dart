import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

/// Handles local push notifications for meal reminders and coaching nudges.
///
/// Meal reminders: scheduled daily at user-chosen times for breakfast, lunch, dinner.
/// Coaching nudges: triggered by the app based on diary progress (e.g. under calorie goal).
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialised = false;

  // Notification channel
  static const _channelId = 'calorielens_reminders';
  static const _channelName = 'Meal Reminders';
  static const _channelDesc = 'Reminders to log your meals and coaching nudges';

  // Notification IDs (fixed per type so we can cancel/replace them)
  static const _breakfastId = 100;
  static const _lunchId = 101;
  static const _dinnerId = 102;
  static const _nudgeId = 200;

  // SharedPreferences keys
  static const _keyRemindersOn = 'notif_reminders_on';
  static const _keyNudgesOn = 'notif_nudges_on';
  static const _keyBreakfastHour = 'notif_breakfast_hour';
  static const _keyBreakfastMin = 'notif_breakfast_min';
  static const _keyLunchHour = 'notif_lunch_hour';
  static const _keyLunchMin = 'notif_lunch_min';
  static const _keyDinnerHour = 'notif_dinner_hour';
  static const _keyDinnerMin = 'notif_dinner_min';

  // ── Initialise ────────────────────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialised) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    _initialised = true;
  }

  // ── Request permission (Android 13+) ──────────────────────────────────────
  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true; // iOS handles via DarwinInitializationSettings
  }

  // ── Preferences ───────────────────────────────────────────────────────────
  static Future<bool> get remindersEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRemindersOn) ?? false;
  }

  static Future<bool> get nudgesEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyNudgesOn) ?? false;
  }

  static Future<void> setRemindersEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRemindersOn, value);
    if (value) {
      await scheduleAllMealReminders();
    } else {
      await cancelMealReminders();
    }
  }

  static Future<void> setNudgesEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNudgesOn, value);
    if (!value) {
      await _plugin.cancel(_nudgeId);
    }
  }

  // ── Get/Set reminder times ────────────────────────────────────────────────
  static Future<TimeOfDay> getReminderTime(String meal) async {
    final prefs = await SharedPreferences.getInstance();
    switch (meal) {
      case 'breakfast':
        return TimeOfDay(
          hour: prefs.getInt(_keyBreakfastHour) ?? 8,
          minute: prefs.getInt(_keyBreakfastMin) ?? 0,
        );
      case 'lunch':
        return TimeOfDay(
          hour: prefs.getInt(_keyLunchHour) ?? 12,
          minute: prefs.getInt(_keyLunchMin) ?? 30,
        );
      case 'dinner':
        return TimeOfDay(
          hour: prefs.getInt(_keyDinnerHour) ?? 18,
          minute: prefs.getInt(_keyDinnerMin) ?? 30,
        );
      default:
        return const TimeOfDay(hour: 12, minute: 0);
    }
  }

  static Future<void> setReminderTime(String meal, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    switch (meal) {
      case 'breakfast':
        await prefs.setInt(_keyBreakfastHour, time.hour);
        await prefs.setInt(_keyBreakfastMin, time.minute);
        break;
      case 'lunch':
        await prefs.setInt(_keyLunchHour, time.hour);
        await prefs.setInt(_keyLunchMin, time.minute);
        break;
      case 'dinner':
        await prefs.setInt(_keyDinnerHour, time.hour);
        await prefs.setInt(_keyDinnerMin, time.minute);
        break;
    }
    // Reschedule if reminders are on
    if (await remindersEnabled) {
      await scheduleAllMealReminders();
    }
  }

  // ── Schedule meal reminders ───────────────────────────────────────────────
  static Future<void> scheduleAllMealReminders() async {
    await _scheduleMealReminder(
      id: _breakfastId,
      meal: 'breakfast',
      title: 'Good morning! ☀️',
      body: 'Time to log your breakfast and start the day right.',
    );
    await _scheduleMealReminder(
      id: _lunchId,
      meal: 'lunch',
      title: 'Lunch time! 🍝',
      body: 'Don\'t forget to log what you\'re having for lunch.',
    );
    await _scheduleMealReminder(
      id: _dinnerId,
      meal: 'dinner',
      title: 'Dinner reminder 🌙',
      body: 'Log your dinner to stay on track with your goals.',
    );
  }

  static Future<void> _scheduleMealReminder({
    required int id,
    required String meal,
    required String title,
    required String body,
  }) async {
    final time = await getReminderTime(meal);
    final now = tz.TZDateTime.now(tz.local);

    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );

    // If the time has already passed today, schedule for tomorrow
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeats daily
    );
  }

  static Future<void> cancelMealReminders() async {
    await _plugin.cancel(_breakfastId);
    await _plugin.cancel(_lunchId);
    await _plugin.cancel(_dinnerId);
  }

  // ── Coaching nudges ───────────────────────────────────────────────────────
  /// Call this when the app opens or diary changes to check if a nudge is needed.
  /// [caloriesEaten] = total calories logged today
  /// [calorieGoal] = user's daily target
  /// [waterGlasses] = glasses of water logged today
  static Future<void> checkAndScheduleNudge({
    required int caloriesEaten,
    required int calorieGoal,
    required int waterGlasses,
  }) async {
    if (!(await nudgesEnabled)) return;

    final now = TimeOfDay.now();
    final remaining = calorieGoal - caloriesEaten;

    String? title;
    String? body;

    // Afternoon check (2-4pm): if very few calories logged, nudge
    if (now.hour >= 14 && now.hour < 16 && caloriesEaten < calorieGoal * 0.3) {
      title = 'Heads up! 💡';
      body = 'You\'ve only logged $caloriesEaten kcal today. Remember to track your meals for accurate insights.';
    }
    // Evening check (7-9pm): summary nudge
    else if (now.hour >= 19 && now.hour < 21) {
      if (remaining > 300) {
        title = 'You\'re $remaining kcal under your goal 🎯';
        body = 'Make sure you\'re eating enough! Log your dinner if you haven\'t already.';
      } else if (remaining < -200) {
        final over = -remaining;
        title = 'You\'re ${over} kcal over your goal';
        body = 'No worries — tomorrow is a fresh start. Staying aware is what matters!';
      }
    }
    // Water reminder (anytime, if less than 3 glasses by afternoon)
    else if (now.hour >= 13 && now.hour < 15 && waterGlasses < 3) {
      title = 'Stay hydrated! 💧';
      body = 'You\'ve only had $waterGlasses glasses of water today. Try to drink a few more.';
    }

    if (title != null && body != null) {
      // Schedule 1 minute from now (so it appears shortly)
      final nudgeTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
      await _plugin.zonedSchedule(
        _nudgeId,
        title,
        body,
        nudgeTime,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // ── Random motivational messages (for variety) ────────────────────────────
  static final _motivationalMessages = [
    'Every meal logged is a step toward your goals!',
    'Consistency beats perfection. Keep tracking!',
    'You\'re doing great — one meal at a time.',
    'Small choices add up. Log your meal!',
    'Your future self will thank you for tracking today.',
  ];

  static String get randomMotivation =>
      _motivationalMessages[Random().nextInt(_motivationalMessages.length)];

  // ── Cancel all ────────────────────────────────────────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
