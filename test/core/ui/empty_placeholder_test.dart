import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/empty_placeholder.dart';

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(body: child),
  );
}

void main() {
  group('EmptyPlaceholder', () {
    testWidgets('renders Empty text', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const EmptyPlaceholder(),
      ));

      expect(find.text('Empty'), findsOneWidget);
    });
  });
}
