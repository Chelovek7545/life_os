import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_spacing.dart';

void main() {
  group('AppSpacing', () {
    test('values match expected sizes', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 12);
      expect(AppSpacing.lg, 16);
      expect(AppSpacing.xl, 24);
      expect(AppSpacing.xxl, 32);
    });
  });

  group('AppRadius', () {
    test('values match expected sizes', () {
      expect(AppRadius.sm, 4);
      expect(AppRadius.md, 8);
      expect(AppRadius.lg, 12);
      expect(AppRadius.xl, 16);
      expect(AppRadius.xxl, 32);
      expect(AppRadius.full, 999);
    });
  });

  group('AppMargins', () {
    test('values match expected sizes', () {
      expect(AppMargins.xs, 4);
      expect(AppMargins.sm, 8);
      expect(AppMargins.md, 12);
      expect(AppMargins.lg, 16);
      expect(AppMargins.xl, 24);
      expect(AppMargins.xxl, 40);
    });
  });
}
