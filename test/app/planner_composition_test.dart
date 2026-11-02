import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits_api/habits_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:projects_api/projects_api.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/features/planner/presentation/planner_screen.dart';
import 'package:life_os/features/tasks/presentation/components/timeline.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  testWidgets(
    'range tasks cover each day and panel can be hidden across navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final monday = getWeekStart(DateTime.now());
      final range = Task.blank().copyWith(
        title: 'Длительная задача',
        startsAt: Wrapped(
          DateTime(monday.year, monday.month, monday.day - 10, 9),
        ),
        endsAt: Wrapped(
          DateTime(monday.year, monday.month, monday.day + 1, 18),
        ),
      );
      await tester.runAsync(() => app.tasksRepository.addTask(range));
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('planner');
      await pumpStorage(tester);
      Finder column(int offset) => find.byKey(
        ValueKey((
          'timeline.panel-day',
          DateTime(monday.year, monday.month, monday.day + offset),
        )),
      );
      expect(
        find.descendant(of: column(0), matching: find.text(range.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: column(1), matching: find.text(range.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: column(2), matching: find.text(range.title)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: column(0),
          matching: find.byIcon(Icons.date_range_outlined),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Скрыть панель задач'));
      await tester.pump();
      expect(find.text(range.title), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('timeline.date-only'))).height,
        28,
      );
      await tester.tap(find.byTooltip('Previous week'));
      await pumpStorage(tester);
      expect(find.byTooltip('Показать панель задач'), findsOneWidget);
      await tester.tap(find.byTooltip('Показать панель задач'));
      await tester.pump();
      expect(find.text(range.title), findsWidgets);
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'date-only tasks appear in their day and can be scheduled or opened',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final monday = getWeekStart(DateTime.now());
      final withoutTime = Task.blank().copyWith(
        title: 'Без времени',
        startsAt: Wrapped(monday.startOfDay),
      );
      final nextWeek = Task.blank().copyWith(
        title: 'Следующая неделя',
        startsAt: Wrapped(
          DateTime(monday.year, monday.month, monday.day + 7).startOfDay,
        ),
      );
      final noDate = Task.blank().copyWith(title: 'Без даты');
      await tester.runAsync(() async {
        for (final task in [withoutTime, nextWeek, noDate]) {
          await app.tasksRepository.addTask(task);
        }
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('planner');
      await pumpStorage(tester);
      final timelineFinder = find.descendant(
        of: find.byType(PlannerScreen),
        matching: find.byType(TimelineBody),
      );
      TimelineBody timeline() => tester.widget<TimelineBody>(timelineFinder);
      expect(timeline().dateOnlyTasks.map((t) => t.id), [withoutTime.id]);
      expect(timeline().events, isEmpty);
      final card = find.byKey(ValueKey('timeline.date-only.${withoutTime.id}'));
      final day = find.byKey(ValueKey(('timeline.day', monday)));
      expect(
        tester.getRect(card).center.dx,
        closeTo(tester.getRect(day).center.dx, 1),
      );
      expect(tester.getRect(card).top, greaterThan(tester.getRect(day).bottom));
      await tester.tap(
        find.descendant(of: card, matching: find.byTooltip('Выполнить')),
      );
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(withoutTime.id),
        ))!.isCompleted,
        isTrue,
      );
      await tester.tap(find.byTooltip('Next week'));
      await pumpStorage(tester);
      expect(timeline().dateOnlyTasks.map((t) => t.id), [nextWeek.id]);
      await tester.tap(find.byTooltip('Previous week'));
      await pumpStorage(tester);
      await tester.tap(card);
      await pumpStorage(tester);
      expect(app.navigation.selectedId, 'tasks');
      expect(app.tasksViewModel.activeTaskWithProject?.task.id, withoutTime.id);
      app.tasksViewModel.hideForm();
      app.navigation.open('planner');
      await pumpStorage(tester);
      timeline().onExternalDrop!(
        withoutTime,
        monday.copyWith(hour: 9),
        monday.copyWith(hour: 10),
      );
      await pumpStorage(tester);
      expect(timeline().dateOnlyTasks, isEmpty);
      expect(timeline().events.single.task.id, withoutTime.id);
      expect(find.byKey(const ValueKey('timeline.date-only')), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'planner reuses hierarchy and timeline with independent filters',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final project = Project.create(name: 'Проект календаря');
      final task = Task.blank().copyWith(
        title: 'Работа над макетом',
        projectId: Wrapped(project.id),
        startsAt: Wrapped(today.copyWith(hour: 8)),
        endsAt: Wrapped(today.copyWith(hour: 10)),
      );
      final habit = Habit.create(title: 'Зарядка', type: const MorningHabit());
      final originalFilter = TaskFilterConfig(
        anchorDate: DateTime(2025, 1, 1),
        period: DatePeriod.month,
      );
      app.tasksViewModel.updateFilter((_) => originalFilter);
      app.habitsViewModel.selectDate(originalFilter.anchorDate);
      await tester.runAsync(() async {
        await app.projectsRepository.addProject(project);
        await app.tasksRepository.addTask(task);
        await app.habitsRepository.addHabit(habit);
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('planner');
      await pumpStorage(tester);
      final planner = find.byType(PlannerScreen);
      final timelineFinder = find.descendant(
        of: planner,
        matching: find.byType(TimelineBody),
      );
      final treeFinder = find.descendant(
        of: planner,
        matching: find.byType(HierarchyColumn),
      );
      expect(treeFinder, findsOneWidget);
      expect(timelineFinder, findsOneWidget);
      expect(
        tester.widget<TimelineBody>(timelineFinder).events.single.task.id,
        task.id,
      );
      final eventFinder = find.descendant(
        of: timelineFinder,
        matching: find.byKey(ValueKey(task.id)),
      );
      final initialHeight = tester.getSize(eventFinder).height;
      await tester.tap(find.byTooltip('Zoom in'));
      await pumpStorage(tester);
      expect(tester.getSize(eventFinder).height, greaterThan(initialHeight));
      await tester.tap(find.byTooltip('Next week'));
      await pumpStorage(tester);
      expect(tester.widget<TimelineBody>(timelineFinder).events, isEmpty);
      expect(app.tasksViewModel.currentFilterValue, originalFilter);
      await tester.tap(find.byTooltip('Previous week'));
      await pumpStorage(tester);
      expect(
        tester.widget<TimelineBody>(timelineFinder).events.single.task.id,
        task.id,
      );
      await tester.tap(find.byKey(ValueKey('planner-habit-${habit.id}')));
      await pumpStorage(tester);
      expect(find.text('Выполнено'), findsOneWidget);
      expect(app.habitsViewModel.selectedDate, originalFilter.anchorDate);

      // The ready-made timeline commands must write through the shared APIs.
      tester
          .widget<TimelineBody>(timelineFinder)
          .onEventChanged(task, startMinutes: 9 * 60, durationMinutes: 90);
      await pumpStorage(tester);
      final moved = (await tester.runAsync(
        () => app.tasksRepository.getById(task.id),
      ))!;
      expect(moved.startsAt, today.copyWith(hour: 9));
      expect(moved.endsAt, today.copyWith(hour: 10, minute: 30));
      tester.widget<TimelineBody>(timelineFinder).onToggleTask(moved);
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(task.id),
        ))!.isCompleted,
        isTrue,
      );
      final draft = Task.blank().copyWith(
        title: 'Создано в календаре',
        startsAt: Wrapped(today.copyWith(hour: 12)),
      );
      await tester.runAsync(
        () =>
            tester.widget<TimelineBody>(timelineFinder).onSubmitNewTask!(draft),
      );
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(draft.id),
        ))!.title,
        draft.title,
      );
      tester.widget<TimelineBody>(timelineFinder).onExternalDrop!(
        draft,
        today.copyWith(hour: 13),
        today.copyWith(hour: 14),
      );
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(draft.id),
        ))!.startsAt,
        today.copyWith(hour: 13),
      );
      expect(app.tasksViewModel.currentFilterValue, originalFilter);

      await tester.tap(
        find.descendant(of: treeFinder, matching: find.text(task.title)),
      );
      await pumpStorage(tester);
      expect(app.navigation.selectedId, 'tasks');
      expect(app.tasksViewModel.activeTaskWithProject?.task.id, task.id);
      app.tasksViewModel.hideForm();
      app.navigation.open('planner');
      await pumpStorage(tester);
      tester.view.physicalSize = const Size(390, 844);
      await pumpStorage(tester);
      expect(timelineFinder, findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Проекты и привычки'));
      await pumpStorage(tester);
      expect(find.byType(HierarchyColumn), findsOneWidget);
      expect(find.text('Зарядка'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(HierarchyColumn),
          matching: find.text(task.title),
        ),
      );
      await pumpStorage(tester);
      expect(app.navigation.selectedId, 'tasks');
      expect(find.text('Иерархия'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );
}
