import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';

void main() {
  group('ResourcesScreen', () {
    testWidgets('renders title and resource cards', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ResourcesScreen(),
      ));

      expect(find.text('Ресурсы'), findsOneWidget);
      expect(find.text('Guides'), findsOneWidget);
      expect(find.text('Templates'), findsOneWidget);
      expect(find.text('Tools'), findsOneWidget);
      expect(find.text('Notes'), findsOneWidget);
    });

    testWidgets('renders subtitles for each card', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ResourcesScreen(),
      ));

      expect(
        find.text('Step-by-step support for routines and habits.'),
        findsOneWidget,
      );
      expect(
        find.text('Use reusable layouts for projects and tasks.'),
        findsOneWidget,
      );
      expect(
        find.text('Productivity apps, timers, and trackers.'),
        findsOneWidget,
      );
      expect(
        find.text('Capture ideas and reminders quickly.'),
        findsOneWidget,
      );
    });

    testWidgets('renders all icons', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: ResourcesScreen(),
      ));

      expect(find.byIcon(Icons.menu_book), findsOneWidget);
      expect(find.byIcon(Icons.grid_view), findsOneWidget);
      expect(find.byIcon(Icons.build), findsOneWidget);
      expect(find.byIcon(Icons.note), findsOneWidget);
    });
  });
}
