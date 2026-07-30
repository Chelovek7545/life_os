import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';

void main() {
  group('AppColors', () {
    test('surface colors are defined', () {
      expect(AppColors.surfaceDim, const Color(0xFF0C0B0B));
      expect(AppColors.surface, const Color(0xFF141212));
      expect(AppColors.surfaceBright, const Color(0xFF1E1B1B));
    });

    test('container hierarchy colors are defined', () {
      expect(AppColors.surfaceContainerLowest, const Color(0xFF101010));
      expect(AppColors.surfaceContainerLow, const Color(0xFF151414));
      expect(AppColors.surfaceContainer, const Color(0xFF1C1A1A));
      expect(AppColors.surfaceContainerHigh, const Color(0xFF312E2E));
    });

    test('text colors are defined', () {
      expect(AppColors.onSurface, const Color(0xFFE5E2E1));
      expect(AppColors.onSurfaceVariant, const Color(0xFFE5BEB2));
    });

    test('brand colors are defined', () {
      expect(AppColors.primary, const Color(0xFFFFB59C));
      expect(AppColors.primaryContainer, const Color(0xFFFF5C00));
      expect(AppColors.secondary, const Color(0xFFDCB8FF));
      expect(AppColors.secondaryContainer, const Color(0xFF550099));
      expect(AppColors.tertiary, const Color(0xFFFFB1C3));
    });

    test('glass colors have alpha transparency', () {
      expect(AppColors.surfaceGlass, isNot(equals(Colors.white)));
      expect(AppColors.borderGlass, isNot(equals(Colors.white)));
    });

    test('vibrantGradient has two colors', () {
      expect(AppColors.vibrantGradient.colors.length, 2);
      expect(AppColors.vibrantGradient.colors[0], const Color(0xFFFF5500));
      expect(AppColors.vibrantGradient.colors[1], const Color(0xFF7701D0));
    });

    test('overdueGlow has low alpha', () {
      expect(AppColors.overdueGlow, const Color(0x22FF5500));
    });
  });
}
