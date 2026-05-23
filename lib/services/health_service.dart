import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

/// Singleton service that reads steps & active calories from Health Connect (Android)
/// or HealthKit (iOS). Data stays on-device — nothing is sent to the cloud.
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  // Single Health instance — reused across the app (required since health v10+)
  final _health = Health();
  bool _configured = false;

  // The health data types we read
  // Note: TOTAL_CALORIES_BURNED is optional — requested separately so it
  // doesn't block STEPS + ACTIVE if unsupported on older HC versions.
  static const _coreTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  static const _corePermissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  static const _extraTypes = [
    HealthDataType.TOTAL_CALORIES_BURNED,
  ];

  static const _extraPermissions = [
    HealthDataAccess.READ,
  ];

  // Combined list for data fetching (only includes types we got permission for)
  List<HealthDataType> _grantedTypes = [];

  bool _isAuthorized = false;
  bool get isAuthorized => _isAuthorized;

  // Cached values for today
  int _stepsToday = 0;
  int _activeCaloriesToday = 0;

  int get stepsToday => _stepsToday;
  int get activeCaloriesToday => _activeCaloriesToday;

  /// Ensure the Health plugin is configured before use (required since v10).
  Future<void> _ensureConfigured() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
      debugPrint('HealthService: Health plugin configured');
    }
  }

  /// Check if Health Connect is available on this device.
  Future<bool> isHealthConnectAvailable() async {
    try {
      await _ensureConfigured();
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        debugPrint('HealthService: SDK status = $status');
        if (status == HealthConnectSdkStatus.sdkAvailable ||
            status == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
          return true;
        }
        // For any other status, still try — the SDK status check can give
        // false negatives due to package visibility restrictions on Android 11+.
        debugPrint('HealthService: SDK status not explicitly available ($status), '
            'will attempt permissions anyway');
        return true;
      }
      // iOS: HealthKit is always available on iOS devices
      if (Platform.isIOS) return true;
      return false;
    } catch (e) {
      debugPrint('HealthService: availability check failed: $e');
      if (Platform.isAndroid) return true;
      return false;
    }
  }

  /// Install Health Connect (Android only) — opens the Play Store listing.
  Future<void> installHealthConnect() async {
    try {
      await _ensureConfigured();
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('HealthService: install Health Connect failed: $e');
    }
  }

  /// Request read permissions for steps and active calories.
  /// Returns true if core permissions (steps + active cal) are granted.
  /// Also tries to get TOTAL_CALORIES_BURNED but doesn't fail if unavailable.
  Future<bool> requestPermissions() async {
    try {
      await _ensureConfigured();

      // Request core permissions (steps + active calories)
      debugPrint('HealthService: requesting core permissions for $_coreTypes');
      final coreGranted = await _health.requestAuthorization(
        _coreTypes,
        permissions: _corePermissions,
      );
      debugPrint('HealthService: core permissions granted = $coreGranted');

      if (!coreGranted) {
        _isAuthorized = false;
        return false;
      }

      // Track which types we have permission for
      _grantedTypes = List.from(_coreTypes);

      // Try to also get TOTAL_CALORIES_BURNED (optional — fallback data source)
      try {
        final extraGranted = await _health.requestAuthorization(
          _extraTypes,
          permissions: _extraPermissions,
        );
        if (extraGranted) {
          _grantedTypes.addAll(_extraTypes);
          debugPrint('HealthService: extra permissions (TOTAL_CALORIES_BURNED) also granted');
        } else {
          debugPrint('HealthService: extra permissions not granted, continuing without');
        }
      } catch (e) {
        debugPrint('HealthService: extra permissions failed (non-critical): $e');
      }

      _isAuthorized = true;
      return true;
    } catch (e) {
      debugPrint('HealthService: permission request failed: $e');
      _isAuthorized = false;
      return false;
    }
  }

  /// Check if we already have permissions (without prompting the user).
  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      final result = await _health.hasPermissions(
        _coreTypes,
        permissions: _corePermissions,
      );
      _isAuthorized = result ?? false;
      if (_isAuthorized && _grantedTypes.isEmpty) {
        _grantedTypes = List.from(_coreTypes);
        // Also check extra types
        final extraResult = await _health.hasPermissions(
          _extraTypes,
          permissions: _extraPermissions,
        );
        if (extraResult == true) {
          _grantedTypes.addAll(_extraTypes);
        }
      }
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
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Fetch health data for today using only the types we have permission for
      final typesToFetch = _grantedTypes.isNotEmpty ? _grantedTypes : _coreTypes;
      final dataPoints = await _health.getHealthDataFromTypes(
        types: typesToFetch,
        startTime: midnight,
        endTime: now,
      );

      // Aggregate steps
      int totalSteps = 0;
      int totalActiveCal = 0;
      int totalCal = 0;

      // Remove duplicates (Health Connect can return overlapping data from multiple sources)
      final unique = _health.removeDuplicates(dataPoints);

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
