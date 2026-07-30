import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/resizable_panel.dart';

Widget createTestWidget({double initialWidth = 300, double minWidth = 200, double maxWidth = 600}) {
  return MaterialApp(
    home: Scaffold(
      body: ResizablePanel(
        initialWidth: initialWidth,
        minWidth: minWidth,
        maxWidth: maxWidth,
        child: const Text('Panel Content'),
      ),
    ),
  );
}

void main() {
  group('ResizablePanel', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Panel Content'), findsOneWidget);
    });

    testWidgets('uses initial width', (tester) async {
      await tester.pumpWidget(createTestWidget(initialWidth: 400));

      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 400);
    });
  });
}
