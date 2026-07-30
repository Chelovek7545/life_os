import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/animated_indexed_stack.dart';

void main() {
  group('AnimatedIndexedStack', () {
    testWidgets('renders child at given index', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AnimatedIndexedStack(
                index: 1,
                children: const [
                  Text('Page 0'),
                  Text('Page 1'),
                  Text('Page 2'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Page 0'), findsNothing);
      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('switches to new index', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AnimatedIndexedStack(
                index: 0,
                children: const [
                  Text('Page 0'),
                  Text('Page 1'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Page 0'), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AnimatedIndexedStack(
                index: 1,
                children: const [
                  Text('Page 0'),
                  Text('Page 1'),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('uses custom duration', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200,
              height: 200,
              child: AnimatedIndexedStack(
                index: 0,
                duration: const Duration(milliseconds: 500),
                children: const [Text('Page 0')],
              ),
            ),
          ),
        ),
      );

      final stack = tester.widget<AnimatedIndexedStack>(find.byType(AnimatedIndexedStack));
      expect(stack.duration, const Duration(milliseconds: 500));
    });
  });
}
