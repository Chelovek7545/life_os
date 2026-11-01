import 'package:flutter/material.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'tasks_screen.dart';
import 'tasks_view_model.dart';

UiModuleSpec tasksScreenModule(
  TasksViewModel viewModel,
  WorkLogsApi workLogs,
) => UiModuleSpec(
  id: 'tasks.screen',
  screens: [
    PluginScreenContribution(
      id: 'tasks',
      label: 'TASKS',
      icon: Icons.format_list_bulleted_rounded,
      order: 10,
      onOpen: (argument) {
        if (argument == null) return;
        if (argument is! Task) {
          throw ArgumentError('The task editor expects a Task.');
        }
        viewModel.openTaskInEditor(argument);
      },
      builder: (_, screen) => TasksScreen(
        viewModel: viewModel,
        workLogs: workLogs,
        onFormVisibilityChanged: screen.setResizeToAvoidBottomInset,
      ),
    ),
  ],
);
