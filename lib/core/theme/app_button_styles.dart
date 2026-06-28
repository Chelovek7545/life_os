import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';

class AppButtonStyles {
  static ButtonStyle get saveButton => FilledButton.styleFrom(
    //minimumSize: const Size(double.infinity, 48),
    minimumSize: const Size(0, 0), // Убираем минимальный размер
    // Максимальный размер (опционально)
    maximumSize: const Size(double.infinity, double.infinity),

    // Tap target size
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,

    // Убираем визуальные отступы
    visualDensity: VisualDensity.compact,
    padding: EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: AppSpacing.lg,
    ),

    backgroundColor: AppColors.primaryContainer,
  );

  static ButtonStyle get baseButtonStyle =>
      OutlinedButton.styleFrom(
        minimumSize: const Size(0, 0), // Убираем минимальный размер
        // Максимальный размер (опционально)
        maximumSize: const Size(double.infinity, double.infinity),

        // Tap target size
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF2A2A2A), width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xl,
        ),
      ).copyWith(
        overlayColor: WidgetStatePropertyAll(Colors.white.withOpacity(0.06)),
        iconColor: const WidgetStatePropertyAll(Color(0xFFFFB39B)),
      );
}
