import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/ui/task_work_logs.dart';
import '../../features/tasks/support/memory_tasks.dart';
import '../../test_helpers.dart';

void main() {
  test('time totals split overnight entries across calendar days', () {
    final log = WorkLog(
      id: 'night',
      taskId: 't',
      status: 1,
      date: DateTime(2026, 11, 7),
      description: '',
      startedAt: DateTime(2026, 11, 7, 23, 30),
      endedAt: DateTime(2026, 11, 8, 0, 30),
    );
    expect(log.duration, const Duration(hours: 1));
    expect(
      workLogTimeOnDay(log, DateTime(2026, 11, 7)),
      const Duration(minutes: 30),
    );
    expect(
      workLogTimeOnDay(log, DateTime(2026, 11, 8)),
      const Duration(minutes: 30),
    );
    expect(
      log
          .copyWith(
            startedAt: const Wrapped(null),
            endedAt: const Wrapped(null),
          )
          .duration,
      isNull,
    );
  });
  testWidgets(
    'card work logs update live, expand without opening task and dispose their stream',
    (tester) async {
      final store = MemoryWorkLogs();
      final task = Task.blank().copyWith(title: 'Задача с ворклогами');
      final now = DateTime.now();
      final day = DateTime(now.year, now.month, now.day);
      var opened = 0;
      var selected = 0;
      await tester.pumpWidget(
        createTestWidget(
          child: Center(
            child: SizedBox(
              width: 340,
              child: TaskCard(
                task: task,
                workLogs: store,
                onTap: () => opened++,
                onSelected: () => selected++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('task.worklogs')), findsNothing);
      await store.addWorkLog(
        WorkLog(
          id: 'a',
          taskId: task.id,
          status: 1,
          date: day,
          description: 'Конспект',
          startedAt: day.copyWith(hour: 14, minute: 10),
          endedAt: day.copyWith(hour: 15, minute: 30),
        ),
      );
      await store.addWorkLog(
        WorkLog(
          id: 'b',
          taskId: task.id,
          status: 1,
          date: day.subtract(const Duration(days: 1)),
          description: 'Разбор тем',
          startedAt: day
              .subtract(const Duration(days: 1))
              .copyWith(hour: 19, minute: 40),
          endedAt: day
              .subtract(const Duration(days: 1))
              .copyWith(hour: 20, minute: 55),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('2 ч 35 мин'), findsOneWidget);
      expect(find.text('Сегодня: 1 ч 20 мин'), findsOneWidget);
      expect(find.text('Конспект'), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('task.worklogs'))).width,
        greaterThan(300),
      );
      await tester.tap(find.byKey(const ValueKey('task.worklogs.toggle')));
      await tester.pump();
      expect(opened, 0);
      expect(selected, 0);
      expect(find.text('Конспект'), findsOneWidget);
      expect(
        tester
            .getRect(find.byKey(const ValueKey(('worklog.title', 'a'))))
            .center
            .dy,
        tester
            .getRect(find.byKey(const ValueKey(('worklog.date', 'a'))))
            .center
            .dy,
      );
      expect(find.text('Вчера'), findsOneWidget);
      expect(find.text('14:10 – 15:30'), findsOneWidget);
      await tester.pumpWidget(
        createTestWidget(
          child: Center(
            child: SizedBox(
              width: 700,
              child: TaskCard(
                task: task,
                workLogs: store,
                onTap: () => opened++,
                onSelected: () => selected++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('task.worklogs'))).width,
        greaterThan(660),
      );
      expect(
        tester
            .getRect(find.byKey(const ValueKey(('worklog.title', 'a'))))
            .center
            .dy,
        tester
            .getRect(find.byKey(const ValueKey(('worklog.date', 'a'))))
            .center
            .dy,
      );
      await tester.tap(find.byKey(const ValueKey('task.worklogs.toggle')));
      await tester.pump();
      expect(find.text('Конспект'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(store.listeners, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
