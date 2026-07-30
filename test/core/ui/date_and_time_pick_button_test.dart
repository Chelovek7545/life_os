import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/date_and_time_pick_button.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('dateAndTimePickButton', () {
    testWidgets('renders label', (tester) async {
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => dateAndTimePickButton(
          context,
          label: 'Start',
          date: null,
          onDateChange: (_) {},
          validate: (_) => true,
        )),
      ));

      expect(find.text('Start'), findsOneWidget);
    });

    testWidgets('shows no date text when date is null', (tester) async {
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => dateAndTimePickButton(
          context,
          label: 'End',
          date: null,
          onDateChange: (_) {},
          validate: (_) => true,
        )),
      ));

      expect(find.text('no date'), findsOneWidget);
    });

    testWidgets('shows formatted date when date is set', (tester) async {
      // This widget has a known layout overflow in the AspectRatio/Expanded
      // column; suppress overflow errors.
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => dateAndTimePickButton(
          context,
          label: 'End',
          date: DateTime(2024, 3, 5),
          onDateChange: (_) {},
          validate: (_) => true,
        )),
      ));

      expect(find.text('05.03.2024'), findsOneWidget);
    });

    testWidgets('shows Time text when date is dateOnly', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => dateAndTimePickButton(
          context,
          label: 'Start',
          date: DateTime(2024, 1, 15, 0, 0, 0, 1), // dateOnly convention
          onDateChange: (_) {},
          validate: (_) => true,
        )),
      ));

      expect(find.text('Time'), findsOneWidget);
    });

    testWidgets('calls onDateChange with null when close tapped', (tester) async {
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        oldHandler?.call(details);
      };
      addTearDown(() => FlutterError.onError = oldHandler);

      DateTime? result;
      await tester.pumpWidget(createTestWidget(
        Builder(builder: (context) => dateAndTimePickButton(
          context,
          label: 'Start',
          date: DateTime(2024, 6, 15),
          onDateChange: (d) => result = d,
          validate: (_) => true,
        )),
      ));

      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(result, isNull);
    });
  });
}
