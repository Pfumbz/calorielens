import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for searching food photos via the Pexels API.
/// Free tier: 200 requests/hour, 20,000/month.
/// Photos are cached locally by query to avoid repeated API calls.
class PexelsService {
  // Free Pexels API key — rate-limited, not billing-sensitive
  static const _apiKey = 'uadAkz7oUjcuS9EQnNjC2g71Y2kFO2U5VlLpGzmN2o7fol2EFfzSG0jX';
  static const _baseUrl = 'https://api.pexels.com/v1/search';
  static const _cachePrefix = 'pexels_cache_';

  /// Searches Pexels for a food photo matching the given query.
  /// Returns the medium-size image URL, or null if not found.
  /// Results are cached locally so the same query never hits the API twice.
  static Future<String?> searchFoodPhoto(String query) async {
    // Normalise the query for caching
    final cacheKey = _cachePrefix + query.toLowerCase().trim().replaceAll(RegExp(r'\s+'), '_');

    // Check cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) return cached.isEmpty ? null : cached;
    } catch (_) {}

    // Search Pexels
    try {
      final searchQuery = '$query food'; // Append "food" to improve relevance
      final url = Uri.parse('$_baseUrl?query=${Uri.encodeComponent(searchQuery)}&per_page=5&orientation=landscape');

      final res = await http.get(url, headers: {
        'Authorization': _apiKey,
      });

      if (res.statusCode != 200) {
        debugPrint('Pexels API error: ${res.statusCode}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final photos = data['photos'] as List? ?? [];

      if (photos.isEmpty) {
        // Cache the miss so we don't retry
        _cacheResult(cacheKey, '');
        return null;
      }

      // Pick a photo deterministically based on query hash (consistent results)
      final index = query.hashCode.abs() % photos.length;
      final photo = photos[index] as Map<String, dynamic>;
      final src = photo['src'] as Map<String, dynamic>? ?? {};
      final imageUrl = (src['medium'] ?? src['large'] ?? src['original']) as String?;

      if (imageUrl != null) {
        _cacheResult(cacheKey, imageUrl);
      }

      return imageUrl;
    } catch (e) {
      debugPrint('Pexels search error: $e');
      return null;
    }
  }

  /// Batch-fetch images for multiple meal names.
  /// Returns a map of mealName → imageUrl.
  static Future<Map<String, String>> searchMultiple(List<String> queries) async {
    final results = <String, String>{};
    for (final q in queries) {
      final url = await searchFoodPhoto(q);
      if (url != null) results[q] = url;
    }
    return results;
  }

  static Future<void> _cacheResult(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {}
  }

  /// Clears all cached Pexels image URLs.
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
      for (final k in keys) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}
