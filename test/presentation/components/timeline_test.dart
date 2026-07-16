import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/components/timeline.dart';

import '../../test_helpers.dart';

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
        expect(event.isActive, false);
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
          isActive: true,
          accentColor: Colors.red,
        );

        final updated = event.copyWith(startMinutes: 600);

        expect(updated.isActive, true);
        expect(updated.accentColor, Colors.red);
      });
    });

    group('TimelineBody', () {
      testWidgets('renders hour labels correctly', (tester) async {
        final events = <TaskEvent>[];

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: events,
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

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

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: [event],
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

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

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: events,
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

        expect(find.text('Event 1'), findsOneWidget);
        expect(find.text('Event 2'), findsOneWidget);
      });

      testWidgets('shows active event styling', (tester) async {
        final task = createMockTask();
        final event = TaskEvent(
          task: task,
          title: 'Active Event',
          startMinutes: 540,
          durationMinutes: 60,
          isActive: true,
        );

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: [event],
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

        expect(find.text('Active Event'), findsOneWidget);
      });

      testWidgets('renders now line indicator', (tester) async {
        final events = <TaskEvent>[];

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: events,
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

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

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: [event],
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

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

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: [event],
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

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

        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: [event],
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

        // The minimum duration is 15 minutes which renders at 35px + padding
        // Check if drag indicator is hidden (condition is height > 36)
        // Since 15 min = 35px < 36, it should be hidden
        expect(find.byIcon(Icons.drag_indicator), findsNothing);
      });
    });

    group('Layout', () {
      testWidgets('handles empty events list', (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: const [],
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

        // Should still render hour grid
        expect(find.text('00:00'), findsOneWidget);
        expect(find.text('24:00'), findsOneWidget);
      });

      testWidgets('renders grid lines for each hour', (tester) async {
        await tester.pumpWidget(createTestWidget(
          child: TimelineBody(
            events: const [],
            topPadding: 0,
            onEventChanged: (task, {startMinutes, durationMinutes}) {},
          ),
        ));

        // Should find 25 hour separators (0-24)
        final gridLines = find.byWidgetPredicate(
          (widget) => widget is ColoredBox && widget.color == const Color(0xFF2A2A2A),
        );
        expect(gridLines, findsAtLeastNWidgets(20));
      });
    });
  });
}