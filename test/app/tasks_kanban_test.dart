import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  testWidgets('kanban header spacing stays consistent after calendar mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(
      () => createTestApp(enableObsidian: false),
    ))!;
    await tester.pumpWidget(MyApp(diContainer: app));
    app.navigation.open('tasks');
    await pumpStorage(tester);
    await tester.tap(find.text('Week'));
    await pumpStorage(tester);
    await tester.tap(find.byIcon(Icons.view_kanban_outlined));
    await pumpStorage(tester);
    final board = find.byKey(const ValueKey('tasks.kanban'));
    final weekTop = tester.getTopLeft(board).dy;

    await tester.tap(find.byIcon(Icons.event));
    await pumpStorage(tester);
    expect(app.tasksViewModel.currentFilterValue.period, DatePeriod.week);
    await tester.tap(find.byIcon(Icons.view_kanban_outlined));
    await pumpStorage(tester);
    expect(tester.getTopLeft(board).dy, weekTop);

    await tester.tap(find.text('Day'));
    await pumpStorage(tester);
    expect(tester.getTopLeft(board).dy, greaterThan(weekTop));
    await tester.tap(find.text('Week'));
    await pumpStorage(tester);
    expect(tester.getTopLeft(board).dy, weekTop);
    await tester.tap(find.text('Month'));
    await pumpStorage(tester);
    expect(tester.getTopLeft(board).dy, weekTop);
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester, app);
  });

  testWidgets(
    'new task form uses the chosen day after calendar week navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final monday = DateTime(2026, 11, 2);
      final chosen = DateTime(2026, 11, 4);
      app.tasksViewModel.updateFilter(
        (old) => old.copyWith(anchorDate: monday, period: DatePeriod.week),
      );
      app.tasksViewModel.toggleEventMode();
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('tasks');
      await pumpStorage(tester);
      await tester.tap(find.byKey(ValueKey(('timeline.day', chosen))));
      await pumpStorage(tester);
      await tester.tap(find.byTooltip('Next week'));
      await pumpStorage(tester);
      app.tasksViewModel.showForm();
      await pumpStorage(tester);
      expect(
        tester
            .widget<CollapsibleTaskForm>(find.byType(CollapsibleTaskForm))
            .task
            .startsAt,
        chosen.startOfDay,
      );
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'kanban displays dated and undated tasks, moves status, opens editor and scrolls on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final day = DateTime.now().startOfDay;
      final scheduled = Task.blank().copyWith(
        title: 'Dated kanban task',
        status: TaskStatus.notStarted,
        startsAt: Wrapped(day),
      );
      final unscheduled = Task.blank().copyWith(
        title: 'Undated kanban task',
        status: TaskStatus.open,
      );
      await tester.runAsync(() async {
        await app.tasksRepository.addTask(scheduled);
        await app.tasksRepository.addTask(unscheduled);
        await app.workLogsRepository.addWorkLog(
          WorkLog(
            id: 'kanban-log',
            taskId: scheduled.id,
            status: 1,
            date: day,
            description: 'Конспект канбан',
            startedAt: DateTime(day.year, day.month, day.day, 14, 10),
            endedAt: DateTime(day.year, day.month, day.day, 15, 30),
          ),
        );
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('tasks');
      await pumpStorage(tester);
      await tester.tap(find.byIcon(Icons.view_kanban_outlined));
      await pumpStorage(tester);
      final board = find.byKey(const ValueKey('tasks.kanban'));
      expect(board, findsOneWidget);
      expect(find.text('Dated kanban task'), findsOneWidget);
      expect(find.text('Undated kanban task'), findsOneWidget);
      final task = find.byKey(ValueKey(('kanban.task', scheduled.id)));
      final target = find.byKey(
        const ValueKey(('kanban.column', TaskStatus.inProgress)),
      );
      await tester.tap(
        find.descendant(
          of: task,
          matching: find.byKey(const ValueKey('task.worklogs.toggle')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Конспект канбан'), findsOneWidget);
      final originalRect = tester.getRect(task);
      final gesture = await tester.startGesture(tester.getCenter(task));
      await tester.pump(const Duration(milliseconds: 600));
      final feedback = find.byKey(ValueKey(('kanban.feedback', scheduled.id)));
      expect(tester.getSize(feedback), originalRect.size);
      expect(tester.getTopLeft(feedback), originalRect.topLeft);
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      await gesture.up();
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(scheduled.id),
        ))!.status,
        TaskStatus.inProgress,
      );
      expect(find.descendant(of: target, matching: task), findsOneWidget);
      await tester.tap(
        find.descendant(of: task, matching: find.text(scheduled.title)),
      );
      await pumpStorage(tester);
      expect(find.text('Edit task'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('task-editor.close')));
      await tester.pumpAndSettle();
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.drag(board, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const ValueKey(('kanban.column', TaskStatus.done)))
            .hitTestable(),
        findsOneWidget,
      );
      await tester.tap(find.byIcon(Icons.check_box));
      await pumpStorage(tester);
      expect(board, findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );
}
