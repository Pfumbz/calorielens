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
  final ScanResult? nutrition; // null if nutrition data unavailable

  BarcodeResult({
    required this.barcode,
    required this.productName,
    this.brand,
    this.imageUrl,
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
        headers: {'User-Agent': 'CalorieLens/1.0 (makhuvhap.c@gmail.com)'},
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
      final calories = _nutriment(nutriments, 'energy-kcal');
      final protein = _nutriment(nutriments, 'proteins');
      final carbs = _nutriment(nutriments, 'carbohydrates');
      final fat = _nutriment(nutriments, 'fat');
      final fiber = _nutriment(nutriments, 'fiber');

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

      return BarcodeResult(
        barcode: barcode,
        productName: name,
        brand: brand,
        imageUrl: imageUrl,
        nutrition: nutrition,
      );
    } catch (e) {
      debugPrint('Open Food Facts lookup error: $e');
      return null;
    }
  }

  /// Extracts a nutriment value, preferring per-serving over per-100g.
  static int? _nutriment(Map<String, dynamic> n, String key) {
    // Try per-serving first
    final serving = n['${key}_serving'];
    if (serving != null) return (serving as num).round();
    // Fall back to per-100g
    final per100 = n['${key}_100g'];
    if (per100 != null) return (per100 as num).round();
    return null;
  }
}
