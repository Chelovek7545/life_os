import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.scaffoldBackgroundColor,
      primaryColor: AppColors.primary,
      colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryContainer,
          brightness: Brightness.dark
        ).copyWith(
        surface: AppColors.surfaceDim,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surfaceContainerLow: AppColors.surfaceContainerLow
      ),
      // Настройка глобального текстового филда под стиль Glass
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputGlass,
        contentPadding: const EdgeInsets.all(24),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderGlass),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.inputBorderGlass),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryContainer),
        ),
      ),
    );
  }
}