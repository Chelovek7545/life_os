import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_theme.dart';

void main() {
  group('AppTheme', () {
    test('darkTheme has dark brightness', () {
      final theme = AppTheme.darkTheme;
      expect(theme.brightness, Brightness.dark);
    });

    test('darkTheme uses standard visual density', () {
      final theme = AppTheme.darkTheme;
      expect(theme.visualDensity, VisualDensity.standard);
    });

    test('darkTheme has card theme with rounded corners', () {
      final theme = AppTheme.darkTheme;
      expect(theme.cardTheme, isNotNull);
      expect(theme.cardTheme?.shape, isA<RoundedRectangleBorder>());
    });

    test('darkTheme has input decoration theme', () {
      final theme = AppTheme.darkTheme;
      expect(theme.inputDecorationTheme, isNotNull);
    });

    test('darkTheme has elevated button theme', () {
      final theme = AppTheme.darkTheme;
      expect(theme.elevatedButtonTheme, isNotNull);
    });

    test('darkTheme has icon button theme with shrinkWrap tap target', () {
      final theme = AppTheme.darkTheme;
      expect(theme.iconButtonTheme.style?.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
    });
  });
}
