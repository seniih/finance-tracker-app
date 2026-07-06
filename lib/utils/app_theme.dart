import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,

      scaffoldBackgroundColor: AppColors.background,

      colorScheme: const ColorScheme.light().copyWith(
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),

      textTheme: AppTypography.textTheme,

      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}