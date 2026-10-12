import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const pine = Color(0xFF153D35);
  static const deepPine = Color(0xFF0A2722);
  static const yellow = Color(0xFFF4D572);
  static const cream = Color(0xFFFAF7EF);
  static const mint = Color(0xFFB6D4BD);
  static const river = Color(0xFF92C5CE);
  static const ink = Color(0xFF18352E);
  static const muted = Color(0xFF68786F);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.pine,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.pine,
      secondary: AppColors.yellow,
      surface: AppColors.cream,
      onSurface: AppColors.ink,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.pine,
          foregroundColor: AppColors.cream,
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}