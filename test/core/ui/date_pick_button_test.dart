import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/date_pick_button.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('datePickButton', () {
    testWidgets('renders label when date is null', (tester) async {
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => datePickButton(
          context,
          label: 'Due date',
          date: null,
          onDateChange: (_) {},
        )),
      ));

      expect(find.text('Due date'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    testWidgets('renders formatted date when date is set', (tester) async {
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => datePickButton(
          context,
          label: 'Due date',
          date: DateTime(2024, 1, 15),
          onDateChange: (_) {},
        )),
      ));

      expect(find.text('15.01.2024'), findsOneWidget);
    });

    testWidgets('shows close button when date is set', (tester) async {
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => datePickButton(
          context,
          label: 'Date',
          date: DateTime.now(),
          onDateChange: (_) {},
        )),
      ));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides close button when date is null', (tester) async {
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => datePickButton(
          context,
          label: 'Date',
          date: null,
          onDateChange: (_) {},
        )),
      ));

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onDateChange with null when close tapped', (tester) async {
      DateTime? result;
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => datePickButton(
          context,
          label: 'Date',
          date: DateTime(2024, 6, 15),
          onDateChange: (d) => result = d,
        )),
      ));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(result, isNull);
    });
  });
}
