import 'package:flutter/material.dart';

class CLColors {
  static const bg      = Color(0xFF0C0B09);
  static const surface = Color(0xFF171512);
  static const surface2= Color(0xFF1F1D19);
  static const surface3= Color(0xFF262420);
  static const border  = Color(0xFF2A2820);
  static const borderB = Color(0xFF363330);
  static const text    = Color(0xFFEDE8DF);
  static const muted   = Color(0xFF6A6358);
  static const muted2  = Color(0xFF4A453D);
  static const accent  = Color(0xFFD07830);
  static const accentDim= Color(0xFF7A4418);
  static const accentLo= Color(0xFF2A1A08);
  static const green   = Color(0xFF7AAA62);
  static const greenLo = Color(0xFF162010);
  static const blue    = Color(0xFF5A8FC2);
  static const blueLo  = Color(0xFF0E1E30);
  static const red     = Color(0xFFC45252);
  static const redLo   = Color(0xFF2A0E0E);
  static const gold    = Color(0xFFC4A040);
  static const goldLo  = Color(0xFF241A04);
  static const purple  = Color(0xFF9070C0);
  static const purpleLo= Color(0xFF1A1030);
}

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: CLColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: CLColors.accent,
    surface: CLColors.surface,
    onSurface: CLColors.text,
  ),
  fontFamily: 'sans-serif',
  appBarTheme: const AppBarTheme(
    backgroundColor: CLColors.bg,
    foregroundColor: CLColors.text,
    elevation: 0,
    centerTitle: false,
    titleTextStyle: TextStyle(
      color: CLColors.text,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF0E0E0E),
    selectedItemColor: CLColors.accent,
    unselectedItemColor: CLColors.muted,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
    selectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
    unselectedLabelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: CLColors.surface2,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: CLColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: CLColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: CLColors.accent),
    ),
    hintStyle: const TextStyle(color: CLColors.muted, fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: CLColors.accent,
      foregroundColor: const Color(0xFF12100D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      textStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        letterSpacing: 0.5,
      ),
    ),
  ),
  cardTheme: const CardThemeData(
    color: CLColors.surface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: CLColors.border),
    ),
  ),
  dividerColor: CLColors.border,
  textTheme: const TextTheme(
    headlineLarge: TextStyle(color: CLColors.text, fontSize: 28, fontWeight: FontWeight.w600),
    headlineMedium: TextStyle(color: CLColors.text, fontSize: 22, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(color: CLColors.text, fontSize: 17, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(color: CLColors.text, fontSize: 15, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(color: CLColors.text, fontSize: 15),
    bodyMedium: TextStyle(color: CLColors.muted, fontSize: 13),
    bodySmall: TextStyle(color: CLColors.muted, fontSize: 11),
  ),
);
