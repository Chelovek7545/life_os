import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/vibrant_gradient_button.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('VibrantGradientButton', () {
    testWidgets('renders text', (tester) async {
      await tester.pumpWidget(createTestWidget(
        VibrantGradientButton(
          text: 'Save',
          onPressed: () {},
        ),
      ));

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        VibrantGradientButton(
          text: 'Add',
          icon: Icons.add,
          onPressed: () {},
        ),
      ));

      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('calls onPressed when tapped', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(createTestWidget(
        VibrantGradientButton(
          text: 'Go',
          onPressed: () => pressed = true,
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pump();

      expect(pressed, isTrue);
    });
  });
}
