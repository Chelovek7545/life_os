import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

void main() {
  group('AppTypography', () {
    test('displayXL has correct properties', () {
      final style = AppTypography.displayXL;
      expect(style.fontFamily, 'SpaceGrotesk');
      expect(style.fontSize, 48);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.color, AppColors.primary);
    });

    test('headlineLg has correct properties', () {
      final style = AppTypography.headlineLg;
      expect(style.fontFamily, 'SpaceGrotesk');
      expect(style.fontSize, 32);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, Colors.white);
    });

    test('headlineMd has correct properties', () {
      final style = AppTypography.headlineMd;
      expect(style.fontFamily, 'SpaceGrotesk');
      expect(style.fontSize, 28);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, Colors.white);
    });

    test('headlineLgMobile has correct properties', () {
      final style = AppTypography.headlineLgMobile;
      expect(style.fontFamily, 'SpaceGrotesk');
      expect(style.fontSize, 24);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.color, AppColors.primary);
    });

    test('bodyMd has correct properties', () {
      final style = AppTypography.bodyMd;
      expect(style.fontFamily, 'Inter');
      expect(style.fontSize, 16);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.color, AppColors.onBackground);
    });

    test('bodySm has correct properties', () {
      final style = AppTypography.bodySm;
      expect(style.fontFamily, 'Inter');
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.color, AppColors.onSurfaceVariant);
    });

    test('codeLabel has correct properties', () {
      final style = AppTypography.codeLabel;
      expect(style.fontFamily, 'JetBrainsMono');
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.color, AppColors.onSurfaceVariant);
    });
  });
}
