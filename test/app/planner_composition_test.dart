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
    'hierarchy tasks drop into day panel or time grid and cancel without changes',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () =>
            createTestApp(enableObsidian: false, includePlanningScreens: true),
      ))!;
      final monday = getWeekStart(DateTime.now());
      final project = Project.create(name: 'Hierarchy project');
      final task = Task.blank().copyWith(
        title: 'Hierarchy task',
        projectId: Wrapped(project.id),
      );
      await tester.runAsync(() => app.projectsRepository.addProject(project));
      await tester.runAsync(() => app.tasksRepository.addTask(task));
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('planner');
      await pumpStorage(tester);
      final timeline = find.descendant(
        of: find.byType(PlannerScreen),
        matching: find.byType(TimelineBody),
      );
      final tree = find.byType(HierarchyColumn);
      final source = find.descendant(of: tree, matching: find.text(task.title));
      Future<TestGesture> startDrag() async {
        final gesture = await tester.startGesture(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 600));
        return gesture;
      }

      final panel = find.byKey(const ValueKey('timeline.date-only'));
      final enter = tester.getTopLeft(timeline) + const Offset(200, 220);
      final cancelled = await startDrag();
      await cancelled.moveTo(enter);
      await tester.pump();
      expect(panel, findsOneWidget);
      await cancelled.moveTo(tester.getCenter(source));
      await tester.pump();
      await cancelled.up();
      await pumpStorage(tester);
      expect(panel, findsNothing);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(task.id),
        ))!.startsAt,
        isNull,
      );

      final toDay = await startDrag();
      await toDay.moveTo(enter);
      await tester.pump();
      final target = monday.add(const Duration(days: 2));
      final column = find.byKey(ValueKey(('timeline.panel-day', target)));
      await toDay.moveTo(tester.getCenter(column));
      await tester.pump();
      await toDay.up();
      await pumpStorage(tester);
      final dated = (await tester.runAsync(
        () => app.tasksRepository.getById(task.id),
      ))!;
      expect(dated.startsAt, target.startOfDay);
      expect(dated.endsAt, isNull);
      expect(
        find.descendant(
          of: column,
          matching: find.byKey(ValueKey('timeline.date-only.${task.id}')),
        ),
        findsOneWidget,
      );

      // A collapsed panel also opens for hierarchy drags; the grid remains a time target.
      await tester.tap(find.byTooltip('Скрыть панель задач'));
      await tester.pump();
      final toCollapsedDay = await startDrag();
      await toCollapsedDay.moveTo(enter);
      await tester.pump();
      final anotherDay = monday.add(const Duration(days: 3));
      await toCollapsedDay.moveTo(
        tester.getCenter(
          find.byKey(ValueKey(('timeline.panel-day', anotherDay))),
        ),
      );
      await tester.pump();
      await toCollapsedDay.up();
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(task.id),
        ))!.startsAt,
        anotherDay.startOfDay,
      );
      expect(tester.getSize(panel).height, 30);
      final toTime = await startDrag();
      await toTime.moveTo(enter);
      await tester.pump();
      expect(tester.getSize(panel).height, greaterThan(30));
      await toTime.moveTo(tester.getTopLeft(timeline) + const Offset(400, 600));
      await tester.pump();
      await toTime.up();
      await pumpStorage(tester);
      final timed = (await tester.runAsync(
        () => app.tasksRepository.getById(task.id),
      ))!;
      expect(timed.startsAt!.isDateOnly, isFalse);
      expect(timed.endsAt, isNotNull);
      expect(
        tester.widget<TimelineBody>(timeline).events.single.task.id,
        task.id,
      );
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'timed task can be dragged into an empty day panel and saved without time',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () =>
            createTestApp(enableObsidian: false, includePlanningScreens: true),
      ))!;
      final monday = getWeekStart(DateTime.now());
      final task = Task.blank().copyWith(
        title: 'Move out of time blocking',
        startsAt: Wrapped(monday.copyWith(hour: 6)),
        endsAt: Wrapped(monday.copyWith(hour: 7)),
      );
      await tester.runAsync(() => app.tasksRepository.addTask(task));
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('planner');
      await pumpStorage(tester);
      final timeline = find.descendant(
        of: find.byType(PlannerScreen),
        matching: find.byType(TimelineBody),
      );
      final vertical = tester
          .widgetList<SingleChildScrollView>(
            find.descendant(
              of: timeline,
              matching: find.byType(SingleChildScrollView),
            ),
          )
          .firstWhere(
            (view) =>
                view.scrollDirection == Axis.vertical &&
                view.controller != null,
          )
          .controller!;
      vertical.jumpTo(400);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('timeline.date-only')), findsNothing);
      final event = find.descendant(
        of: timeline,
        matching: find.byKey(ValueKey(task.id)),
      );
      final gesture = await tester.startGesture(tester.getCenter(event));
      await tester.pump(const Duration(milliseconds: 600));
      final target = monday.add(const Duration(days: 1));
      final column = find.byKey(ValueKey(('timeline.panel-day', target)));
      expect(column, findsOneWidget);
      await gesture.moveTo(tester.getCenter(column));
      await tester.pump();
      await gesture.up();
      await pumpStorage(tester);
      final saved = (await tester.runAsync(
        () => app.tasksRepository.getById(task.id),
      ))!;
      expect(saved.startsAt, target.startOfDay);
      expect(saved.endsAt, isNull);
      expect(tester.widget<TimelineBody>(timeline).events, isEmpty);
      expect(
        find.descendant(
          of: column,
          matching: find.byKey(ValueKey('timeline.date-only.${task.id}')),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'browsing weeks keeps the chosen day until an explicit date selection',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () =>
            createTestApp(enableObsidian: false, includePlanningScreens: true),
      ))!;
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('planner');
      await pumpStorage(tester);
      final planner = find.byType(PlannerScreen);
      final model = tester.widget<PlannerScreen>(planner).tasks;
      final timeline = find.descendant(
        of: planner,
        matching: find.byType(TimelineBody),
      );
      TimelineBody body() => tester.widget<TimelineBody>(timeline);
      Finder day(DateTime date) => find.byKey(ValueKey(('timeline.day', date)));
      Color border(DateTime date) => tester
          .widgetList<DecoratedBox>(
            find.descendant(of: day(date), matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .where((decoration) => decoration.border != null)
          .first
          .border!
          .top
          .color;

      final monday = body().weekStart!;
      final chosen = monday.add(const Duration(days: 2));
      await tester.tap(day(chosen));
      await tester.pump();
      expect(body().anchorDate, chosen);
      expect(border(chosen), Colors.white.withValues(alpha: .6));
      await pumpStorage(tester);
      final header = find.byKey(const ValueKey('timeline.header-scroll'));
      await tester.drag(header, const Offset(-1000, 0));
      await tester.pumpAndSettle();
      await pumpStorage(tester);
      final nextWeek = monday.add(const Duration(days: 7));
      expect(body().weekStart, nextWeek);
      expect(body().anchorDate, chosen);
      expect(border(chosen), Colors.white.withValues(alpha: .6));
      expect(border(nextWeek), isNot(Colors.white.withValues(alpha: .6)));

      await tester.tap(find.byTooltip('Previous week'));
      await pumpStorage(tester);
      expect(body().weekStart, monday);
      expect(body().anchorDate, chosen);
      await tester.tap(find.byTooltip('Next week'));
      await pumpStorage(tester);
      expect(body().weekStart, nextWeek);
      expect(body().anchorDate, chosen);

      final nextChosen = nextWeek.add(const Duration(days: 1));
      await tester.tap(day(nextChosen));
      await tester.pump();
      expect(body().anchorDate, nextChosen);
      expect(border(nextChosen), Colors.white.withValues(alpha: .6));
      await pumpStorage(tester);
      final externalDate = monday.subtract(const Duration(days: 3));
      model.updateFilter((old) => old.copyWith(anchorDate: externalDate));
      await pumpStorage(tester);
      expect(body().anchorDate, externalDate);
      expect(border(externalDate), Colors.white.withValues(alpha: .6));
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'adjacent timed tasks are visible during scroll before the selected week changes',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () =>
            createTestApp(enableObsidian: false, includePlanningScreens: true),
      ))!;
      final monday = getWeekStart(DateTime.now());
      final previous = Task.blank().copyWith(
        title: 'Previous week task',
        startsAt: Wrapped(
          DateTime(monday.year, monday.month, monday.day - 3, 9),
        ),
        endsAt: Wrapped(
          DateTime(monday.year, monday.month, monday.day - 3, 10),
        ),
      );
      final next = Task.blank().copyWith(
        title: 'Next week task',
        startsAt: Wrapped(
          DateTime(monday.year, monday.month, monday.day + 8, 9),
        ),
        endsAt: Wrapped(
          DateTime(monday.year, monday.month, monday.day + 8, 10),
        ),
      );
      await tester.runAsync(() async {
        await app.tasksRepository.addTask(previous);
        await app.tasksRepository.addTask(next);
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('planner');
      await pumpStorage(tester);
      final planner = find.byType(PlannerScreen);
      final model = tester.widget<PlannerScreen>(planner).tasks;
      final anchor = model.currentFilterValue.anchorDate;
      final timeline = find.descendant(
        of: planner,
        matching: find.byType(TimelineBody),
      );
      expect(
        tester
            .widget<TimelineBody>(timeline)
            .events
            .map((event) => event.task.id),
        [previous.id, next.id],
      );
      final horizontal = tester
          .widgetList<SingleChildScrollView>(
            find.descendant(
              of: timeline,
              matching: find.byType(SingleChildScrollView),
            ),
          )
          .firstWhere(
            (view) =>
                view.scrollDirection == Axis.horizontal &&
                view.controller != null,
          )
          .controller!;
      horizontal.jumpTo(horizontal.offset + 450);
      await tester.pump();
      expect(
        model.currentFilterValue.anchorDate,
        anchor,
        reason: 'The selected week must not have switched yet',
      );
      final futureCard = find.descendant(
        of: timeline,
        matching: find.byKey(ValueKey(next.id)),
      );
      final intersection = tester
          .getRect(futureCard)
          .intersect(tester.getRect(timeline));
      expect(
        intersection.width,
        greaterThan(0),
        reason:
            'The next-week event is already rendered in the entering columns',
      );
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'range tasks cover each day and panel can be hidden across navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1800, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () =>
            createTestApp(enableObsidian: false, includePlanningScreens: true),
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
        30,
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
        () =>
            createTestApp(enableObsidian: false, includePlanningScreens: true),
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
      expect(
        timeline().dateOnlyTasks.map((t) => t.id),
        [withoutTime.id, nextWeek.id],
        reason: 'The next week must be ready before the selected week changes',
      );
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
      expect(timeline().dateOnlyTasks.map((t) => t.id), [
        withoutTime.id,
        nextWeek.id,
      ]);
      await tester.tap(find.byTooltip('Previous week'));
      await pumpStorage(tester);
      await tester.tap(card);
      await pumpStorage(tester);
      expect(app.navigation.selectedId, 'planner');
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
      expect(timeline().dateOnlyTasks.map((t) => t.id), [nextWeek.id]);
      expect(timeline().events.single.task.id, withoutTime.id);
      expect(
        find.byKey(ValueKey('timeline.date-only.${withoutTime.id}')),
        findsNothing,
      );
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
        () =>
            createTestApp(enableObsidian: false, includePlanningScreens: true),
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
      expect(
        tester.widget<TimelineBody>(timelineFinder).events.single.task.id,
        task.id,
        reason: 'The previous week stays available in the scroll buffer',
      );
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
      expect(app.navigation.selectedId, 'planner');
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
      expect(app.navigation.selectedId, 'planner');
      expect(find.text('Иерархия'), findsNothing);
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );
}
