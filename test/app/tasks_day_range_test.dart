import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  for (final size in [const Size(390, 844), const Size(1400, 1000)]) {
    testWidgets(
      'Tasks day shows stored ranges at boundaries and inside them at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final app = (await tester.runAsync(
          () => createTestApp(enableObsidian: false),
        ))!;
        final start = DateTime(2026, 11, 2);
        final end = DateTime(2026, 11, 7);
        final range = Task.blank().copyWith(
          title: 'Задача со 2 по 7 ноября',
          startsAt: Wrapped(start.startOfDay),
          endsAt: Wrapped(end.startOfDay),
        );
        final timedRange = Task.blank().copyWith(
          title: 'Диапазон со временем',
          startsAt: Wrapped(start.copyWith(hour: 16)),
          endsAt: Wrapped(end.copyWith(hour: 9)),
        );
        await tester.runAsync(() async {
          await app.tasksRepository.addTask(range);
          await app.tasksRepository.addTask(timedRange);
        });
        await tester.pumpWidget(MyApp(diContainer: app));
        app.navigation.open('tasks');
        for (final day in [
          start.subtract(const Duration(days: 1)),
          start,
          DateTime(2026, 11, 5),
          end,
          end.add(const Duration(days: 1)),
        ]) {
          app.tasksViewModel.updateFilter(
            (_) => TaskFilterConfig(anchorDate: day, period: DatePeriod.day),
          );
          await pumpStorage(tester);
          final cards = tester
              .widgetList<TaskCard>(
                find.descendant(
                  of: find.byType(TasksScreen),
                  matching: find.byType(TaskCard),
                ),
              )
              .map((card) => card.task.id)
              .toSet();
          final included = !day.isBefore(start) && !day.isAfter(end);
          expect(
            cards.contains(range.id),
            included,
            reason: '$day, date-only range',
          );
          expect(
            cards.contains(timedRange.id),
            included,
            reason: '$day, timed range',
          );
          if (included) {
            expect(
              find.descendant(
                of: find.byType(TasksScreen),
                matching: find.byIcon(Icons.date_range_outlined),
              ),
              findsNWidgets(2),
            );
          }
          expect(app.tasksViewModel.currentFilterValue.period, DatePeriod.day);
          expect(tester.takeException(), isNull);
        }
        await disposeTestApp(tester, app);
      },
    );
  }
}
