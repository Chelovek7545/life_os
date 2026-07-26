import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/pill_switcher.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('PillSwitcher', () {
    testWidgets('renders all options', (tester) async {
      await tester.pumpWidget(createTestWidget(
        PillSwitcher(
          options: const [Text('Day'), Text('Week'), Text('Month')],
          onSelectionChanged: (_) {},
        ),
      ));

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    });

    testWidgets('calls onSelectionChanged on tap', (tester) async {
      int selected = -1;
      await tester.pumpWidget(createTestWidget(
        PillSwitcher(
          options: const [Text('A'), Text('B')],
          onSelectionChanged: (i) => selected = i,
        ),
      ));

      await tester.tap(find.text('B'));
      await tester.pump();

      expect(selected, 1);
    });

    testWidgets('selects first option by default', (tester) async {
      await tester.pumpWidget(createTestWidget(
        PillSwitcher(
          options: const [Text('X'), Text('Y')],
          onSelectionChanged: (_) {},
        ),
      ));

      expect(find.text('X'), findsOneWidget);
      expect(find.text('Y'), findsOneWidget);
    });
  });
}
