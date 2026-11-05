import 'package:flutter/material.dart';

/// Central theme definitions for the Couple App.
///
/// Implements a romantic, modern Material 3 aesthetic tailored for two partners,
/// featuring warm pastel tones (rose, blush, peach, mauve), soft rounded corners,
/// and calm typography.
class AppTheme {
  // --- Romantic & Modern Color Palette ---
  static const Color primaryRose = Color(0xFFE25266);
  static const Color primaryRoseLight = Color(0xFFFF8A9E);
  static const Color primaryRoseDark = Color(0xFFB3233F);

  static const Color secondaryBlush = Color(0xFFFFB4A2);
  static const Color tertiaryMauve = Color(0xFFB5838D);
  static const Color pastelPeach = Color(0xFFFFE5D9);
  static const Color pastelLavender = Color(0xFFE8D7F1);

  static const Color backgroundLight = Color(0xFFFFF9F9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF7ECEF);
  static const Color textPrimaryLight = Color(0xFF2B2129);
  static const Color textSecondaryLight = Color(0xFF75656D);
  static const Color outlineLight = Color(0xFFE5D5DA);

  // Dark Theme Palette
  static const Color backgroundDark = Color(0xFF140F12);
  static const Color surfaceDark = Color(0xFF1E171B);
  static const Color surfaceVariantDark = Color(0xFF2A2026);
  static const Color textPrimaryDark = Color(0xFFF7EFF2);
  static const Color textSecondaryDark = Color(0xFFAFA3A9);
  static const Color outlineDark = Color(0xFF45363F);

  // Status & Accents
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color successGreen = Color(0xFF388E3C);
  static const Color goldAccent = Color(0xFFFFB703);

  // Geometry & Radii
  static const double cardBorderRadius = 20.0;
  static const double buttonBorderRadius = 16.0;
  static const double inputBorderRadius = 14.0;
  static const double dialogBorderRadius = 24.0;

  /// Default application theme (Light theme).
  static ThemeData get themeData => lightTheme;

  /// Romantic Material 3 light theme.
  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryRose,
      brightness: Brightness.light,
      primary: primaryRose,
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFFFD9DF),
      onPrimaryContainer: const Color(0xFF3E0010),
      secondary: secondaryBlush,
      onSecondary: textPrimaryLight,
      secondaryContainer: pastelPeach,
      onSecondaryContainer: const Color(0xFF331200),
      tertiary: tertiaryMauve,
      onTertiary: Colors.white,
      tertiaryContainer: pastelLavender,
      surface: surfaceLight,
      onSurface: textPrimaryLight,
      error: errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundLight,
        foregroundColor: textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimaryLight,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0.5,
        shadowColor: primaryRose.withOpacity(0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: const BorderSide(color: outlineLight, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryRose,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryRose,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryRose,
          side: const BorderSide(color: primaryRose, width: 1.5),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryRose,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: outlineLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: outlineLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: primaryRose, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: errorRed),
        ),
        hintStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogBorderRadius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outlineLight,
        thickness: 0.8,
        space: 1,
      ),
    );
  }

  /// Romantic Material 3 dark theme.
  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryRose,
      brightness: Brightness.dark,
      primary: primaryRoseLight,
      onPrimary: const Color(0xFF5E0018),
      secondary: secondaryBlush,
      onSecondary: backgroundDark,
      tertiary: tertiaryMauve,
      surface: surfaceDark,
      onSurface: textPrimaryDark,
      error: errorRed,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundDark,
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundDark,
        foregroundColor: textPrimaryDark,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimaryDark,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardBorderRadius),
          side: const BorderSide(color: outlineDark, width: 0.8),
        ),
        clipBehavior: Clip.antiAlias,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: primaryRoseLight,
          foregroundColor: const Color(0xFF5E0018),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: outlineDark),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: outlineDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputBorderRadius),
          borderSide: const BorderSide(color: primaryRoseLight, width: 2),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogBorderRadius),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: outlineDark,
        thickness: 0.8,
        space: 1,
      ),
    );
  }
}
