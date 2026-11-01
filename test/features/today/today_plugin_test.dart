import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:tasks_plugin/tasks_panels.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'support/today_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'panels have their own date, filters and models without primary feature plugins',
    () async {
      final h = TodayHarness()..seed();
      addTearDown(h.dispose);
      final mainTasks = TasksViewModel(
        h.tasks,
        GetTasksWithProjectsUseCase(h.tasks, h.projects),
        h.projects,
      )..initialize();
      final mainHabits = HabitsViewModel(h.habits)..initialize();
      addTearDown(mainTasks.dispose);
      addTearDown(mainHabits.dispose);
      final original = DateTime(2025, 5, 1);
      mainTasks.updateFilter(
        (old) => old.copyWith(anchorDate: original, period: DatePeriod.month),
      );
      mainHabits.selectDate(original);
      await h.host.start();
      final initial =
          await h.tasksPanel.viewModel.state.firstWhere(
                (state) => state is TasksLoaded,
              )
              as TasksLoaded;
      expect(initial.tasks.single.task.title, 'Задача на сегодня');
      h.module.selectDate(DateTime(2026, 11, 3, 23));
      final next =
          await h.tasksPanel.viewModel.state.firstWhere(
                (state) =>
                    state is TasksLoaded &&
                    state.tasks.any(
                      (item) => item.task.title == 'Задача на завтра',
                    ),
              )
              as TasksLoaded;
      expect(next.tasks, hasLength(1));
      expect(h.habitsPanel.viewModel.selectedDate, DateTime(2026, 11, 3));
      expect(h.projectsPanel.viewModel.date, DateTime(2026, 11, 3));
      expect(mainTasks.currentFilterValue.anchorDate, original);
      expect(mainTasks.currentFilterValue.period, DatePeriod.month);
      expect(mainHabits.selectedDate, original);
      h.tasksPanel.viewModel.updateFilter(
        (old) => old.copyWith(showCompleted: () => true),
      );
      expect(mainTasks.currentFilterValue.showCompleted, isNull);
    },
  );

  test('a task action updates the project panel through shared APIs', () async {
    final h = TodayHarness()..seed();
    addTearDown(h.dispose);
    await h.host.start();
    await h.projectsPanel.viewModel.state.firstWhere(
      (state) => !state.isLoading,
    );
    final task = h.tasks.items.values.first;
    await h.tasksPanel.viewModel.toggleTask(task);
    final progress = await h.projectsPanel.viewModel.state.firstWhere(
      (state) =>
          state.projects.isNotEmpty &&
          state.projects.single.completedTasks == 1,
    );
    expect(progress.projects.single.totalTasks, 2);
    expect(progress.projects.single.progress, .5);
    expect(h.tasks.items[task.id]!.isCompleted, isTrue);
  });

  test('two instances of the task panel keep independent filters', () async {
    final h = TodayHarness()..seed();
    final date = ValueNotifier(DateTime(2026, 11, 3));
    final extra = TasksPanelModule(
      id: 'another.tasks',
      slot: 'another',
      ui: h.ui,
      tasks: h.tasks,
      projects: h.projects,
      date: () => date,
    );
    final host = PluginHost([...h.module.plugins, extra]);
    await host.start();
    expect(extra.viewModel.currentFilterValue.anchorDate, date.value);
    h.module.selectDate(DateTime(2026, 11, 4));
    h.tasksPanel.viewModel.updateFilter(
      (old) => old.copyWith(showCompleted: () => true),
    );
    expect(
      extra.viewModel.currentFilterValue.anchorDate,
      DateTime(2026, 11, 3),
    );
    expect(extra.viewModel.currentFilterValue.showCompleted, isFalse);
    await host.stop();
    date.dispose();
    h.ui.dispose();
    expect(h.tasks.listeners, isEmpty);
    expect(h.projects.listeners, isEmpty);
  });

  test(
    'completion preserves newer fields and does not recreate a deleted task',
    () async {
      final h = TodayHarness()..seed();
      addTearDown(h.dispose);
      await h.host.start();
      final displayed = h.tasks.items.values.first;
      await h.tasks.updateTask(
        displayed.copyWith(title: 'Название изменено на другом экране'),
      );
      await h.tasksPanel.viewModel.toggleTask(displayed);
      expect(
        h.tasks.items[displayed.id]!.title,
        'Название изменено на другом экране',
      );
      expect(h.tasks.items[displayed.id]!.isCompleted, isTrue);
      await h.tasks.deleteTask(displayed.id);
      await h.tasksPanel.viewModel.toggleTask(displayed);
      expect(h.tasks.items.containsKey(displayed.id), isFalse);
    },
  );

  test(
    'stop drains task and habit writes before disposing the date owner',
    () async {
      final h = TodayHarness()..seed();
      addTearDown(h.dispose);
      await h.host.start();
      await h.habitsPanel.viewModel.state.firstWhere(
        (state) => state is HabitsLoaded && state.habits.isNotEmpty,
      );
      final tasksModel = h.tasksPanel.viewModel;
      final habitsModel = h.habitsPanel.viewModel;
      h.tasks.writeGate = Completer<void>();
      h.tasks.entered = Completer<void>();
      h.habits.writeGate = Completer<void>();
      h.habits.entered = Completer<void>();
      final task = h.tasks.items.values.first;
      final habit = h.habits.habits.values.single;
      final taskWrite = tasksModel.toggleTask(task);
      final habitWrite = habitsModel.toggleHabit(habit, h.day);
      await Future.wait([h.tasks.entered!.future, h.habits.entered!.future]);
      var stopped = false;
      final closing = h.host.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      expect(h.ui.screens, isEmpty);
      expect(h.module.selectedDate, h.day);
      h.tasks.writeGate!.complete();
      h.habits.writeGate!.complete();
      await Future.wait([taskWrite, habitWrite]);
      await closing;
      expect(h.tasks.items[task.id]!.isCompleted, isTrue);
      expect(h.habits.entries.values.single.dateKey, '2026-11-02');
      expect(() => h.module.selectedDate, throwsStateError);
      expect(h.tasks.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.habits.habitListeners, isEmpty);
      expect(h.habits.entryListeners, isEmpty);
      await expectLater(tasksModel.deleteTask(task.id), throwsStateError);
      await expectLater(
        habitsModel.toggleHabit(habit, h.day),
        throwsStateError,
      );
    },
  );

  test(
    'a partial panel startup rolls back earlier panels and date state',
    () async {
      final h = TodayHarness()..seed();
      addTearDown(h.dispose);
      h.habits.failWatch = true;
      await expectLater(
        h.host.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.ui.screens, isEmpty);
      expect(h.ui.panelsFor('today.tasks'), isEmpty);
      expect(h.tasks.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(() => h.module.selectedDate, throwsStateError);
      h.habits.failWatch = false;
      await h.host.start();
      expect(h.ui.screens.single.id, 'today');
    },
  );

  test(
    'screen collisions preserve the existing owner and release every panel',
    () async {
      final h = TodayHarness()..seed();
      addTearDown(h.dispose);
      h.ui.register(
        'existing',
        screens: [
          PluginScreenContribution(
            id: 'today',
            label: 'Existing',
            icon: Icons.home,
            builder: (_, _) => const SizedBox(),
          ),
        ],
      );
      await expectLater(
        h.host.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.ui.screens.single.label, 'Existing');
      expect(h.tasks.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.habits.habitListeners, isEmpty);
      expect(() => h.module.selectedDate, throwsStateError);
    },
  );

  test(
    'restarting creates fresh panel state and source cancellation failures still release peers',
    () async {
      final h = TodayHarness()..seed();
      addTearDown(h.dispose);
      await h.host.start();
      final first = h.tasksPanel.viewModel;
      h.module.selectDate(DateTime(2026, 11, 3));
      await h.host.stop();
      await h.host.start();
      expect(h.module.selectedDate, h.day);
      expect(h.tasksPanel.viewModel, isNot(same(first)));
      h.habits.failCancel = true;
      await expectLater(
        h.host.stop(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.tasks.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.habits.habitListeners, isEmpty);
      expect(h.habits.entryListeners, isEmpty);
      expect(() => h.module.selectedDate, throwsStateError);
    },
  );
}
