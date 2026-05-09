import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart' as iap;

/// Google Play product ID for the CalorieLens Pro monthly subscription.
/// Must match the product ID created in Google Play Console.
const String kProMonthlyId = 'calorielens_pro_monthly';

/// All product IDs we query from the store.
const Set<String> _kProductIds = {kProMonthlyId};

/// Purchase status that the UI can react to.
enum ProPurchaseState {
  idle,
  loading,
  purchased,
  restored,
  error,
  cancelled,
}

/// ─────────────────────────────────────────────────────────────────────────────
/// PurchaseService — manages Google Play Billing subscription lifecycle.
///
/// Usage:
///   1. Call `init()` once at app start (from AppState.init)
///   2. Listen to `statusStream` for purchase state changes
///   3. Call `buyProMonthly()` from the upgrade modal
///   4. Call `restorePurchases()` from settings
///   5. Call `dispose()` when no longer needed
///
/// SETUP IN GOOGLE PLAY CONSOLE:
///   1. Go to Play Console → your app → Monetise → Subscriptions
///   2. Create a subscription with Product ID: "calorielens_pro_monthly"
///   3. Add a base plan with monthly billing period
///   4. Set the price to match your localised pricing tiers
///   5. Optionally add a 7-day free trial as an offer
///   6. Activate the subscription
/// ─────────────────────────────────────────────────────────────────────────────
class PurchaseService {
  static final PurchaseService _instance = PurchaseService._();
  factory PurchaseService() => _instance;
  PurchaseService._();

  final iap.InAppPurchase _iapInstance = iap.InAppPurchase.instance;
  StreamSubscription<List<iap.PurchaseDetails>>? _subscription;

  /// Product details fetched from the store (null until init completes).
  iap.ProductDetails? _proProduct;
  iap.ProductDetails? get proProduct => _proProduct;

  /// Whether the store is available on this device.
  bool _storeAvailable = false;
  bool get storeAvailable => _storeAvailable;

  /// Whether the user currently has an active Pro subscription.
  bool _isProActive = false;
  bool get isProActive => _isProActive;

  /// Stream that emits purchase state changes for UI feedback.
  final _stateController = StreamController<ProPurchaseState>.broadcast();
  Stream<ProPurchaseState> get stateStream => _stateController.stream;

  /// Last error message (if any).
  String? _lastError;
  String? get lastError => _lastError;

  /// Callback to activate/deactivate premium in AppState.
  /// Set by AppState during init.
  void Function(bool isPremium)? onPremiumChanged;

  // ── Initialisation ───────────────────────────────────────────────────────

  /// Initialise the purchase service. Call once at app start.
  Future<void> init() async {
    _storeAvailable = await _iapInstance.isAvailable();
    if (!_storeAvailable) {
      debugPrint('PurchaseService: Store not available');
      return;
    }

    // Listen to purchase updates
    _subscription = _iapInstance.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        debugPrint('PurchaseService: Stream error: $error');
      },
    );

    // Fetch product details from the store
    await _loadProducts();
  }

  /// Load product details from Google Play.
  Future<void> _loadProducts() async {
    try {
      final response = await _iapInstance.queryProductDetails(_kProductIds);

      if (response.error != null) {
        debugPrint('PurchaseService: Query error: ${response.error}');
        return;
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('PurchaseService: Products not found: ${response.notFoundIDs}');
        // Expected during development before the product is created
        // in Google Play Console
      }

      for (final product in response.productDetails) {
        if (product.id == kProMonthlyId) {
          _proProduct = product;
          debugPrint('PurchaseService: Found product: ${product.title} — ${product.price}');
        }
      }
    } catch (e) {
      debugPrint('PurchaseService: Failed to load products: $e');
    }
  }

  // ── Purchase flow ────────────────────────────────────────────────────────

  /// Start the purchase flow for Pro monthly subscription.
  Future<bool> buyProMonthly() async {
    if (_proProduct == null) {
      _lastError = 'Subscription not available yet. Please try again in a moment.';
      _stateController.add(ProPurchaseState.error);
      return false;
    }

    _stateController.add(ProPurchaseState.loading);

    try {
      final purchaseParam = iap.PurchaseParam(productDetails: _proProduct!);
      // buyNonConsumable is used for subscriptions
      final success = await _iapInstance.buyNonConsumable(purchaseParam: purchaseParam);
      if (!success) {
        _lastError = 'Unable to start purchase. Please try again.';
        _stateController.add(ProPurchaseState.error);
      }
      return success;
    } catch (e) {
      _lastError = 'Purchase failed: ${e.toString()}';
      _stateController.add(ProPurchaseState.error);
      return false;
    }
  }

  /// Restore previous purchases (e.g. after reinstall or new device).
  Future<void> restorePurchases() async {
    _stateController.add(ProPurchaseState.loading);
    try {
      await _iapInstance.restorePurchases();
      // If no purchases are restored, the stream won't emit — set a timeout
      Future.delayed(const Duration(seconds: 5), () {
        if (!_isProActive) {
          _lastError = 'No active subscription found.';
          _stateController.add(ProPurchaseState.error);
        }
      });
    } catch (e) {
      _lastError = 'Could not restore purchases: ${e.toString()}';
      _stateController.add(ProPurchaseState.error);
    }
  }

  // ── Purchase stream handler ──────────────────────────────────────────────

  void _onPurchaseUpdate(List<iap.PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(iap.PurchaseDetails purchase) async {
    if (purchase.productID != kProMonthlyId) return;

    switch (purchase.status) {
      case iap.PurchaseStatus.pending:
        _stateController.add(ProPurchaseState.loading);
        break;

      case iap.PurchaseStatus.purchased:
        await _verifyAndDeliver(purchase);
        break;

      case iap.PurchaseStatus.restored:
        await _verifyAndDeliver(purchase, isRestore: true);
        break;

      case iap.PurchaseStatus.error:
        _lastError = purchase.error?.message ?? 'Purchase failed. Please try again.';
        _stateController.add(ProPurchaseState.error);
        if (purchase.pendingCompletePurchase) {
          await _iapInstance.completePurchase(purchase);
        }
        break;

      case iap.PurchaseStatus.canceled:
        _stateController.add(ProPurchaseState.cancelled);
        break;
    }
  }

  /// Verify the purchase and deliver premium access.
  ///
  /// In production, you should verify the purchase token server-side
  /// via Google Play Developer API. For now, we trust the client-side
  /// verification from the in_app_purchase plugin.
  Future<void> _verifyAndDeliver(iap.PurchaseDetails purchase, {bool isRestore = false}) async {
    // TODO: For production, add server-side verification:
    // Send purchase.verificationData.serverVerificationData to a Supabase
    // Edge Function that calls the Google Play Developer API to verify.

    _isProActive = true;
    onPremiumChanged?.call(true);

    _stateController.add(isRestore ? ProPurchaseState.restored : ProPurchaseState.purchased);

    // Complete the purchase (required by Google Play)
    if (purchase.pendingCompletePurchase) {
      await _iapInstance.completePurchase(purchase);
    }

    debugPrint('PurchaseService: Pro ${isRestore ? "restored" : "purchased"} successfully');
  }

  // ── Subscription management ──────────────────────────────────────────────

  /// Get the store price string for Pro (e.g. "$4.99" or "R79.99").
  /// Returns null if the product hasn't loaded yet.
  String? get proPrice => _proProduct?.price;

  /// Check if we have a valid product loaded from the store.
  bool get hasProduct => _proProduct != null;

  // ── Cleanup ──────────────────────────────────────────────────────────────

  void dispose() {
    _subscription?.cancel();
    _stateController.close();
  }
}
