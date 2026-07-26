import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/base_container.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('BaseContainer', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const BaseContainer(child: Text('Hello')),
      ));

      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('applies correct padding', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const BaseContainer(child: SizedBox(width: 50, height: 50)),
      ));

      final container = tester.widget<Container>(find.byType(Container).first);
      expect(container.padding, isNotNull);
    });
  });
}
