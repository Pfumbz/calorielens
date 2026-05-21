import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Singleton service that reads steps & active calories from Health Connect (Android)
/// or HealthKit (iOS). Data stays on-device — nothing is sent to the cloud.
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  // The health data types we read
  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  static const _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  bool _isAuthorized = false;
  bool get isAuthorized => _isAuthorized;

  // Cached values for today
  int _stepsToday = 0;
  int _activeCaloriesToday = 0;

  int get stepsToday => _stepsToday;
  int get activeCaloriesToday => _activeCaloriesToday;

  /// Check if Health Connect is available on this device.
  Future<bool> isHealthConnectAvailable() async {
    try {
      if (Platform.isAndroid) {
        final status = await Health().getHealthConnectSdkStatus();
        return status == HealthConnectSdkStatus.sdkAvailable;
      }
      // iOS: HealthKit is always available on iOS devices
      if (Platform.isIOS) return true;
      return false;
    } catch (e) {
      debugPrint('HealthService: availability check failed: $e');
      return false;
    }
  }

  /// Install Health Connect (Android only) — opens the Play Store listing.
  Future<void> installHealthConnect() async {
    try {
      await Health().installHealthConnect();
    } catch (e) {
      debugPrint('HealthService: install Health Connect failed: $e');
    }
  }

  /// Request read permissions for steps and active calories.
  /// Returns true if granted.
  Future<bool> requestPermissions() async {
    try {
      final granted = await Health().requestAuthorization(
        _types,
        permissions: _permissions,
      );
      _isAuthorized = granted;
      return granted;
    } catch (e) {
      debugPrint('HealthService: permission request failed: $e');
      _isAuthorized = false;
      return false;
    }
  }

  /// Check if we already have permissions (without prompting the user).
  Future<bool> hasPermissions() async {
    try {
      final result = await Health().hasPermissions(
        _types,
        permissions: _permissions,
      );
      _isAuthorized = result ?? false;
      return _isAuthorized;
    } catch (e) {
      debugPrint('HealthService: permission check failed: $e');
      return false;
    }
  }

  /// Fetch today's steps and active calories from Health Connect.
  /// Returns a record with (steps, activeCalories).
  Future<({int steps, int activeCalories})> fetchTodayActivity() async {
    if (!_isAuthorized) {
      return (steps: _stepsToday, activeCalories: _activeCaloriesToday);
    }

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Fetch all health data points for today
      final dataPoints = await Health().getHealthDataFromTypes(
        types: _types,
        startTime: midnight,
        endTime: now,
      );

      // Aggregate steps
      int totalSteps = 0;
      int totalActiveCal = 0;
      int totalCal = 0;

      // Remove duplicates (Health Connect can return overlapping data from multiple sources)
      final unique = Health().removeDuplicates(dataPoints);

      for (final point in unique) {
        final value = point.value;
        final numericValue = value is NumericHealthValue ? value.numericValue.toInt() : 0;

        switch (point.type) {
          case HealthDataType.STEPS:
            totalSteps += numericValue;
            break;
          case HealthDataType.ACTIVE_ENERGY_BURNED:
            totalActiveCal += numericValue;
            break;
          case HealthDataType.TOTAL_CALORIES_BURNED:
            totalCal += numericValue;
            break;
          default:
            break;
        }
      }

      // Prefer ACTIVE_CALORIES_BURNED; fall back to TOTAL if active is 0
      // (some devices only report total). Subtract BMR estimate (~70 cal/hr awake).
      int activeCal = totalActiveCal;
      if (activeCal == 0 && totalCal > 0) {
        final hoursAwake = now.difference(midnight).inMinutes / 60.0;
        final estimatedBmr = (70 * hoursAwake).round();
        activeCal = (totalCal - estimatedBmr).clamp(0, 9999);
      }

      _stepsToday = totalSteps;
      _activeCaloriesToday = activeCal;

      return (steps: totalSteps, activeCalories: activeCal);
    } catch (e) {
      debugPrint('HealthService: fetch failed: $e');
      return (steps: _stepsToday, activeCalories: _activeCaloriesToday);
    }
  }

  /// Calculate the activity bonus (extra calories the user can eat).
  /// Uses the multiplier (0.0–1.0) to avoid "eating back" 100% of exercise.
  static int activityBonus(int activeCalories, double multiplier) {
    return (activeCalories * multiplier).round();
  }

  /// Reset cached values (e.g. at midnight rollover).
  void resetDaily() {
    _stepsToday = 0;
    _activeCaloriesToday = 0;
  }
}
