import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/settings/settings_screen.dart';

void main() {
  group('SettingsScreen', () {
    testWidgets('renders app bar with title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.text('Настройки'), findsOneWidget);
    });

    testWidgets('renders section headers', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.text('ОСНОВНЫЕ'), findsOneWidget);
      expect(find.text('ПРЕДПОЧТЕНИЯ'), findsOneWidget);
      expect(find.text('OPTIMIZATION'), findsOneWidget);
      expect(find.text('О СИСТЕМЕ'), findsOneWidget);
    });

    testWidgets('renders theme toggle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.text('Тёмная тема'), findsOneWidget);
      expect(find.byIcon(Icons.dark_mode_outlined), findsOneWidget);
    });

    testWidgets('renders notifications toggle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.text('Уведомления'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    });

    testWidgets('renders language selector', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.text('Язык приложения'), findsOneWidget);
      expect(find.byIcon(Icons.language_outlined), findsOneWidget);
    });

    testWidgets('renders blur toggle', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.text('Эффект размытия (Blur)'), findsOneWidget);
      expect(find.byIcon(Icons.blur_on), findsOneWidget);
    });

    testWidgets('renders about section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

      expect(find.text('О программе'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}
