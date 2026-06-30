import 'dart:io';

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      //Чтобы были одинаковые отступы и т.д
      visualDensity: VisualDensity.standard,
      brightness: Brightness.dark,
      //scaffoldBackgroundColor: AppColors.scaffoldBackgroundColor,
      primaryColor: AppColors.primary,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.primaryContainer,
            brightness: Brightness.dark,
          ).copyWith(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            primaryContainer: AppColors.primaryContainer,
            onPrimaryContainer: Colors.white,
            secondary: AppColors.secondary,

            surface: AppColors.surface,
            surfaceBright: AppColors.surfaceBright,
            surfaceDim: AppColors.surfaceDim,
            onSurface: AppColors.onSurface,
            onSurfaceVariant: AppColors.onSurfaceVariant,

            surfaceContainerHigh: AppColors.surfaceContainerHigh,
            surfaceContainerLow: AppColors.surfaceContainerLow,

            outline: AppColors.inputBorderGlass,
            outlineVariant: AppColors.borderGlass,
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
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          textStyle: AppTypography.codeLabel,
        ),
      ),

      textTheme: TextTheme(
        displayLarge: AppTypography.displayXL,
        headlineLarge: Platform.isAndroid
            ? AppTypography.headlineLgMobile
            : AppTypography.headlineLg,
        bodyMedium: AppTypography.bodyMd,
        bodySmall: AppTypography.bodySm,
        labelMedium: AppTypography.codeLabel,
      ),
    );
  }
}
