import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/presentation/components/date_header.dart';
import 'package:life_os/core/utils/date_format.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('DateHeader', () {
    testWidgets('renders formatted date', (tester) async {
      final date = DateTime(2024, 7, 15);
      await tester.pumpWidget(createTestWidget(
        DateHeader(
          anchorDate: date,
          onDateChange: (_) {},
        ),
      ));

      expect(find.text(formatDate(date)), findsOneWidget);
    });

    testWidgets('shows TODAY when anchorDate is today', (tester) async {
      await tester.pumpWidget(createTestWidget(
        DateHeader(
          anchorDate: DateTime.now(),
          onDateChange: (_) {},
        ),
      ));

      expect(find.text('TODAY'), findsOneWidget);
    });

    testWidgets('hides TODAY when anchorDate is not today', (tester) async {
      await tester.pumpWidget(createTestWidget(
        DateHeader(
          anchorDate: DateTime(2023, 1, 1),
          onDateChange: (_) {},
        ),
      ));

      expect(find.text('TODAY'), findsNothing);
    });

    testWidgets('renders left and right chevron icons', (tester) async {
      await tester.pumpWidget(createTestWidget(
        DateHeader(
          anchorDate: DateTime.now(),
          onDateChange: (_) {},
        ),
      ));

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('calls onDateChange with previous day on left chevron', (tester) async {
      DateTime? result;
      final date = DateTime(2024, 6, 15);
      await tester.pumpWidget(createTestWidget(
        DateHeader(
          anchorDate: date,
          onDateChange: (d) => result = d,
        ),
      ));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();

      expect(result, DateTime(2024, 6, 14));
    });

    testWidgets('calls onDateChange with next day on right chevron', (tester) async {
      DateTime? result;
      final date = DateTime(2024, 6, 15);
      await tester.pumpWidget(createTestWidget(
        DateHeader(
          anchorDate: date,
          onDateChange: (d) => result = d,
        ),
      ));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();

      expect(result, DateTime(2024, 6, 16));
    });
  });
}
