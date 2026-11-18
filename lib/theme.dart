import 'package:flutter/material.dart';

/// ألوان Depo
class DepoColors {
  static const brand = Color(0xFF4BCDDB); // الفيروزي الأساسي
  static const dark = Color(0xFF0E7F8A); // الأزرار والروابط
  static const ink = Color(0xFF06363C); // النصوص
  static const muted = Color(0xFF4A6B70);
  static const bg = Color(0xFFF4FDFE);
  static const soft = Color(0xFFE3F8FA);
  static const line = Color(0xFFDDF3F6);
  static const accent = Color(0xFFF5A524); // شارات الخصم
  static const success = Color(0xFF17663F);
  static const successBg = Color(0xFFE9F8F0);
  static const danger = Color(0xFF9B1C20);
}

ThemeData buildDepoTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Tajawal',
    colorScheme: ColorScheme.fromSeed(
      seedColor: DepoColors.brand,
      primary: DepoColors.dark,
      surface: DepoColors.bg,
    ),
    scaffoldBackgroundColor: DepoColors.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: DepoColors.ink,
      displayColor: DepoColors.ink,
      fontFamily: 'Tajawal',
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: DepoColors.bg,
      foregroundColor: DepoColors.ink,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Tajawal',
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: DepoColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DepoColors.dark,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: DepoColors.dark,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: DepoColors.dark, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DepoColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DepoColors.line, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: DepoColors.brand, width: 1.5),
      ),
    ),
  );
}
