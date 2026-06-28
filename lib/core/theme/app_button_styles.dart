import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class AppButtonStyles {
  static ButtonStyle get saveButton => FilledButton.styleFrom(
    
    //minimumSize: const Size(double.infinity, 48),
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.lg,
    ),

    backgroundColor: AppColors.primaryContainer,
  );

  static ButtonStyle get baseButtonStyle =>
      OutlinedButton.styleFrom(
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF2A2A2A), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 28),
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.06)),
        iconColor: const WidgetStatePropertyAll(Color(0xFFFFB39B)),
      );
}
