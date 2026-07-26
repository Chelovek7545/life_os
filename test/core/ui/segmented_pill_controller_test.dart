import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SegmentedPillControl', () {
    testWidgets('renders all tabs', (tester) async {
      await tester.pumpWidget(createTestWidget(
        SegmentedPillControl(
          tabs: const ['Day', 'Week', 'Month'],
          onTabChanged: (_) {},
          currentIdx: 0,
        ),
      ));

      expect(find.text('Day'), findsOneWidget);
      expect(find.text('Week'), findsOneWidget);
      expect(find.text('Month'), findsOneWidget);
    });

    testWidgets('highlights current tab', (tester) async {
      await tester.pumpWidget(createTestWidget(
        SegmentedPillControl(
          tabs: const ['A', 'B', 'C'],
          onTabChanged: (_) {},
          currentIdx: 1,
        ),
      ));

      // Current tab B should be visible
      expect(find.text('B'), findsOneWidget);
    });

    testWidgets('calls onTabChanged on tap', (tester) async {
      int selected = -1;
      await tester.pumpWidget(createTestWidget(
        SegmentedPillControl(
          tabs: const ['X', 'Y'],
          onTabChanged: (i) => selected = i,
          currentIdx: 0,
        ),
      ));

      await tester.tap(find.text('Y'));
      await tester.pump();

      expect(selected, 1);
    });
  });
}
