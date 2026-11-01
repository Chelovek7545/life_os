import 'package:today_plugin/today_plugin.dart';
import 'package:tasks_plugin/tasks_panels.dart';
import 'package:habits_plugin/habits_panels.dart';
import 'package:projects_plugin/projects_panels.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:habits_api/habits_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:plugin_ui/plugin_ui.dart';

TodayPlugin createTodayPlugin({
  required PluginUiRegistry ui,
  required TasksApi tasks,
  required HabitsApi habits,
  required ProjectsQueries projects,
}) => TodayPlugin(
  ui: ui,
  panels: (date) => [
    TasksPanelModule(
      id: 'today.tasks',
      slot: TodayPanelSlots.tasks,
      ui: ui,
      tasks: tasks,
      projects: projects,
      date: date,
    ),
    HabitsPanelModule(
      id: 'today.habits',
      slot: TodayPanelSlots.habits,
      ui: ui,
      habits: habits,
      date: date,
    ),
    ProjectsPanelModule(
      id: 'today.projects',
      slot: TodayPanelSlots.projects,
      ui: ui,
      projects: projects,
      tasks: tasks,
      date: date,
    ),
  ],
);
