import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:tasks_api/tasks_api.dart' show Task;
import 'package:life_os/features/tasks/presentation/components/mini_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/timeline.dart';
import 'package:life_os/features/tasks/presentation/components/calendar_task_hint.dart';
import 'package:life_os/core/ui/glass_panel.dart';

import '../../test_helpers.dart';

void _noopEventChanged(
  Task task, {
  int? startMinutes,
  int? durationMinutes,
  DateTime? newDate,
}) {}

void main() {
  for (final isWeek in [true, false]) {
    testWidgets(
      'resizing the day panel keeps time-grid position in ${isWeek ? 'week' : 'day'} mode',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final monday = DateTime(2026, 11, 2);
        final panelTask = createMockTask(
          startsAt: monday.add(const Duration(milliseconds: 1)),
        );
        final timedTask = createMockTask(title: 'Fixed calendar event');
        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [
                TaskEvent(
                  task: timedTask,
                  title: timedTask.title,
                  date: monday,
                  startMinutes: 360,
                  durationMinutes: 60,
                ),
              ],
              dateOnlyTasks: [panelTask],
              weekStart: isWeek ? monday : null,
              anchorDate: monday,
              topPadding: 60,
              onWeekChange: (_) {},
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        final vertical = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (view) =>
                  view.scrollDirection == Axis.vertical &&
                  view.controller != null,
            )
            .controller!;
        final event = find.byKey(ValueKey(timedTask.id));
        final panel = find.byKey(const ValueKey('timeline.date-only'));
        for (final offset in [400.0, vertical.position.maxScrollExtent]) {
          vertical.jumpTo(offset);
          await tester.pumpAndSettle();
          final eventY = tester.getTopLeft(event).dy;
          final scrollOffset = vertical.offset;
          final extent = vertical.position.maxScrollExtent;
          final initialHeight = tester.getSize(panel).height;
          final gesture = await tester.startGesture(
            tester.getCenter(
              find.byKey(const ValueKey('timeline.panel-resize')),
            ),
          );
          for (final delta in [40.0, 40.0, -60.0]) {
            await gesture.moveBy(Offset(0, delta));
            await tester.pump();
            expect(vertical.offset, closeTo(scrollOffset, .1));
            expect(vertical.position.maxScrollExtent, closeTo(extent, .1));
            expect(
              tester.getTopLeft(event).dy,
              closeTo(eventY, .1),
              reason: 'Resizing the overlay must not move hours or events',
            );
          }
          await gesture.up();
          await tester.pumpAndSettle();
          expect(tester.getSize(panel).height, isNot(initialHeight));
          expect(tester.getTopLeft(event).dy, closeTo(eventY, .1));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'rebasing the week keeps headers and tasks fixed in the first frame',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final monday = DateTime(2026, 11, 2);
      final next = monday.add(const Duration(days: 7));
      final task = Task.blank().copyWith(title: 'Stable task');
      var week = monday;
      DateTime? requestedWeek;
      Widget build() => createTestWidget(
        child: TimelineBody(
          events: [
            TaskEvent(
              task: task,
              title: task.title,
              date: next,
              startMinutes: 180,
              durationMinutes: 60,
            ),
          ],
          topPadding: 0,
          weekStart: week,
          anchorDate: monday,
          onWeekChange: (date) => requestedWeek = date,
          onEventChanged: _noopEventChanged,
          onToggleTask: (_) {},
        ),
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('timeline.header-scroll'));
      final scroll = tester.widget<SingleChildScrollView>(header).controller!;
      final day = find.byKey(ValueKey(('timeline.day', next)));
      final width = tester.getSize(day).width;
      // A wheel gesture may end between day boundaries; preserve that fraction.
      scroll.position.pointerScroll(width * 5.25);
      await tester.pumpAndSettle();
      expect(
        requestedWeek,
        next,
        reason:
            'offset=${scroll.offset}, width=$width, viewport=${scroll.position.viewportDimension}',
      );
      final dayBefore = tester.getTopLeft(day);
      final taskBefore = tester.getTopLeft(find.byKey(ValueKey(task.id)));
      week = requestedWeek!;
      await tester.pumpWidget(build());
      expect(
        tester.getTopLeft(day).dx,
        closeTo(dayBefore.dx, .1),
        reason: 'The header must rebase before painting, not one frame later',
      );
      expect(
        tester.getTopLeft(find.byKey(ValueKey(task.id))).dx,
        closeTo(taskBefore.dx, .1),
        reason: 'Rebasing must preserve partial-day offsets',
      );
      await tester.pump();
      expect(tester.getTopLeft(day).dx, closeTo(dayBefore.dx, .1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'week highlight follows an unfinished swipe without waiting for data or animation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final monday = DateTime(2026, 11, 2);
      final previous = DateTime(2026, 10, 26);
      var selectedWeekChanges = 0;
      await tester.pumpWidget(
        createTestWidget(
          child: TimelineBody(
            events: const [],
            topPadding: 0,
            weekStart: monday,
            anchorDate: monday,
            onWeekChange: (_) => selectedWeekChanges++,
            onEventChanged: _noopEventChanged,
            onToggleTask: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      double highlight(DateTime date) => tester
          .widgetList<Container>(
            find.descendant(
              of: find.byKey(ValueKey(('timeline.day', date))),
              matching: find.byType(Container),
            ),
          )
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .firstWhere((d) => d.color != null)
          .color!
          .a;
      final header = find.byKey(const ValueKey('timeline.header-scroll'));
      expect(highlight(monday), greaterThan(highlight(previous)));
      expect(find.text('02.11 – 08.11'), findsOneWidget);
      final gesture = await tester.startGesture(tester.getCenter(header));
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(150, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        selectedWeekChanges,
        0,
        reason: 'The pointer is still down; the data week has not changed',
      );
      expect(
        highlight(previous),
        greaterThan(highlight(monday)),
        reason: 'Visual highlight must already follow the visible week',
      );
      expect(find.text('26.10 – 01.11'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(-150, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(highlight(monday), greaterThan(highlight(previous)));
      expect(find.text('02.11 – 08.11'), findsOneWidget);
      expect(selectedWeekChanges, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'small horizontal wheel steps are not snapped away and fast flings keep momentum',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final monday = DateTime(2026, 11, 2);
      await tester.pumpWidget(
        createTestWidget(
          child: TimelineBody(
            events: const [],
            topPadding: 0,
            weekStart: monday,
            anchorDate: monday,
            onWeekChange: (_) {},
            onEventChanged: _noopEventChanged,
            onToggleTask: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('timeline.header-scroll'));
      final controller = tester
          .widget<SingleChildScrollView>(header)
          .controller!;
      final initial = controller.offset;
      for (var i = 0; i < 4; i++) {
        tester.binding.handlePointerEvent(
          PointerScrollEvent(
            position: tester.getCenter(header),
            scrollDelta: const Offset(24, 0),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          controller.offset - initial,
          closeTo((i + 1) * 24, 1),
          reason:
              'Small wheel steps must accumulate instead of returning to the nearest day',
        );
      }
      final beforeFling = controller.offset;
      // Keep enough pointer samples to estimate release velocity reliably.
      await tester.fling(header, const Offset(-200, 0), 3000);
      await tester.pumpAndSettle();
      expect(
        controller.offset - beforeFling,
        greaterThan(300),
        reason: 'A fast fling must travel more than a single day column',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'header and grid follow small continuous drag updates without fighting or slowing',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final monday = DateTime(2026, 11, 2);
      await tester.pumpWidget(
        createTestWidget(
          child: TimelineBody(
            events: const [],
            topPadding: 0,
            weekStart: monday,
            anchorDate: monday,
            onWeekChange: (_) {},
            onEventChanged: _noopEventChanged,
            onToggleTask: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('timeline.header-scroll'));
      final headerController = tester
          .widget<SingleChildScrollView>(header)
          .controller!;
      final grid = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .firstWhere(
            (w) => w.scrollDirection == Axis.horizontal && w.controller != null,
          )
          .controller!;
      for (final origin in [tester.getCenter(header), const Offset(600, 500)]) {
        final initial = grid.offset;
        var previous = initial;
        final gesture = await tester.startGesture(origin);
        for (var i = 0; i < 10; i++) {
          await gesture.moveBy(const Offset(-24, 0));
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            grid.offset,
            greaterThanOrEqualTo(previous - .1),
            reason: 'Scroll must not snap back during a drag',
          );
          expect(headerController.offset, closeTo(grid.offset, 1));
          previous = grid.offset;
        }
        expect(
          grid.offset - initial,
          inInclusiveRange(210, 250),
          reason:
              '240 pixels of pointer motion must not be damped by synchronization',
        );
        await gesture.up();
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'week header stays highlighted and synchronized while swiping between weeks',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var week = DateTime(2026, 11, 2);
      await tester.pumpWidget(
        createTestWidget(
          child: StatefulBuilder(
            builder: (_, update) => TimelineBody(
              events: const [],
              topPadding: 0,
              weekStart: week,
              anchorDate: week,
              onWeekChange: (date) => update(
                () => week = DateTime(
                  date.year,
                  date.month,
                  date.day - date.weekday + 1,
                ),
              ),
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final header = find.byKey(const ValueKey('timeline.header-scroll'));
      ScrollController headerScroll() =>
          tester.widget<SingleChildScrollView>(header).controller!;
      ScrollController gridScroll() => tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .firstWhere(
            (w) => w.scrollDirection == Axis.horizontal && w.controller != null,
          )
          .controller!;
      Finder day(DateTime date) => find.byKey(ValueKey(('timeline.day', date)));
      double highlight(DateTime date) {
        final backgrounds = tester.widgetList<Container>(
          find.descendant(of: day(date), matching: find.byType(Container)),
        );
        return backgrounds
            .map((w) => w.decoration)
            .whereType<BoxDecoration>()
            .firstWhere((d) => d.color != null)
            .color!
            .a;
      }

      expect(
        highlight(week),
        greaterThan(highlight(week.subtract(const Duration(days: 1)))),
      );
      expect(
        find.descendant(of: day(week), matching: find.byType(GlassPanel)),
        findsNothing,
        reason: 'An opaque surface must not cover the selected-week background',
      );
      final gesture = await tester.startGesture(tester.getCenter(header));
      final initialOffset = headerScroll().offset;
      for (var i = 0; i < 5; i++) {
        await gesture.moveBy(const Offset(70, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(headerScroll().offset, closeTo(gridScroll().offset, 1));
      expect(
        headerScroll().offset,
        lessThan(initialOffset),
        reason:
            'header should actually scroll, max=${headerScroll().position.maxScrollExtent}',
      );
      // Both weeks are still present at the halfway position, with no gap.
      final columnWidth = tester.getSize(day(week)).width;
      for (var offset = -2; offset < 5; offset++) {
        final date = DateTime(week.year, week.month, week.day + offset);
        final next = DateTime(date.year, date.month, date.day + 1);
        expect(
          tester.getTopLeft(day(next)).dx - tester.getTopLeft(day(date)).dx,
          closeTo(columnWidth, 1),
        );
        expect(
          tester.getRect(day(date)).intersect(tester.getRect(header)).width,
          greaterThan(0),
        );
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(day(DateTime(2026, 11, 2)).hitTestable(), findsOneWidget);
      await tester.drag(header, const Offset(1000, 0));
      await tester.pumpAndSettle();
      expect(week, DateTime(2026, 10, 26));
      expect(headerScroll().offset, closeTo(gridScroll().offset, 1));
      expect(
        highlight(week),
        greaterThan(highlight(week.subtract(const Duration(days: 1)))),
      );
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: tester.getCenter(header),
          scrollDelta: const Offset(300, 0),
        ),
      );
      await tester.pumpAndSettle();
      expect(headerScroll().offset, closeTo(gridScroll().offset, 1));
      tester.view.physicalSize = const Size(800, 850);
      await tester.pumpAndSettle();
      expect(headerScroll().offset, closeTo(gridScroll().offset, 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'panel resizes, moves date and range tasks between days, and reuses cards during scroll',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final monday = DateTime(2026, 11, 2);
      final task = createMockTask(
        id: 'panel-task',
        title: 'Panel task',
        startsAt: monday.add(const Duration(milliseconds: 1)),
      );
      final range = createMockTask(
        id: 'panel-range',
        title: 'Panel range',
        startsAt: DateTime(2026, 11, 3, 9),
        endsAt: DateTime(2026, 11, 5, 18),
      );
      final moves = <(String, DateTime, DateTime)>[];
      await tester.pumpWidget(
        createTestWidget(
          child: TimelineBody(
            events: const [],
            dateOnlyTasks: [task, range],
            weekStart: monday,
            anchorDate: monday,
            topPadding: 0,
            onWeekChange: (_) {},
            onEventChanged: _noopEventChanged,
            onToggleTask: (_) {},
            onDayTaskMoved: (task, source, target) =>
                moves.add((task.id, source, target)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final panel = find.byKey(const ValueKey('timeline.date-only'));
      final initial = tester.getSize(panel).height;
      await tester.drag(
        find.byKey(const ValueKey('timeline.panel-resize')),
        const Offset(0, 80),
      );
      await tester.pumpAndSettle();
      final resized = tester.getSize(panel).height;
      expect(resized, greaterThan(initial + 40));
      await tester.tap(find.byTooltip('Скрыть панель задач'));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, 30);
      await tester.tap(find.byTooltip('Показать панель задач'));
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, resized);
      Finder column(int day) =>
          find.byKey(ValueKey(('timeline.panel-day', DateTime(2026, 11, day))));
      Future<void> move(String id, int from, int to) async {
        final source = find.descendant(
          of: column(from),
          matching: find.byKey(ValueKey('timeline.date-only.$id')),
        );
        final gesture = await tester.startGesture(tester.getCenter(source));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(tester.getCenter(column(to)));
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
      }

      await move(task.id, 2, 3);
      await move(range.id, 4, 6);
      expect(moves, [
        (task.id, monday, DateTime(2026, 11, 3)),
        (range.id, DateTime(2026, 11, 4), DateTime(2026, 11, 6)),
      ]);
      final previous = debugOnRebuildDirtyWidget;
      var cardBuilds = 0;
      debugOnRebuildDirtyWidget = (element, built) {
        if (element.widget is CalendarTaskHint) cardBuilds++;
        previous?.call(element, built);
      };
      addTearDown(() => debugOnRebuildDirtyWidget = previous);
      final scroll = tester
          .widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView))
          .firstWhere(
            (scroll) =>
                scroll.scrollDirection == Axis.horizontal &&
                scroll.controller != null,
          )
          .controller!;
      for (var i = 0; i < 5; i++) {
        scroll.jumpTo(scroll.offset + 8);
        await tester.pump();
      }
      expect(
        cardBuilds,
        0,
        reason:
            'Horizontal scrolling should translate cached cards, not rebuild them',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('date-only day row scrolls and drags a task into the time grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final day = DateTime(2026, 11, 2);
    final tasks = List.generate(
      6,
      (i) => createMockTask(
        id: 'date-only-$i',
        title: 'Task $i',
        startsAt: day.add(const Duration(milliseconds: 1)),
      ),
    );
    DateTime? droppedStart;
    String? droppedId;
    await tester.pumpWidget(
      createTestWidget(
        child: TimelineBody(
          events: const [],
          dateOnlyTasks: tasks,
          anchorDate: day,
          topPadding: 0,
          onEventChanged: _noopEventChanged,
          onToggleTask: (_) {},
          onExternalDrop: (task, startsAt, endsAt) {
            droppedId = task.id;
            droppedStart = startsAt;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('timeline.date-only'));
    expect(tester.getSize(row).height, lessThan(180));
    await tester.drag(
      find.descendant(of: row, matching: find.byType(ListView)),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('timeline.date-only.date-only-5'));
    expect(card.hitTestable(), findsOneWidget);
    final gesture = await tester.startGesture(tester.getCenter(card));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(const Offset(200, 450));
    await tester.pump();
    await gesture.moveTo(const Offset(210, 460));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(droppedId, tasks.last.id);
    expect(DateUtils.isSameDay(droppedStart, day), isTrue);
    expect(tester.takeException(), isNull);
  });

  group('Timeline', () {
    group('TaskEvent', () {
      test('creates with all required fields', () {
        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Test Event',
          startMinutes: 540, // 9:00 AM
          durationMinutes: 60,
        );

        expect(event.task, task);
        expect(event.title, 'Test Event');
        expect(event.startMinutes, 540);
        expect(event.durationMinutes, 60);
        expect(event.accentColor, const Color(0xFF2A2A2A));
      });

      test('computes endMinutes correctly', () {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Test',
          startMinutes: 540,
          durationMinutes: 60,
        );

        expect(event.endMinutes, 600);
      });

      test('computes startTime and endTime correctly', () {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Test',
          startMinutes: 540, // 9:00 AM
          durationMinutes: 90, // 1.5 hours
        );

        expect(event.startTime.hour, 9);
        expect(event.startTime.minute, 0);
        expect(event.endTime.hour, 10);
        expect(event.endTime.minute, 30);
      });

      test('copyWith updates startMinutes', () {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Test',
          startMinutes: 540,
          durationMinutes: 60,
        );

        final updated = event.copyWith(startMinutes: 600);

        expect(updated.startMinutes, 600);
        expect(updated.durationMinutes, 60);
      });

      test('copyWith updates durationMinutes', () {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Test',
          startMinutes: 540,
          durationMinutes: 60,
        );

        final updated = event.copyWith(durationMinutes: 90);

        expect(updated.startMinutes, 540);
        expect(updated.durationMinutes, 90);
      });

      test('copyWith preserves other fields', () {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Test',
          startMinutes: 540,
          durationMinutes: 60,
          accentColor: Colors.red,
        );

        final updated = event.copyWith(startMinutes: 600);

        expect(updated.accentColor, Colors.red);
      });
    });

    group('TimelineBody', () {
      testWidgets('renders hour labels correctly', (tester) async {
        final events = <TaskEvent>[];

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: events,
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // Should render 25 hour labels (0-24)
        expect(find.text('00:00'), findsOneWidget);
        expect(find.text('12:00'), findsOneWidget);
        expect(find.text('24:00'), findsOneWidget);
      });

      testWidgets('renders events at correct positions', (tester) async {
        final now = DateTime.now();
        final task = createMockTask(startsAt: now);
        final event = TaskEvent(
          task: task,
          title: 'Test Event',
          startMinutes: 540, // 9:00 AM
          durationMinutes: 60,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // Should find the event title
        expect(find.text('Test Event'), findsOneWidget);
      });

      testWidgets('renders multiple events', (tester) async {
        final task1 = createMockTask(id: '1');
        final task2 = createMockTask(id: '2');
        final events = [
          TaskEvent(
            task: task1,
            title: 'Event 1',
            startMinutes: 540, // 9:00 AM
            durationMinutes: 60,
          ),
          TaskEvent(
            task: task2,
            title: 'Event 2',
            startMinutes: 660, // 11:00 AM
            durationMinutes: 30,
          ),
        ];

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: events,
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        expect(find.text('Event 1'), findsOneWidget);
        expect(find.text('Event 2'), findsOneWidget);
      });

      testWidgets('shows event styling', (tester) async {
        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Active Event',
          startMinutes: 540,
          durationMinutes: 60,
        );

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        expect(find.text('Active Event'), findsOneWidget);
      });

      testWidgets('renders now line indicator', (tester) async {
        final events = <TaskEvent>[];

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: events,
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // Should find the orange now indicator (circle)
        expect(find.byType(DecoratedBox), findsWidgets);
      });
    });

    group('Event Interaction', () {
      testWidgets('event tile displays time range', (tester) async {
        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Timed Event',
          startMinutes: 540, // 9:00 AM
          durationMinutes: 90, // 1.5 hours
        );

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // Event should show start and end time - look for the time range text specifically
        expect(find.textContaining('9:00 AM - 10:30 AM'), findsOneWidget);
      });

      testWidgets('shows drag indicator for taller events', (tester) async {
        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Long Event',
          startMinutes: 540,
          durationMinutes: 120, // 2 hours - tall enough for drag indicator
        );

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // Should find drag indicator icon
        expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
      });

      testWidgets('hides drag indicator for short events', (tester) async {
        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Short Event',
          startMinutes: 540,
          durationMinutes: 5, // Very short - will be snapped to min 15
        );

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // The minimum duration is 15 minutes which renders at 35px + padding
        // Check if drag indicator is hidden (condition is height > 36)
        // Since 15 min = 35px < 36, it should be hidden
        expect(find.byIcon(Icons.drag_indicator), findsNothing);
      });

      testWidgets('drag ending over unscheduled panel unschedules the task', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Timed Event',
          startMinutes: 540, // 9:00 AM
          durationMinutes: 60,
        );

        Task? unscheduled;
        var eventChangedCalls = 0;
        var hoverCalls = 0;
        bool? lastHover;

        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 60,
              onEventChanged: (t, {startMinutes, durationMinutes, newDate}) {
                eventChangedCalls++;
              },
              onToggleTask: (_) {},
              isOverUnscheduled: (_) => true,
              onEventToUnscheduled: (t) => unscheduled = t,
              onHoverUnscheduled: (hovering) {
                hoverCalls++;
                lastHover = hovering;
              },
            ),
          ),
        );
        await tester.pump();

        // Event tile top: (540 - 0) / 60 * 140 + 2 = 1262 in content coords,
        // plus topPadding 60 → global ~1322.
        final gesture = await tester.startGesture(const Offset(300, 1340));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));

        expect(unscheduled, same(task));
        expect(eventChangedCalls, 0);
        expect(hoverCalls, greaterThan(0));
        expect(lastHover, isFalse);
      });

      testWidgets('drag ending outside unscheduled panel moves the event', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Timed Event',
          startMinutes: 540,
          durationMinutes: 60,
        );

        int? movedStartMinutes;
        Task? unscheduled;
        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 60,
              onEventChanged: (t, {startMinutes, durationMinutes, newDate}) {
                movedStartMinutes = startMinutes;
              },
              onToggleTask: (_) {},
              isOverUnscheduled: (_) => false,
              onEventToUnscheduled: (t) => unscheduled = t,
            ),
          ),
        );
        await tester.pump();

        final gesture = await tester.startGesture(const Offset(300, 1340));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));

        expect(unscheduled, isNull);
        expect(movedStartMinutes, isNotNull);
      });
    });

    group('Layout', () {
      testWidgets('handles empty events list', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: const [],
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // Should still render hour grid
        expect(find.text('00:00'), findsOneWidget);
        expect(find.text('24:00'), findsOneWidget);
      });
      testWidgets('renders grid lines for each hour', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: const [],
              topPadding: 0,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          ),
        );

        // Should find 25 hour separators (0-24)
        final gridLines = find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == const Color(0xFF2A2A2A),
        );
        expect(gridLines, findsAtLeastNWidgets(20));
      });
    });

    group('Week mode', () {
      final monday = DateTime(2026, 8, 10);

      Widget weekBody({
        required List<TaskEvent> events,
        DateTime? anchorDate,
        ValueChanged<DateTime>? onWeekChange,
        void Function(
          Task, {
          int? startMinutes,
          int? durationMinutes,
          DateTime? newDate,
        })?
        onEventChanged,
      }) {
        return createTestWidget(
          child: TimelineBody(
            events: events,
            topPadding: 0,
            weekStart: monday,
            anchorDate: anchorDate ?? monday,
            onWeekChange: onWeekChange,
            onEventChanged: onEventChanged ?? _noopEventChanged,
            onToggleTask: (_) {},
          ),
        );
      }

      double verticalOffsetOf(WidgetTester tester) {
        return tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (w) => w.scrollDirection == Axis.vertical && w.controller != null,
            )
            .controller!
            .offset;
      }

      testWidgets('renders current week headers inside the three-week buffer', (
        tester,
      ) async {
        await tester.pumpWidget(weekBody(events: const []));

        for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
          expect(find.text(day), findsNWidgets(3));
        }
        for (final day in [10, 11, 12, 13, 14, 15, 16]) {
          expect(find.text('$day'), findsWidgets);
        }
      });

      testWidgets('renders week range in navigation header', (tester) async {
        await tester.pumpWidget(
          weekBody(events: const [], onWeekChange: (_) {}),
        );

        expect(find.text('10.08 – 16.08'), findsOneWidget);
      });

      testWidgets('places event in its day column', (tester) async {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Weekly Event',
          startMinutes: 540,
          durationMinutes: 60,
          date: DateTime(2026, 8, 12, 9), // Wednesday
        );

        await tester.pumpWidget(weekBody(events: [event]));

        final box = tester.getTopLeft(find.text('Weekly Event'));
        final column = find.byKey(
          ValueKey(('timeline.day', DateTime(2026, 8, 12))),
        );
        final columnStart = tester.getTopLeft(column).dx;
        final columnEnd = tester.getTopRight(column).dx;
        expect(box.dx, greaterThan(columnStart));
        expect(box.dx, lessThan(columnEnd));
      });

      testWidgets('does not render events outside the buffered weeks', (
        tester,
      ) async {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Outside Week',
          startMinutes: 540,
          durationMinutes: 60,
          date: DateTime(2026, 8, 31), // outside all three buffered weeks
        );

        await tester.pumpWidget(weekBody(events: [event]));

        expect(find.text('Outside Week'), findsNothing);
      });

      testWidgets('horizontal drag moves event to another day', (tester) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        DateTime? receivedNewDate;
        int? newStart;
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Draggable Event',
          startMinutes: 540,
          durationMinutes: 60,
          date: DateTime(2026, 8, 12, 9), // Wednesday
        );

        await tester.pumpWidget(
          weekBody(
            events: [event],
            onEventChanged: (task, {startMinutes, durationMinutes, newDate}) {
              newStart = startMinutes;
              receivedNewDate = newDate;
            },
          ),
        );

        const columnWidth = 320.0;
        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Draggable Event')),
        );
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(Offset(columnWidth, 0));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(newStart, 540);
        expect(receivedNewDate, DateTime(2026, 8, 13)); // Thursday
      });

      testWidgets('quick drag over a task scrolls instead of moving it', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(800, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final event = TaskEvent(
          task: createMockTask(),
          title: 'Scroll Me',
          startMinutes: 540,
          durationMinutes: 60,
          date: DateTime(2026, 8, 12, 9), // Wednesday
        );

        int? newStart;
        DateTime? receivedNewDate;
        await tester.pumpWidget(
          createTestWidget(
            child: TimelineBody(
              events: [event],
              topPadding: 0,
              weekStart: null,
              anchorDate: DateTime(2026, 8, 12),
              onWeekChange: (_) {},
              onEventChanged: (task, {startMinutes, durationMinutes, newDate}) {
                newStart = startMinutes;
                receivedNewDate = newDate;
              },
              onToggleTask: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Scroll Me'));
        await tester.pumpAndSettle();

        final startOffset = verticalOffsetOf(tester);
        await tester.dragFrom(
          tester.getCenter(find.text('Scroll Me')),
          const Offset(0, -200),
        );
        await tester.pumpAndSettle();

        expect(newStart, isNull);
        expect(receivedNewDate, isNull);
        expect(verticalOffsetOf(tester), isNot(startOffset));
      });

      testWidgets('left arrow navigates to previous week', (tester) async {
        DateTime? received;
        await tester.pumpWidget(
          weekBody(events: const [], onWeekChange: (d) => received = d),
        );

        await tester.tap(find.byIcon(Icons.chevron_left));
        expect(received, DateTime(2026, 8, 3));
      });

      testWidgets('right arrow navigates to next week', (tester) async {
        DateTime? received;
        await tester.pumpWidget(
          weekBody(events: const [], onWeekChange: (d) => received = d),
        );

        await tester.tap(find.byIcon(Icons.chevron_right));
        expect(received, DateTime(2026, 8, 17));
      });

      testWidgets('horizontal scroll jumps to new week start when '
          'navigating via header', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        var weekStart = monday;

        Widget build() {
          return createTestWidget(
            child: TimelineBody(
              events: const [],
              topPadding: 0,
              weekStart: weekStart,
              anchorDate: weekStart,
              onWeekChange: (d) => weekStart = d,
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          );
        }

        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.chevron_right));
        expect(weekStart, DateTime(2026, 8, 17));

        // Apply the week change, as the parent does in the real app.
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        // viewport = 800 - 52 = 748, so columnWidth is clamped to 150 and
        // the new week must start exactly at the buffer center offset.
        const columnWidth = 150.0;
        final horizontalScroller = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (w) =>
                  w.scrollDirection == Axis.horizontal && w.controller != null,
            );
        expect(
          horizontalScroller.controller!.offset,
          closeTo(7 * columnWidth, 1),
        );
      });

      testWidgets('week grid scrolls horizontally', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(weekBody(events: const []));

        final wednesday = find.byKey(
          ValueKey(('timeline.day', DateTime(2026, 8, 12))),
        );
        final before = tester.getTopLeft(wednesday).dx;
        final initialOffset = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (w) =>
                  w.scrollDirection == Axis.horizontal && w.controller != null,
            )
            .controller!
            .offset;

        await tester.dragFrom(const Offset(400, 400), const Offset(-400, 0));
        await tester.pumpAndSettle();

        final horizontalScroller = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere((w) => w.scrollDirection == Axis.horizontal);
        final offset = horizontalScroller.controller!.offset;
        expect(offset, greaterThan(initialOffset));

        // Day headers follow the scroll so they stay aligned with the columns.
        final after = tester.getTopLeft(wednesday).dx;
        expect(before - after, closeTo(offset - initialOffset, 1));
      });

      testWidgets('week stays day-aligned when side panel width toggles '
          'during a week-edge switch', (tester) async {
        tester.view.physicalSize = const Size(830, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        // viewport = 830 - 52 = 778 < 1050, so columnWidth is clamped to 150
        // and maxScrollExtent (3150 - 778 = 2372) is NOT a multiple of it.
        const columnWidth = 150.0;

        var weekStart = monday;
        var weekChanged = false;

        Widget build() {
          return createTestWidget(
            child: TimelineBody(
              events: const [],
              topPadding: 0,
              weekStart: weekStart,
              anchorDate: weekStart,
              onWeekChange: (d) {
                weekStart = d;
                weekChanged = true;
              },
              onEventChanged: _noopEventChanged,
              onToggleTask: (_) {},
            ),
          );
        }

        double horizontalOffset() {
          final horizontalScroller = tester
              .widgetList<SingleChildScrollView>(
                find.byType(SingleChildScrollView),
              )
              .firstWhere(
                (w) =>
                    w.scrollDirection == Axis.horizontal &&
                    w.controller != null,
              );
          return horizontalScroller.controller!.offset;
        }

        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        // Scroll to the right edge of the 21-day buffer with a slow drag:
        // releasing at maxScrollExtent with ~zero velocity pins the offset
        // there, and maxScrollExtent is not day-aligned while the column
        // width is clamped.
        final gesture = await tester.startGesture(const Offset(400, 900));
        for (var i = 0; i < 24; i++) {
          await gesture.moveBy(const Offset(-150, 0));
          await tester.pump(const Duration(milliseconds: 16));
        }
        await tester.pump(const Duration(milliseconds: 120));
        await gesture.up();
        await tester.pumpAndSettle();

        // The scroll must rest exactly on a day boundary. On the old code
        // the ballistic snap pinned the offset to maxScrollExtent (2372),
        // which is 0.81 days off the grid — the skewed/clipped week.
        expect(horizontalOffset() % columnWidth, closeTo(0, 0.5));

        // The edge scroll pushed the viewport into the next week.
        expect(weekChanged, isTrue);

        // Apply the week change. The fractional offset captured at the edge
        // must not survive: it would skew the grid by most of a day.
        await tester.pumpWidget(build());
        await tester.pumpAndSettle();

        expect(horizontalOffset() % columnWidth, closeTo(0, 0.5));

        // A side-panel style width toggle afterwards must keep the grid
        // day-aligned too.
        tester.view.physicalSize = const Size(1250, 4200);
        await tester.pumpAndSettle();
        tester.view.physicalSize = const Size(830, 4200);
        await tester.pumpAndSettle();
        expect(horizontalOffset() % columnWidth, closeTo(0, 0.5));
      });

      testWidgets('pinch to zoom increases hour slot height', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(weekBody(events: const []));

        final before =
            (tester.getTopLeft(find.text('10:00')).dy -
            tester.getTopLeft(find.text('09:00')).dy);

        final g1 = await tester.createGesture();
        final g2 = await tester.createGesture();
        await g1.down(const Offset(400, 500));
        await g2.down(const Offset(400, 700));
        await tester.pump();

        // Spread the fingers: distance 200 -> 400, scale factor 2.0.
        await g1.moveTo(const Offset(400, 400));
        await g2.moveTo(const Offset(400, 800));
        await tester.pump();

        await g1.up();
        await g2.up();
        await tester.pumpAndSettle();

        final after =
            (tester.getTopLeft(find.text('10:00')).dy -
            tester.getTopLeft(find.text('09:00')).dy);
        // Check hour spacing independently of the preserved zoom focal point.
        // 140 * 2.0 is clamped to 240, so adjacent hours spread by 100.
        expect(after - before, closeTo(100, 1));
      });

      testWidgets('zoom in increases hour slot height', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          weekBody(events: const [], onWeekChange: (_) {}),
        );
        final before =
            (tester.getTopLeft(find.text('10:00')).dy -
            tester.getTopLeft(find.text('09:00')).dy);

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        final after =
            (tester.getTopLeft(find.text('10:00')).dy -
            tester.getTopLeft(find.text('09:00')).dy);

        // Adjacent hour spacing grows from 140 to 168.
        expect(after - before, closeTo(140 * 0.2, 1));
      });

      testWidgets('zoom out decreases hour slot height', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          weekBody(events: const [], onWeekChange: (_) {}),
        );
        final before =
            (tester.getTopLeft(find.text('10:00')).dy -
            tester.getTopLeft(find.text('09:00')).dy);

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pumpAndSettle();
        final after =
            (tester.getTopLeft(find.text('10:00')).dy -
            tester.getTopLeft(find.text('09:00')).dy);

        // Adjacent hour spacing shrinks from 140 to about 116.67.
        expect(before - after, closeTo(140 * (1 - 1 / 1.2), 1));
      });
    });

    group('Task creation via long-press selection', () {
      final monday = DateTime(2026, 8, 10);

      Widget buildBody({
        List<TaskEvent> events = const [],
        DateTime? weekStart,
        DateTime? anchorDate,
        Future<void> Function(Task task)? onSubmitNewTask,
      }) {
        return createTestWidget(
          child: TimelineBody(
            events: events,
            topPadding: 0,
            weekStart: weekStart,
            anchorDate: anchorDate ?? weekStart ?? monday,
            onWeekChange: (_) {},
            onEventChanged: _noopEventChanged,
            onToggleTask: (_) {},
            onSubmitNewTask: onSubmitNewTask,
          ),
        );
      }

      double horizontalOffset(WidgetTester tester) {
        return tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (w) =>
                  w.scrollDirection == Axis.horizontal && w.controller != null,
            )
            .controller!
            .offset;
      }

      double verticalOffset(WidgetTester tester) {
        return tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (w) => w.scrollDirection == Axis.vertical && w.controller != null,
            )
            .controller!
            .offset;
      }

      testWidgets('long-press on empty week area opens mini form and '
          'creates a task on submit', (tester) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        Task? submitted;
        await tester.pumpWidget(
          buildBody(
            weekStart: monday,
            onSubmitNewTask: (task) async => submitted = task,
          ),
        );
        await tester.pump();

        // Monday of the current week (buffer index 7).
        const columnWidth = (1600 - 52) / 7.0;
        final h = horizontalOffset(tester);
        final v = verticalOffset(tester);
        final screenX = 52 + (7 * columnWidth + columnWidth / 2) - h;
        final screenY = 200 + (9 * 140 + 70) - v;

        final gesture = await tester.startGesture(Offset(screenX, screenY));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, 140));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MiniTaskForm), findsOneWidget);

        await tester.enterText(
          find.byKey(const ValueKey('mini_task_title')),
          'Gym',
        );
        await tester.tap(find.text('Create'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MiniTaskForm), findsNothing);
        expect(submitted, isNotNull);
        expect(submitted!.title, 'Gym');
        final startsAt = submitted!.startsAt!;
        expect(DateTime(startsAt.year, startsAt.month, startsAt.day), monday);
        expect(
          submitted!.endsAt!.difference(startsAt),
          const Duration(hours: 1),
        );
      });

      testWidgets('long-press on an existing event does not open mini form', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final event = TaskEvent(
          task: createMockTask(),
          title: 'Busy',
          startMinutes: 540,
          durationMinutes: 60,
          date: DateTime(2026, 8, 10, 9), // Monday 9:00
        );

        await tester.pumpWidget(buildBody(weekStart: monday, events: [event]));
        await tester.pump();

        const columnWidth = (1600 - 52) / 7.0;
        final h = horizontalOffset(tester);
        final v = verticalOffset(tester);
        final screenX = 52 + (7 * columnWidth + columnWidth / 2) - h;
        final screenY = 200 + ((540 + 30) / 60 * 140) - v;

        final gesture = await tester.startGesture(Offset(screenX, screenY));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MiniTaskForm), findsNothing);
      });

      testWidgets('long-press in day view creates task on the anchor date', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final anchor = DateTime(2026, 8, 12);
        Task? submitted;
        await tester.pumpWidget(
          buildBody(
            anchorDate: anchor,
            onSubmitNewTask: (task) async => submitted = task,
          ),
        );
        await tester.pump();

        final gesture = await tester.startGesture(const Offset(500, 900));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveBy(const Offset(0, 140));
        await tester.pump(const Duration(milliseconds: 50));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MiniTaskForm), findsOneWidget);

        await tester.tap(find.text('Create'));
        await tester.pump(const Duration(milliseconds: 100));

        expect(submitted, isNotNull);
        final startsAt = submitted!.startsAt!;
        expect(DateTime(startsAt.year, startsAt.month, startsAt.day), anchor);
        expect(
          submitted!.endsAt!.difference(startsAt),
          const Duration(hours: 1),
        );
      });

      testWidgets(
        'mini form stays on the right even when a task is to the right of '
        'the ghost',
        (tester) async {
          tester.view.physicalSize = const Size(1600, 4200);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final event = TaskEvent(
            task: createMockTask(),
            title: 'Busy',
            startMinutes: 540,
            durationMinutes: 60,
            date: DateTime(2026, 8, 11, 9), // Tuesday 9:00, right of Monday
          );

          await tester.pumpWidget(
            buildBody(weekStart: monday, events: [event]),
          );
          await tester.pump();

          const columnWidth = (1600 - 52) / 7.0;
          final h = horizontalOffset(tester);
          final v = verticalOffset(tester);
          final screenX = 52 + (7 * columnWidth + columnWidth / 2) - h;
          final screenY = 200 + (10 * 140 + 70) - v;

          final gesture = await tester.startGesture(Offset(screenX, screenY));
          await tester.pump(const Duration(milliseconds: 600));
          await gesture.up();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.byType(MiniTaskForm), findsOneWidget);

          final ghostTextRect = tester.getRect(
            find.text('10:30 AM \u2013 11:30 AM'),
          );
          final formRect = tester.getRect(find.byType(MiniTaskForm));
          expect(formRect.top, greaterThanOrEqualTo(ghostTextRect.top - 15));
          expect(formRect.left, greaterThanOrEqualTo(ghostTextRect.right - 1));
        },
      );

      testWidgets('mini form moves together with the ghost on scroll', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildBody(weekStart: monday));
        await tester.pump();

        const columnWidth = (1600 - 52) / 7.0;
        final h = horizontalOffset(tester);
        final v = verticalOffset(tester);
        final screenX = 52 + (7 * columnWidth + columnWidth / 2) - h;
        final screenY = 200 + (9 * 140 + 70) - v;

        final gesture = await tester.startGesture(Offset(screenX, screenY));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MiniTaskForm), findsOneWidget);

        final before = tester.getRect(find.byType(MiniTaskForm));

        final horizontal = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (w) =>
                  w.scrollDirection == Axis.horizontal && w.controller != null,
            )
            .controller!;
        final vertical = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere(
              (w) => w.scrollDirection == Axis.vertical && w.controller != null,
            )
            .controller!;
        horizontal.jumpTo(horizontal.offset + columnWidth);
        vertical.jumpTo(vertical.offset + 140);
        await tester.pump();

        final after = tester.getRect(find.byType(MiniTaskForm));
        expect(after.left, closeTo(before.left - columnWidth, 1));
        expect(after.top, closeTo(before.top - 140, 1));
      });

      testWidgets('cancel button closes mini form and clears ghost', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(1600, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildBody(weekStart: monday));
        await tester.pump();

        const columnWidth = (1600 - 52) / 7.0;
        final h = horizontalOffset(tester);
        final v = verticalOffset(tester);
        final screenX = 52 + (7 * columnWidth + columnWidth / 2) - h;
        final screenY = 200 + (9 * 140 + 70) - v;

        final gesture = await tester.startGesture(Offset(screenX, screenY));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MiniTaskForm), findsOneWidget);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(MiniTaskForm), findsNothing);
      });
    });
  });
}
