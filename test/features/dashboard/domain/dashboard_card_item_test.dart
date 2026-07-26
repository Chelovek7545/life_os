import 'package:flutter/material.dart';
import 'package:life_os/features/dashboard/domain/dashboard_card_item.dart';
import 'package:test/test.dart';

void main() {
  group('DashboardCardItem', () {
    test('creates instance with required fields', () {
      final item = const DashboardCardItem(
        icon: Icons.task_alt,
        title: 'Tasks',
        value: '42',
      );

      expect(item.icon, Icons.task_alt);
      expect(item.title, 'Tasks');
      expect(item.value, '42');
    });

    group('equality', () {
      test('same instance is equal to itself', () {
        const item = DashboardCardItem(icon: Icons.task, title: 'T', value: '1');
        expect(item, item);
      });

      test('different instances with same fields are not equal', () {
        final a = DashboardCardItem(icon: Icons.task, title: 'T', value: '1');
        final b = DashboardCardItem(icon: Icons.task, title: 'T', value: '1');
        expect(a == b, isFalse);
      });

      test('hashCodes of different instances differ', () {
        final a = DashboardCardItem(icon: Icons.task, title: 'T', value: '1');
        final b = DashboardCardItem(icon: Icons.task, title: 'T', value: '1');
        expect(a.hashCode == b.hashCode, isFalse);
      });
    });

    test('supports different icons and values', () {
      final item = const DashboardCardItem(
        icon: Icons.dashboard_customize,
        title: 'Projects',
        value: '10',
      );

      expect(item.icon, Icons.dashboard_customize);
      expect(item.title, 'Projects');
      expect(item.value, '10');
    });
  });
}
