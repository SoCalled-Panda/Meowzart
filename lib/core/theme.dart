import 'package:flutter/material.dart';

/// Palette shared with `documents/visual_assets.md`. Keep the two in sync.
abstract final class AppColors {
  static const Color nightPlum = Color(0xFF2B2440);
  static const Color duskViolet = Color(0xFF4A3B6B);
  static const Color lampAmber = Color(0xFFFFC98B);
  static const Color milkCream = Color(0xFFFFF4E3);
  static const Color pawPink = Color(0xFFFF8FB1);
  static const Color mint = Color(0xFF7ADCC9);
  static const Color butter = Color(0xFFFFE27A);
  static const Color rainBlue = Color(0xFF8FB8FF);

  /// Lane order matches `kLaneCount`: pink, mint, butter, blue.
  static const List<Color> laneColors = [pawPink, mint, butter, rainBlue];

  static const Color starGold = Color(0xFFFFD76A);
  static const Color starEmpty = Color(0xFF6B5F8C);
}

/// The mood bar fill runs mint -> amber -> pink.
const LinearGradient kMoodGradient = LinearGradient(
  colors: [AppColors.mint, AppColors.lampAmber, AppColors.pawPink],
);

abstract final class AppTheme {
  /// Pixelify Sans — bundled in `assets/fonts/` and recorded in
  /// `assets/LICENSES.md`. Matches the pixel-art look of the whole drop.
  static const String fontFamily = 'Pixelify Sans';

  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.nightPlum,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.lampAmber,
        secondary: AppColors.pawPink,
        surface: AppColors.nightPlum,
        onPrimary: AppColors.nightPlum,
        onSurface: AppColors.milkCream,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: fontFamily,
        bodyColor: AppColors.milkCream,
        displayColor: AppColors.milkCream,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lampAmber,
          foregroundColor: AppColors.nightPlum,
          minimumSize: const Size(220, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontSize: 20),
        ),
      ),
    );
  }
}
