import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:habits_api/habits_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/app.dart';
import '../support/test_app.dart';

Future<void> pumpStorage(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets(
    'Today shares stored data while keeping primary screen filters independent',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final day = app.todayPlugin.selectedDate;
      final original = DateTime(day.year - 1, 4, 2);
      app.tasksViewModel.updateFilter(
        (old) => old.copyWith(period: DatePeriod.month, anchorDate: original),
      );
      app.habitsViewModel.selectDate(original);
      final project = Project.create(name: 'Общий проект');
      final task = Task.blank().copyWith(
        title: 'Общая задача',
        projectId: Wrapped(project.id),
        startsAt: Wrapped(day.copyWith(hour: 9)),
      );
      final habit = Habit.create(
        title: 'Общая привычка',
        type: const MorningHabit(),
      );
      await tester.runAsync(() async {
        await app.projectsRepository.addProject(project);
        await app.tasksRepository.addTask(task);
        await app.habitsRepository.addHabit(habit);
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('today');
      await pumpStorage(tester);
      expect(find.text('Общая задача'), findsOneWidget);
      expect(find.text('Общая привычка'), findsOneWidget);
      expect(find.text('Общий проект'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('task-toggle-${task.id}')));
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(task.id),
        ))!.isCompleted,
        isTrue,
      );
      expect(find.text('Выполнено 1 из 1 задач'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('today-next-day')));
      await pumpStorage(tester);
      expect(app.tasksViewModel.currentFilterValue.anchorDate, original);
      expect(app.tasksViewModel.currentFilterValue.period, DatePeriod.month);
      expect(app.habitsViewModel.selectedDate, original);
      tester.view.physicalSize = const Size(390, 844);
      await pumpStorage(tester);
      expect(
        find.byKey(const ValueKey('navigation-bar:today')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );
}
