import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/components/timeline.dart';

import '../../test_helpers.dart';

void _noopEventChanged(
  Task task, {
  int? startMinutes,
  int? durationMinutes,
  DateTime? newDate,
}) {}

void main() {
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
      });      testWidgets('renders grid lines for each hour', (tester) async {
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
          Task,
          {int? startMinutes,
          int? durationMinutes,
          DateTime? newDate}
        )? onEventChanged,
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

      testWidgets('renders 7 day headers with dates', (tester) async {
        await tester.pumpWidget(weekBody(events: const []));

        for (final day in ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN']) {
          expect(find.text(day), findsOneWidget);
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
        const offset = 12.0;
        const columnWidth = 320.0;
        // Wednesday is the 3rd column (index 2)
        final columnStart = offset + 2 * columnWidth;
        final columnEnd = offset + 3 * columnWidth;
        expect(box.dx, greaterThan(columnStart));
        expect(box.dx, lessThan(columnEnd));
        // It must not start in the Tuesday column (index 1)
        expect(box.dx, greaterThan(offset + 1.5 * columnWidth));
      });

      testWidgets('does not render events outside the week', (tester) async {
        final event = TaskEvent(
          task: createMockTask(),
          title: 'Outside Week',
          startMinutes: 540,
          durationMinutes: 60,
          date: DateTime(2026, 8, 20), // next week
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
            onEventChanged: (task,
                {startMinutes, durationMinutes, newDate}) {
              newStart = startMinutes;
              receivedNewDate = newDate;
            },
          ),
        );

        const columnWidth = 320.0;
        await tester.drag(find.text('Draggable Event'), Offset(columnWidth, 0));
        await tester.pumpAndSettle();

        expect(newStart, 540);
        expect(receivedNewDate, DateTime(2026, 8, 13)); // Thursday
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

      testWidgets('week grid scrolls horizontally', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(weekBody(events: const []));

        final before = tester.getTopLeft(find.text('WED')).dx;

        await tester.dragFrom(const Offset(400, 400), const Offset(-400, 0));
        await tester.pumpAndSettle();

        final horizontalScroller = tester
            .widgetList<SingleChildScrollView>(
              find.byType(SingleChildScrollView),
            )
            .firstWhere((w) => w.scrollDirection == Axis.horizontal);
        final offset = horizontalScroller.controller!.offset;
        expect(offset, closeTo(400, 1));

        // Day headers follow the scroll so they stay aligned with the columns.
        final after = tester.getTopLeft(find.text('WED')).dx;
        expect(before - after, closeTo(offset, 1));
      });

      testWidgets(
          'week stays day-aligned when side panel width toggles '
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

        final before = tester.getTopLeft(find.text('09:00')).dy;

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

        final after = tester.getTopLeft(find.text('09:00')).dy;
        // 140 * 2.0 = 280, clamped to max 240; hour 9 moves down by 9 * 100.
        expect(after - before, closeTo(9 * 100, 1));
      });

      testWidgets('zoom in increases hour slot height', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          weekBody(events: const [], onWeekChange: (_) {}),
        );
        final before = tester.getTopLeft(find.text('09:00')).dy;

        await tester.tap(find.byIcon(Icons.add));
        await tester.pumpAndSettle();
        final after = tester.getTopLeft(find.text('09:00')).dy;

        // Hour height goes 140 -> 168, so hour 9 moves down by 9 * 28
        expect(after - before, closeTo(9 * 140 * 0.2, 1));
      });

      testWidgets('zoom out decreases hour slot height', (tester) async {
        tester.view.physicalSize = const Size(800, 4200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          weekBody(events: const [], onWeekChange: (_) {}),
        );
        final before = tester.getTopLeft(find.text('09:00')).dy;

        await tester.tap(find.byIcon(Icons.remove));
        await tester.pumpAndSettle();
        final after = tester.getTopLeft(find.text('09:00')).dy;

        // Hour height goes 140 -> ~116.67, so hour 9 moves up
        expect(before - after, closeTo(9 * 140 * (1 - 1 / 1.2), 1));
      });
    });
  });
}
