import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/fixed_fade_mask.dart';

void main() {
  group('FixedVerticalFadeMask', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: FixedVerticalFadeMask(
              child: const Text('Fade Content'),
            ),
          ),
        ),
      );

      expect(find.text('Fade Content'), findsOneWidget);
    });

    testWidgets('contains ShaderMask widget', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: FixedVerticalFadeMask(
              child: const Text('Fade Content'),
            ),
          ),
        ),
      );

      expect(find.byType(ShaderMask), findsOneWidget);
    });

    testWidgets('uses default fade values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: const FixedVerticalFadeMask(
              child: Text('Fade Content'),
            ),
          ),
        ),
      );

      final mask = tester.widget<FixedVerticalFadeMask>(find.byType(FixedVerticalFadeMask));
      expect(mask.topFade, 24.0);
      expect(mask.bottomFade, 24.0);
    });

    testWidgets('accepts custom fade values', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 200,
            height: 200,
            child: const FixedVerticalFadeMask(
              topFade: 40,
              bottomFade: 16,
              child: Text('Fade Content'),
            ),
          ),
        ),
      );

      final mask = tester.widget<FixedVerticalFadeMask>(find.byType(FixedVerticalFadeMask));
      expect(mask.topFade, 40.0);
      expect(mask.bottomFade, 16.0);
    });
  });
}
