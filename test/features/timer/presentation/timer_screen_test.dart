import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/timer/presentation/timer_screen.dart';

Widget createTestWidget() {
  return const MaterialApp(
    home: TimerScreen(),
  );
}

void main() {
  group('TimerScreen', () {
    testWidgets('renders title and description', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Timer'), findsOneWidget);
      expect(find.text('A simple focus timer for routines and work sessions.'), findsOneWidget);
    });

    testWidgets('shows default time 25:00', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('25:00'), findsOneWidget);
    });

    testWidgets('shows Start button when not running', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Start'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    });

    testWidgets('shows Reset button', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Reset'), findsOneWidget);
    });

    testWidgets('toggles to Pause when Start is tapped', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Start'));
      await tester.pump();

      expect(find.text('Pause'), findsOneWidget);
      expect(find.byIcon(Icons.pause), findsOneWidget);
    });

    testWidgets('toggles back to Start when Pause is tapped', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('Reset button resets to initial state', (tester) async {
      await tester.pumpWidget(createTestWidget());

      await tester.tap(find.text('Start'));
      await tester.pump();

      await tester.tap(find.text('Reset'));
      await tester.pump();

      expect(find.text('Start'), findsOneWidget);
      expect(find.text('25:00'), findsOneWidget);
    });
  });
}
