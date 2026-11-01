import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/node_edit_dialog.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/existing_task_picker_dialog.dart';

Future<void> openDialog(WidgetTester tester, Widget dialog) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () =>
                showDialog<void>(context: context, builder: (_) => dialog),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

const node = GraphNode(
  id: 'task',
  type: GraphNodeType.task,
  title: 'Original',
  subtitle: '',
  color: '#123456',
);

void main() {
  testWidgets(
    'edit waits for completion, preserves input after failure and supports retry',
    (tester) async {
      final gate = Completer<void>();
      var attempts = 0;
      await openDialog(
        tester,
        NodeEditDialog(
          node: node,
          onDelete: (_) async {},
          onSave: (updated) async {
            attempts++;
            expect(updated.title, 'Edited');
            if (attempts == 1) {
              await gate.future;
              throw StateError('Write failed');
            }
          },
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Edited');
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      expect(find.byType(NodeEditDialog), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      gate.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось выполнить действие. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.text('Edited'), findsOneWidget);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(NodeEditDialog), findsNothing);
    },
  );

  testWidgets('failed deletion keeps the editor open and can be repeated', (
    tester,
  ) async {
    var attempts = 0;
    await openDialog(
      tester,
      NodeEditDialog(
        node: node,
        onSave: (_) async {},
        onDelete: (keepChildren) async {
          expect(keepChildren, isFalse);
          if (++attempts == 1) throw StateError('Delete failed');
        },
      ),
    );
    Future<void> remove() async {
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить всё поддерево'));
      await tester.pumpAndSettle();
    }

    await remove();
    expect(
      find.text('Не удалось выполнить действие. Повторите попытку.'),
      findsOneWidget,
    );
    await remove();
    expect(attempts, 2);
    expect(find.byType(NodeEditDialog), findsNothing);
  });

  testWidgets('failed creation keeps its title and enables another attempt', (
    tester,
  ) async {
    var attempts = 0;
    await openDialog(
      tester,
      AddChildDialog(
        childNodeType: GraphNodeType.goal,
        onSave:
            ({
              required title,
              required description,
              color,
              dueDate,
              startsAt,
              endsAt,
            }) async {
              expect(title, 'New goal');
              if (++attempts == 1) throw StateError('Create failed');
            },
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'New goal');
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(
      find.text('Не удалось создать узел. Повторите попытку.'),
      findsOneWidget,
    );
    expect(find.text('New goal'), findsOneWidget);
    await tester.tap(find.text('Создать'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(AddChildDialog), findsNothing);
  });

  testWidgets(
    'failed attachment stays in the picker until a successful retry',
    (tester) async {
      var attempts = 0;
      final task = Task.blank().copyWith(title: 'Attach me');
      await openDialog(
        tester,
        ExistingTaskPickerDialog(
          tasks: [task],
          onSelect: (id) async {
            expect(id, task.id);
            if (++attempts == 1) throw StateError('Invalid relationship');
          },
        ),
      );
      await tester.tap(find.text('Attach me'));
      await tester.pumpAndSettle();
      expect(find.byType(ExistingTaskPickerDialog), findsOneWidget);
      expect(
        find.text(
          'Не удалось привязать задачу. Проверьте связь и повторите попытку.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Attach me'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(ExistingTaskPickerDialog), findsNothing);
    },
  );
}
