import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'storage_service.dart';

/// Requests the Google Play in-app review prompt at a positive moment, rather
/// than on launch. Asks once, after the user's [_scanThreshold]th successful
/// scan. Google additionally rate-limits how often the system dialog appears,
/// so this can never spam the user.
class ReviewService {
  static final ReviewService _instance = ReviewService._();
  factory ReviewService() => _instance;
  ReviewService._();

  final InAppReview _inAppReview = InAppReview.instance;

  /// Number of successful scans before we consider asking for a review.
  static const int _scanThreshold = 3;

  /// Call after each successful scan. Increments the lifetime scan count and,
  /// once the threshold is reached (and we haven't asked before), requests the
  /// Play review flow. Safe to call always — it no-ops when not appropriate or
  /// when the Play flow is unavailable (e.g. sideloaded builds, emulators).
  Future<void> maybeRequestAfterScan() async {
    final storage = StorageService();
    await storage.incrementTotalScans();

    if (storage.reviewRequested) return;
    if (storage.totalSuccessfulScans < _scanThreshold) return;

    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        // Mark as asked even if Play silently suppressed the dialog (quota),
        // per Google's guidance not to call repeatedly.
        await storage.setReviewRequested();
      }
    } catch (e) {
      debugPrint('ReviewService: review request failed: $e');
    }
  }
}
