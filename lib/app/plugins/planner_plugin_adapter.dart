import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/features/planner/presentation/planner_screen.dart';

AppPlugin createPlannerPlugin({
  required PluginUiRegistry ui,
  required TasksApi tasks,
  required ProjectsQueries projects,
  required HabitsApi habits,
}) {
  final lifecycle = _PlannerLifecycle(habits, tasks, projects);
  return UiPluginRegistration(
    plugin: lifecycle,
    registry: ui,
    screens: [
      PluginScreenContribution(
        id: 'planner',
        label: 'НЕДЕЛЯ',
        icon: Icons.calendar_view_week_outlined,
        order: 7,
        builder: (_, screen) => PlannerScreen(
          tasks: lifecycle.tasksModel!,
          habits: lifecycle.model!,
          onOpenTask: (task) =>
              screen.openScreen('tasks', argument: task, select: false),
          isActive: () => screen.isActive,
        ),
      ),
    ],
  );
}

class _PlannerLifecycle implements AppPlugin {
  _PlannerLifecycle(this.habits, this.tasks, this.projects);
  final HabitsApi habits;
  final TasksApi tasks;
  final ProjectsQueries projects;
  HabitsViewModel? model;
  TasksViewModel? tasksModel;
  @override
  String get id => 'planner.screen';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    model = HabitsViewModel(habits)..initialize();
    tasksModel =
        TasksViewModel(
            tasks,
            GetTasksWithProjectsUseCase(tasks, projects),
            projects,
          )
          ..updateFilter((old) => old.copyWith(period: DatePeriod.week))
          ..initialize();
  }

  @override
  Future<void> stop() async {
    final previous = model;
    final previousTasks = tasksModel;
    model = null;
    tasksModel = null;
    previousTasks?.stopAccepting();
    try {
      await previous?.dispose();
    } finally {
      await previousTasks?.dispose();
    }
  }
}
