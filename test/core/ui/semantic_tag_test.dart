import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/semantic_tag.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('SemanticTag', () {
    testWidgets('renders label prefixed with #', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const SemanticTag(
          label: 'work',
          accentColor: Colors.blue,
        ),
      ));

      expect(find.text('#work'), findsOneWidget);
    });

    testWidgets('shows close icon when onRemove is provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        SemanticTag(
          label: 'tag',
          accentColor: Colors.red,
          onRemove: () {},
        ),
      ));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('hides close icon when onRemove is null', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const SemanticTag(
          label: 'tag',
          accentColor: Colors.green,
        ),
      ));

      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('calls onRemove when close icon tapped', (tester) async {
      bool removed = false;
      await tester.pumpWidget(createTestWidget(
        SemanticTag(
          label: 'removable',
          accentColor: Colors.orange,
          onRemove: () => removed = true,
        ),
      ));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(removed, isTrue);
    });
  });
}
