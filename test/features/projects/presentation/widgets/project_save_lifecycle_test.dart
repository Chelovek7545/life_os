import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';

void main() {
  testWidgets(
    'save waits, prevents duplicate writes and preserves input for retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final gate = Completer<void>();
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: EditProjectCard(
                onCancel: () {},
                onSave: (project) async {
                  expect(project.name, 'Pending project');
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
      await tester.tap(find.text('Создать проект'));
      await tester.pump();
      expect(attempts, 1);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось сохранить проект. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.text('Pending project'), findsOneWidget);
      await tester.tap(find.text('Создать проект'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(
        find.text('Не удалось сохранить проект. Повторите попытку.'),
        findsNothing,
      );
    },
  );
}
