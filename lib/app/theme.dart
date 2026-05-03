import 'package:flutter/material.dart';

/// Pastel Park Tycoon design system colors (per design doc §121.1).
///
/// Pastel palette only — primary mint, lavender secondary, peach accent.
/// Red is minimized; danger uses rose tones.
class PastelColors {
  static const primary = Color(0xFFA8E6CF); // mint
  static const primaryDark = Color(0xFF7FCDB6);
  static const secondary = Color(0xFFCDB4F6); // lavender
  static const accent = Color(0xFFFFB5A7); // peach coral
  static const premium = Color(0xFFF6D689); // soft gold
  static const success = Color(0xFFB8E0A1); // matcha green
  static const warning = Color(0xFFFFD8A8); // cream orange
  static const danger = Color(0xFFF7B2BD); // soft rose
  static const info = Color(0xFFA8D8EA); // sky blue

  static const background = Color(0xFFFFF9F2); // cream ivory
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF5EFE6);

  static const grass = Color(0xFFD4F0DC); // mint grass
  static const grassDark = Color(0xFFB6E0BF);
  static const path = Color(0xFFEFE0C9); // light beige path
  static const pathDark = Color(0xFFD9C7AE);

  static const textPrimary = Color(0xFF4A4A4A);
  static const textSecondary = Color(0xFF7A7A7A);
  static const textMuted = Color(0xFFB0B0B0);
}

class PastelTheme {
  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: PastelColors.primary,
        primary: PastelColors.primary,
        secondary: PastelColors.secondary,
        surface: PastelColors.surface,
      ).copyWith(
        surface: PastelColors.surface,
      ),
      scaffoldBackgroundColor: PastelColors.background,
      cardTheme: const CardThemeData(
        elevation: 0,
        color: PastelColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        margin: EdgeInsets.zero,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: PastelColors.textPrimary,
        displayColor: PastelColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: PastelColors.textPrimary,
      ),
    );
  }
}
