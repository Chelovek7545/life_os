import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/glass_panel.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('GlassPanel', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GlassPanel(child: Text('Panel Content')),
      ));

      expect(find.text('Panel Content'), findsOneWidget);
    });

    testWidgets('applies custom padding', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GlassPanel(
          child: Text('Padded'),
          padding: EdgeInsets.all(16),
        ),
      ));

      expect(find.text('Padded'), findsOneWidget);
    });

    testWidgets('applies custom borderRadius', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const GlassPanel(
          child: Text('Rounded'),
          borderRadius: 12,
        ),
      ));

      expect(find.text('Rounded'), findsOneWidget);
    });
  });
}
