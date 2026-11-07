import 'package:flutter/material.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'pulse_screen.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart'
    show PulseScreenViewModel;

UiModuleSpec pulseScreenModule(
  PulseScreenViewModel viewModel,
  PluginUiRegistry registry,
  Future<void> Function(Task) completeTask,
) => UiModuleSpec(
  id: 'lifegraph.screen',
  dependencies: {'spheres.graph'},
  screens: [
    PluginScreenContribution(
      id: 'pulse',
      label: 'PULSE',
      icon: Icons.bolt_rounded,
      ownsAppBar: true,
      builder: (_, screen) => PulseScreen(
        viewModel: viewModel,
        registry: registry,
        portraitAppBarAction: PluginActions(
          registry: registry,
          location: PluginActionLocation.appBar,
          compact: true,
        ),
        onOpenTask: (task) {
          if (!screen.openScreen('tasks', argument: task, select: false)) {
            registry.notify(const PluginNotice('Экран задач недоступен.'));
          }
        },
        onCompleteTask: (task) async {
          if (!screen.isActive) return;
          try {
            await completeTask(task);
          } catch (_) {
            registry.notify(
              const PluginNotice('Не удалось обновить задачу.', isError: true),
            );
          }
        },
      ),
    ),
  ],
);
