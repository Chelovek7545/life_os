import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  testWidgets(
    'week switches layout and moves timed, date-only and spanning tasks without losing their schedule',
    (tester) async {
      tester.view.physicalSize = const Size(2000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final mon = DateTime(2026, 11, 9);
      final tue = DateTime(2026, 11, 10);
      final wed = DateTime(2026, 11, 11);
      final thu = DateTime(2026, 11, 12);
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
        title: 'Range Monday Tuesday',
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
      await tester.tap(
        find.descendant(
          of: card(dated, mon),
          matching: find.byKey(const ValueKey('task.worklogs.toggle')),
        ),
      );
      await tester.pumpAndSettle();
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
      final horizontal = find.byKey(const ValueKey('tasks.week.horizontal'));
      await tester.drag(horizontal, const Offset(-2000, 0));
      await tester.pumpAndSettle();
      expect(day(DateTime(2026, 11, 15)).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tasks.week-layout')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tasks.week.vertical')), findsOneWidget);
      expect(app.tasksViewModel.currentFilterValue.anchorDate, mon);
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );
}
