import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/features/tasks/presentation/components/task_kanban_board.dart';
import '../../test_helpers.dart';

void main() {
  testWidgets(
    'drag feedback preserves the grab point and drops using the cursor position',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final task = Task.blank().copyWith(
        title: 'Keep the grabbed point',
        status: TaskStatus.notStarted,
      );
      final moves = <TaskStatus>[];
      await tester.pumpWidget(
        createTestWidget(
          child: TaskKanbanBoard(
            items: [TaskWithProject(task: task)],
            topPadding: 0,
            onOpen: (_) {},
            onToggle: (_) {},
            onMove: (_, status) => moves.add(status),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final source = find.byKey(ValueKey(('kanban.task', task.id)));
      final feedback = find.byKey(ValueKey(('kanban.feedback', task.id)));
      final sourceRect = tester.getRect(source);
      for (final grabPoint in [
        sourceRect.center,
        sourceRect.topLeft + const Offset(30, 20),
      ]) {
        final gesture = await tester.startGesture(grabPoint);
        await tester.pump(const Duration(milliseconds: 600));
        expect(tester.getRect(feedback).topLeft, sourceRect.topLeft);
        expect(tester.getSize(feedback), sourceRect.size);
        await gesture.moveBy(const Offset(50, 70));
        await tester.pump();
        expect(
          tester.getRect(feedback).topLeft,
          sourceRect.topLeft + const Offset(50, 70),
        );
        // The feedback's top-left is outside the target: drop must follow the pointer.
        final target = tester.getRect(
          find.byKey(const ValueKey(('kanban.column', TaskStatus.inProgress))),
        );
        await gesture.moveTo(Offset(target.left + 5, target.center.dy));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(feedback, findsNothing);
      }
      expect(moves, [TaskStatus.inProgress, TaskStatus.inProgress]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cards have space below the header and the header stays fixed while scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final items = [
        for (var i = 0; i < 20; i++)
          TaskWithProject(
            task: Task.blank().copyWith(
              title: 'Task $i',
              status: TaskStatus.notStarted,
            ),
          ),
      ];
      await tester.pumpWidget(
        createTestWidget(
          child: TaskKanbanBoard(
            items: items,
            topPadding: 0,
            onOpen: (_) {},
            onToggle: (_) {},
            onMove: (_, _) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(
        const ValueKey(('kanban.header', TaskStatus.notStarted)),
      );
      final list = find.byKey(
        const ValueKey(('kanban.list', TaskStatus.notStarted)),
      );
      final first = find.byKey(ValueKey(('kanban.task', items.first.task.id)));
      final headerRect = tester.getRect(header);
      expect(
        tester.getTopLeft(first).dy,
        greaterThanOrEqualTo(headerRect.bottom + 8),
      );
      await tester.drag(list, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getRect(header), headerRect);
      expect(tester.getRect(list).top, greaterThanOrEqualTo(headerRect.bottom));
      // The header remains clickable instead of being covered by list contents.
      expect(find.text('К выполнению').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
