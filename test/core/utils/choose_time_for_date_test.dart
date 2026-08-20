import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/utils/datetime_utils.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
    home: Scaffold(body: child),
  );
}

void main() {
  group('chooseTimeForDate', () {
    testWidgets('shows clear button when a time is set', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () =>
                    chooseTimeForDate(context, DateTime(2024, 6, 15, 9, 30)),
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clear-time-picker')), findsOneWidget);
    });

    testWidgets('hides clear button for date-only', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () =>
                    chooseTimeForDate(context, DateTime(2024, 6, 15, 0, 0, 0, 1)),
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clear-time-picker')), findsNothing);
    });

    testWidgets('tapping clear returns startOfDay', (tester) async {
      DateTime? result;
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () async {
                  result = await chooseTimeForDate(
                    context,
                    DateTime(2024, 6, 15, 9, 30),
                  );
                },
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('clear-time-picker')));
      await tester.pumpAndSettle();

      expect(result, DateTime(2024, 6, 15, 0, 0, 0, 1));
    });

    testWidgets('positions clear button centered above the dialog',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () =>
                    chooseTimeForDate(context, DateTime(2024, 6, 15, 9, 30)),
                child: const Text('pick'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('pick'));
      await tester.pumpAndSettle();

      final screenSize = tester.getSize(find.byType(Scaffold));
      final buttonRect = tester.getRect(
        find.byKey(const Key('clear-time-picker')),
      );

      expect(buttonRect.bottom, lessThan(screenSize.height / 2));
      expect(
        (buttonRect.center.dx - screenSize.width / 2).abs(),
        lessThan(120),
      );
    });
  });
}
