import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Result from an Open Food Facts barcode lookup.
class BarcodeResult {
  final String barcode;
  final String productName;
  final String? brand;
  final String? imageUrl;
  final String? servingSize;       // e.g. "30g", "1 cup (240ml)"
  final String? packageSize;       // e.g. "500g", "1L"
  final ScanResult? nutrition; // null if nutrition data unavailable

  BarcodeResult({
    required this.barcode,
    required this.productName,
    this.brand,
    this.imageUrl,
    this.servingSize,
    this.packageSize,
    this.nutrition,
  });

  /// Human-readable label: "Brand – Product" or just "Product".
  String get displayName =>
      brand != null && brand!.isNotEmpty ? '$brand – $productName' : productName;
}

class OpenFoodFactsService {
  static const _baseUrl = 'https://world.openfoodfacts.org/api/v2/product';

  /// Looks up a barcode and returns product + nutrition data.
  /// Returns null if the product is not found.
  static Future<BarcodeResult?> lookup(String barcode) async {
    try {
      final url = '$_baseUrl/$barcode.json?fields='
          'product_name,brands,image_front_small_url,'
          'nutriments,serving_size,product_quantity';

      final res = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'CalNova/1.0 (pcmacstudios@gmail.com)'},
      );

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['status'] != 1) return null; // product not found

      final product = data['product'] as Map<String, dynamic>? ?? {};
      final name = (product['product_name'] as String?)?.trim() ?? '';
      if (name.isEmpty) return null;

      final brand = (product['brands'] as String?)?.trim();
      final imageUrl = product['image_front_small_url'] as String?;
      final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};
      final servingSize = product['serving_size'] as String?;

      // Try to extract per-serving values first, fall back to per-100g
      // When using per-100g, scale to actual serving/package size
      final servingGrams = _parseGrams(servingSize);
      final packageGrams = _parseGrams(
          (product['product_quantity'] as dynamic)?.toString());
      // Use serving size for scaling; if unavailable, use package size (single-serve products)
      final scaleGrams = servingGrams ?? packageGrams;

      final calories = _nutriment(nutriments, 'energy-kcal', scaleGrams: scaleGrams);
      final protein = _nutriment(nutriments, 'proteins', scaleGrams: scaleGrams);
      final carbs = _nutriment(nutriments, 'carbohydrates', scaleGrams: scaleGrams);
      final fat = _nutriment(nutriments, 'fat', scaleGrams: scaleGrams);
      final fiber = _nutriment(nutriments, 'fiber', scaleGrams: scaleGrams);

      ScanResult? nutrition;
      if (calories != null) {
        final portionLabel = servingSize ?? '1 serving';
        nutrition = ScanResult(
          mealName: brand != null && brand.isNotEmpty
              ? '$brand $name'
              : name,
          totalCalories: calories,
          proteinG: protein ?? 0,
          carbsG: carbs ?? 0,
          fatG: fat ?? 0,
          fiberG: fiber ?? 0,
          items: [
            FoodItem(
              name: name,
              portion: portionLabel,
              calories: calories,
              note: brand != null ? 'Brand: $brand' : '',
            ),
          ],
          overallNotes: 'Nutrition data from Open Food Facts database'
              '${servingSize != null ? ' (serving: $servingSize)' : ''}.',
        );
      }

      final packageQuantity = (product['product_quantity'] as dynamic)?.toString();

      return BarcodeResult(
        barcode: barcode,
        productName: name,
        brand: brand,
        imageUrl: imageUrl,
        servingSize: servingSize,
        packageSize: packageQuantity,
        nutrition: nutrition,
      );
    } catch (e) {
      debugPrint('Open Food Facts lookup error: $e');
      return null;
    }
  }

  /// Extracts a nutriment value, preferring per-serving over per-100g.
  /// When using per-100g fallback, scales to [scaleGrams] if provided.
  static int? _nutriment(Map<String, dynamic> n, String key, {double? scaleGrams}) {
    // Try per-serving first (already scaled to one serving)
    final serving = n['${key}_serving'];
    if (serving != null) return (serving as num).round();
    // Fall back to per-100g, scaled to actual serving/package size
    final per100 = n['${key}_100g'];
    if (per100 != null) {
      if (scaleGrams != null && scaleGrams > 0) {
        return ((per100 as num) * scaleGrams / 100).round();
      }
      return (per100 as num).round(); // no size info — assume 100g
    }
    return null;
  }

  /// Parses a weight string like "60g", "500ml", "1.5kg" into grams.
  static double? _parseGrams(String? s) {
    if (s == null || s.isEmpty) return null;
    final match = RegExp(r'([\d.]+)\s*(kg|g|l|ml)?', caseSensitive: false).firstMatch(s);
    if (match == null) return null;
    final num = double.tryParse(match.group(1)!);
    if (num == null) return null;
    final unit = (match.group(2) ?? 'g').toLowerCase();
    if (unit == 'kg' || unit == 'l') return num * 1000;
    return num; // g or ml
  }
}
