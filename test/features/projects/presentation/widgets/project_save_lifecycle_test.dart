import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';

void main() {
  testWidgets(
    'save waits, prevents duplicate writes and preserves input for retry',
    (tester) async {
      final gate = Completer<void>();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditProjectCard(
                onCancel: () {},
                onSave: (name, description, color, dueDate) async {
                  expect(name, 'Pending project');
                  attempts++;
                  if (attempts == 1) {
                    await gate.future;
                    throw StateError('Write failed');
                  }
                },
              ),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextFormField).first,
        'Pending project',
      );
      await tester.tap(find.text('INITIALIZE PROJECT'));
      await tester.pump();
      expect(attempts, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось сохранить проект. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.text('Pending project'), findsOneWidget);
      await tester.tap(find.text('INITIALIZE PROJECT'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        find.text('Не удалось сохранить проект. Повторите попытку.'),
        findsNothing,
      );
    },
  );
}
