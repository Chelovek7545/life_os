import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:today_plugin/today_plugin.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:habits_api/habits_api.dart';
import 'package:tasks_plugin/tasks_panels.dart';
import 'package:projects_plugin/projects_panels.dart';
import 'package:habits_plugin/habits_panels.dart';
import '../../tasks/support/memory_tasks.dart';
import '../../habits/support/memory_habits.dart';

class TodayHarness {
  final tasks = MemoryTasks();
  final projects = MemoryProjectQueries();
  final habits = MemoryHabits();
  final ui = PluginUiRegistry();
  final day = DateTime(2026, 11, 2);
  late TasksPanelModule tasksPanel;
  late HabitsPanelModule habitsPanel;
  late ProjectsPanelModule projectsPanel;
  late final module = TodayPlugin(
    ui: ui,
    now: () => day,
    panels: (date) {
      tasksPanel = TasksPanelModule(
        id: 'today.tasks',
        slot: TodayPanelSlots.tasks,
        ui: ui,
        tasks: tasks,
        projects: projects,
        date: date,
      );
      habitsPanel = HabitsPanelModule(
        id: 'today.habits',
        slot: TodayPanelSlots.habits,
        ui: ui,
        habits: habits,
        date: date,
      );
      projectsPanel = ProjectsPanelModule(
        id: 'today.projects',
        slot: TodayPanelSlots.projects,
        ui: ui,
        projects: projects,
        tasks: tasks,
        date: date,
      );
      return [tasksPanel, habitsPanel, projectsPanel];
    },
  );
  late final host = PluginHost(module.plugins);
  Future<void> dispose() async {
    try {
      await host.stop();
    } catch (_) {}
    ui.dispose();
  }

  void seed() {
    final project = Project.create(name: 'Запустить проект');
    projects.items[project.id] = project;
    for (final (title, date) in [
      ('Задача на сегодня', day),
      ('Задача на завтра', DateTime(2026, 11, 3)),
    ]) {
      final task = Task.blank().copyWith(
        title: title,
        startsAt: Wrapped(date.copyWith(hour: 10)),
        projectId: Wrapped(project.id),
      );
      tasks.items[task.id] = task;
    }
    final habit = Habit.create(
      title: 'Читать каждый день',
      type: const MorningHabit(),
    ).copyWith(createdAt: DateTime(2026, 1));
    habits.habits[habit.id] = habit;
  }
}

Future<void> pumpPluginLifecycle(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  var done = false;
  final operation = action().whenComplete(() => done = true);
  for (var i = 0; i < 80 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(
    done,
    isTrue,
    reason: 'Panel subscriptions and accepted work must finish closing.',
  );
  await operation;
}

Widget todayApp(PluginNavigationController navigation) => MaterialApp(
  theme: ThemeData.dark(useMaterial3: true),
  home: Scaffold(body: PluginScreenDeck(navigation: navigation)),
);
