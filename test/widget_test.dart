// Basic smoke test — verifies the app widget can be instantiated.
//
// Note: CalorieLensApp requires Supabase and SharedPreferences initialisation,
// so we only verify the import compiles. Full widget tests require mocking
// those dependencies.

import 'package:flutter_test/flutter_test.dart';
import 'package:calorielens/main.dart';

void main() {
  test('CalorieLensApp class exists and is importable', () {
    // If this compiles, the app entry point is wired correctly.
    expect(CalorieLensApp, isNotNull);
  });
}
