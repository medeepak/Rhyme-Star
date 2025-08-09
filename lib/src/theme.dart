import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

ThemeData buildTheme() {
  final baseTextTheme = GoogleFonts.baloo2TextTheme();
  
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF4FC3F7), // Turquoise primary color
    brightness: Brightness.light,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    textTheme: baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(fontWeight: FontWeight.w900),
      displayMedium: baseTextTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900),
      displaySmall: baseTextTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900),
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
      titleLarge: baseTextTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      titleSmall: baseTextTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w900),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontWeight: FontWeight.w900),
      labelLarge: baseTextTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
      labelMedium: baseTextTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
      labelSmall: baseTextTheme.labelSmall?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

// Rhyme Star Color Palette
class RhymeStarColors {
  static const Color primaryTurquoise = Color(0xFF4FC3F7);
  static const Color backgroundTeal = Color(0xFF26C6DA);
  static const Color titleBlue = Color(0xFF1976D2);
  static const Color titleOrange = Color(0xFFFF8A65);
  static const Color titleGreen = Color(0xFF66BB6A);
  static const Color starYellow = Color(0xFFFFC107);
  static const Color starOrange = Color(0xFFFF9800);
  static const Color starPink = Color(0xFFE91E63);
  static const Color starGreen = Color(0xFF4CAF50);
  static const Color loadingYellow = Color(0xFFFDD835);
  static const Color hillGreen = Color(0xFF81C784);
  static const Color hillDarkGreen = Color(0xFF66BB6A);
}
