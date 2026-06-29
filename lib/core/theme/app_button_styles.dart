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
  static ButtonStyle get activeButtonStyle => OutlinedButton.styleFrom(
    minimumSize: const Size(0, 0), // Убираем минимальный размер
    // Максимальный размер (опционально)
    maximumSize: const Size(double.infinity, double.infinity),
    backgroundColor: AppColors.primary.withAlpha(100),
    foregroundColor: AppColors.primary,
    side: const BorderSide(color: AppColors.primary, width: 1.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // Tap target size
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: EdgeInsets.all(AppSpacing.xl),
  );

  static InputDecorationTheme get baseInputDecoration => InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface, // Темный фон контейнера
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),

    // Настройка скругления и границ
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg), // Большое скругление
      borderSide: BorderSide(color: AppColors.surfaceBright, width: 1),
    ),
    enabledBorder: InputBorder.none,
    // OutlineInputBorder(
    //   borderRadius: BorderRadius.circular(AppRadius.lg),
    //   borderSide:  BorderSide(color: AppColors.borderGlass, width: 1),
    // ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      // При фокусе можно подсветить границу цветом primary
      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
    ),
  );
}
