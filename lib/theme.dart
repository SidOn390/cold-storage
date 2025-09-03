import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors
  static const Color primary   = Color(0xFF00897B); // teal
  static const Color secondary = Color(0xFFFFA000); // amber

  // Light theme
  static final ThemeData light = ThemeData(
    brightness: Brightness.light,
    primaryColor: primary,
    colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.teal)
        .copyWith(secondary: secondary),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.all(primary),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primary),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
  );
}
