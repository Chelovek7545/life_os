import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/pill_checker.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('PillChecker', () {
    testWidgets('renders all options', (tester) async {
      await tester.pumpWidget(createTestWidget(
        PillChecker(
          options: const ['Morning', 'Afternoon', 'Evening'],
          onSelectionChanged: (_) {},
        ),
      ));

      expect(find.text('Morning'), findsOneWidget);
      expect(find.text('Afternoon'), findsOneWidget);
      expect(find.text('Evening'), findsOneWidget);
    });

    testWidgets('calls onSelectionChanged on tap', (tester) async {
      int selected = -1;
      await tester.pumpWidget(createTestWidget(
        PillChecker(
          options: const ['A', 'B'],
          onSelectionChanged: (i) => selected = i,
        ),
      ));

      await tester.tap(find.text('B'));
      await tester.pump();

      expect(selected, 1);
    });

    testWidgets('preview builds without error', (tester) async {
      await tester.pumpWidget(createTestWidget(PillChecker.preview()));
      await tester.pump();

      expect(find.text('Morning'), findsOneWidget);
    });
  });
}
