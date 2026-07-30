import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_button_styles.dart';

void main() {
  group('AppButtonStyles', () {
    test('saveButton has shrinkWrap tap target', () {
      expect(AppButtonStyles.saveButton.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });

    test('saveButton has compact visual density', () {
      expect(AppButtonStyles.saveButton.visualDensity, VisualDensity.compact);
    });

    test('baseButtonStyle has shrinkWrap tap target', () {
      expect(AppButtonStyles.baseButtonStyle.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });

    test('activeButtonStyle has shrinkWrap tap target', () {
      expect(AppButtonStyles.activeButtonStyle.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });

    test('menuButtonStyle returns a ButtonStyle', () {
      final style = AppButtonStyles.menuButtonStyle();
      expect(style, isA<ButtonStyle>());
    });

    test('menuButtonStyle with custom bgColor', () {
      final style = AppButtonStyles.menuButtonStyle(bgColor: Colors.red);
      expect(style, isA<ButtonStyle>());
    });

    test('baseInputDecoration has filled property', () {
      expect(AppButtonStyles.baseInputDecoration.filled, isTrue);
    });
  });
}
