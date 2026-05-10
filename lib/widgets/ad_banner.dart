import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';

/// A reusable AdMob banner widget.
/// Automatically hides for Premium and BYOK (API key) users.
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  static String get _adUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-5237846834490979/9754446561'; // Android production banner
    } else {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS test banner (update when iOS goes live)
    }
  }

  @override
  void initState() {
    super.initState();
    // Only load ads for free-tier users
    final state = context.read<AppState>();
    if (state.isPremium || state.hasApiKey) return;
    _loadAd();
  }

  void _loadAd() {
    // Use adaptive banner for full-width fit, fall back to standard 320x50
    final screenWidth = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width /
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final adWidth = (screenWidth - 72).clamp(280, 460).toInt(); // account for padding
    final adSize = AdSize(width: adWidth, height: 50);

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      size: adSize,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('AdBanner failed to load: ${error.message}');
          ad.dispose();
          _bannerAd = null;
          // Retry with standard 320x50 size as fallback
          if (mounted) {
            _bannerAd = BannerAd(
              adUnitId: _adUnitId,
              size: AdSize.banner,
              request: const AdRequest(),
              listener: BannerAdListener(
                onAdLoaded: (ad) {
                  if (mounted) setState(() => _isLoaded = true);
                },
                onAdFailedToLoad: (ad, err) {
                  ad.dispose();
                  if (mounted) setState(() => _bannerAd = null);
                },
              ),
            )..load();
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hide ads for Pro / BYOK users
    final state = context.watch<AppState>();
    if (state.isPremium || state.hasApiKey) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CLColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
