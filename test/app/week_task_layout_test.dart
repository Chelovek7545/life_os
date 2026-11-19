import 'package:core_contracts/core_contracts.dart' show StorageException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/core/ui/task_drag.dart';
import 'package:life_os/features/tasks/presentation/components/task_hierarchy.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  testWidgets('hierarchy, inbox, week and kanban accept tasks across panels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1050);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(
      () => createTestApp(enableObsidian: false),
    ))!;
    final project = Project.create(name: 'Drag project');
    final monday = DateTime(2026, 11, 16);
    final thursday = DateTime(2026, 11, 19);
    final task = Task.blank().copyWith(
      title: 'Movable task',
      status: TaskStatus.notStarted,
      projectId: Wrapped(project.id),
      dueDate: Wrapped(thursday.copyWith(hour: 18)),
    );
    final parent = Task.blank().copyWith(
      title: 'Target parent',
      projectId: Wrapped(project.id),
      startsAt: Wrapped(monday.startOfDay),
    );
    await tester.runAsync(() async {
      await app.projectsRepository.addProject(project);
      await app.tasksRepository.addTask(task);
      await app.tasksRepository.addTask(parent);
    });
    app.tasksViewModel.updateFilter(
      (old) => old.copyWith(anchorDate: monday, period: DatePeriod.week),
    );
    await tester.pumpWidget(MyApp(diContainer: app));
    app.navigation.open('tasks');
    await pumpStorage(tester);
    await tester.tap(find.byKey(const ValueKey('tasks.week-layout')));
    await tester.pumpAndSettle();

    final hierarchy = find.byType(TaskHierarchy);
    final hierarchyButton = find.byTooltip('Hierarchy');
    final inboxButton = find.byIcon(Icons.inbox_rounded);
    final inbox = find.byKey(const ValueKey('tasks.unscheduled'));
    final card = find.byKey(ValueKey(('week.task', thursday, task.id)));
    Finder taskIn(Finder pane, Task task) =>
        find.descendant(of: pane, matching: find.text(task.title));
    Future<Task> saved() async =>
        (await tester.runAsync(() => app.tasksRepository.getById(task.id)))!;
    Future<TestGesture> drag(Finder source, Finder target) async {
      final gesture = await tester.startGesture(tester.getCenter(source));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(tester.getCenter(target));
      await tester.pump();
      return gesture;
    }

    await tester.tap(hierarchyButton);
    await pumpStorage(tester);
    final day = find.byKey(ValueKey(('week.day', thursday)));
    final schedule = await drag(taskIn(hierarchy, task), day);
    await schedule.up();
    await pumpStorage(tester);
    expect((await saved()).startsAt, thursday.startOfDay);

    final attach = await drag(card, taskIn(hierarchy, parent));
    await attach.up();
    await pumpStorage(tester);
    expect((await saved()).parentTaskId, parent.id);
    await tester.runAsync(
      () => expectLater(
        app.tasksRepository.moveTaskUnder(parent.id, task.id),
        throwsA(isA<StorageException>()),
      ),
    );

    await tester.tap(inboxButton);
    await pumpStorage(tester);
    expect(taskIn(inbox, task), findsNothing);
    final unschedule = await drag(card, inbox);
    expect(find.text('Drop to unschedule'), findsOneWidget);
    await unschedule.up();
    await pumpStorage(tester);
    expect((await saved()).startsAt, isNull);
    expect((await saved()).dueDate, task.dueDate);

    await tester.tap(find.byIcon(Icons.view_kanban_outlined));
    await pumpStorage(tester);
    final column = find.byKey(
      const ValueKey(('kanban.column', TaskStatus.inProgress)),
    );
    final status = await drag(taskIn(inbox, task), column);
    await status.up();
    await pumpStorage(tester);
    expect((await saved()).status, TaskStatus.inProgress);
    expect((await saved()).startsAt, isNull);
    expect(
      find.descendant(of: column, matching: find.byType(TaskDraggable)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester, app);
  });

  testWidgets(
    'week switches layout and moves timed, date-only and spanning tasks without losing their schedule',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final mon = DateTime(2026, 11, 9);
      final tue = DateTime(2026, 11, 10);
      final wed = DateTime(2026, 11, 11);
      final thu = DateTime(2026, 11, 12);
      final sun = DateTime(2026, 11, 15);
      final timed = Task.blank().copyWith(
        title: 'Timed Monday',
        startsAt: Wrapped(mon.copyWith(hour: 9)),
        endsAt: Wrapped(mon.copyWith(hour: 10)),
      );
      final dated = Task.blank().copyWith(
        title: 'Date-only Monday',
        startsAt: Wrapped(mon.startOfDay),
      );
      final range = Task.blank().copyWith(
        title:
            'Long task title spanning multiple days and several lines in '
            'the regular task card with extra details at the end',
        dueDate: Wrapped(DateTime(2026, 11, 29)),
        startsAt: Wrapped(mon.copyWith(hour: 12)),
        endsAt: Wrapped(tue.copyWith(hour: 13)),
      );
      await tester.runAsync(() async {
        for (final task in [timed, dated, range]) {
          await app.tasksRepository.addTask(task);
        }
        await app.workLogsRepository.addWorkLog(
          WorkLog(
            id: 'week-log',
            taskId: dated.id,
            status: 1,
            date: mon,
            description: 'История задачи',
          ),
        );
      });
      app.tasksViewModel.updateFilter(
        (old) => old.copyWith(anchorDate: mon, period: DatePeriod.week),
      );
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('tasks');
      await pumpStorage(tester);
      Finder day(DateTime date) => find.byKey(ValueKey(('week.day', date)));
      Finder card(Task task, DateTime date) =>
          find.byKey(ValueKey(('week.task', date, task.id)));
      Future<void> move(Task task, DateTime from, DateTime to) async {
        final source = card(task, from);
        final rect = tester.getRect(source);
        final gesture = await tester.startGesture(rect.center);
        await tester.pump(const Duration(milliseconds: 600));
        final feedback = find.byKey(ValueKey(('week.feedback', from, task.id)));
        expect(tester.getRect(feedback).topLeft, rect.topLeft);
        expect(tester.getSize(feedback).width, closeTo(rect.width, .01));
        expect(tester.getSize(feedback).height, closeTo(rect.height, .01));
        await gesture.moveTo(tester.getCenter(day(to)));
        await tester.pump();
        await gesture.up();
        await pumpStorage(tester);
      }

      expect(find.byKey(const ValueKey('tasks.week.vertical')), findsOneWidget);
      expect(
        tester.getTopLeft(day(tue)).dy,
        greaterThan(tester.getTopLeft(day(mon)).dy),
      );
      await move(timed, mon, tue);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(timed.id),
        ))!.startsAt,
        tue.copyWith(hour: 9),
      );
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(timed.id),
        ))!.endsAt,
        tue.copyWith(hour: 10),
      );
      final regularHeight = tester.getSize(card(range, mon)).height;
      await tester.tap(find.byKey(const ValueKey('tasks.week-layout')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('tasks.week.horizontal')),
        findsOneWidget,
      );
      expect(tester.getTopLeft(day(mon)).dy, tester.getTopLeft(day(tue)).dy);
      expect(
        tester.getTopLeft(day(tue)).dx,
        greaterThan(tester.getTopLeft(day(mon)).dx),
      );
      final horizontal = find.byKey(const ValueKey('tasks.week.horizontal'));
      expect(
        tester.getRect(day(sun)).right,
        lessThanOrEqualTo(tester.getRect(horizontal).right + .01),
      );
      expect(tester.getSize(card(range, mon)).height, lessThan(regularHeight));
      final title = find.descendant(
        of: card(range, mon),
        matching: find.text(range.title),
      );
      expect(tester.widget<Text>(title).maxLines, 2);
      final logsToggle = find.descendant(
        of: card(dated, mon),
        matching: find.byKey(const ValueKey('task.worklogs.toggle')),
      );
      expect(find.text('Ворклоги · 1'), findsOneWidget);
      expect(tester.getSize(logsToggle).height, lessThan(30));
      expect(find.text('История задачи'), findsNothing);
      await tester.tap(logsToggle);
      await tester.pumpAndSettle();
      expect(find.text('История задачи'), findsOneWidget);
      await move(dated, mon, wed);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(dated.id),
        ))!.startsAt,
        wed.startOfDay,
      );
      await move(range, tue, thu);
      final savedRange = (await tester.runAsync(
        () => app.tasksRepository.getById(range.id),
      ))!;
      expect(savedRange.startsAt, wed.copyWith(hour: 12));
      expect(savedRange.endsAt, thu.copyWith(hour: 13));
      expect(card(range, mon), findsNothing);
      expect(card(range, wed), findsOneWidget);
      expect(card(range, thu), findsOneWidget);
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.drag(horizontal, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(day(sun).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tasks.week-layout')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tasks.week.vertical')), findsOneWidget);
      expect(app.tasksViewModel.currentFilterValue.anchorDate, mon);
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );
}
