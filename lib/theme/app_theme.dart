// lib/theme/app_theme.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Step 2: Define the Color Palette
class AppColors {
  // Primary color (deep teal)
  static const Color primary = Color(0xFF00796B);

  // Secondary color (vibrant coral)
  static const Color secondary = Color(0xFFFF7043);

  // Background color (light gray)
  static const Color background = Color(0xFFF5F5F5);

  // Card and surface color (white)
  static const Color surface = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF212121); // For headings and body
  static const Color textSecondary = Color(
    0xFF757575,
  ); // For sub-text and hints

  // Extra colors
  static const Color success = Color(0xFF4CAF50); // For success states
}

// Step 3: This is the main theme configuration for the app.
final ThemeData vibrantHorizonTheme = ThemeData(
  // 1. Color Scheme
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    secondary: AppColors.secondary,
    background: AppColors.background,
    surface: AppColors.surface,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppColors.background,

  // 2. Typography
  textTheme: GoogleFonts.latoTextTheme(), // Body font
  // 3. Component Themes
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white, // Color for back arrows and icons
    elevation: 0,
    centerTitle: true,
    titleTextStyle: GoogleFonts.montserrat(
      // Heading font
      fontSize: 20,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.secondary, // Coral color
      foregroundColor: Colors.white, // Text color
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      textStyle: GoogleFonts.montserrat(
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  ),

  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: AppColors.secondary,
  ),

  cardTheme: CardThemeData(
    elevation: 2,
    color: AppColors.surface,
    margin: const EdgeInsets.symmetric(vertical: 8.0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    hintStyle: const TextStyle(color: AppColors.textSecondary),
  ),
);
