import 'dart:async';
import 'package:flutter/material.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:projects_api/projects_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:tasks_plugin/tasks_panels.dart';
import 'package:life_os/features/tasks/presentation/components/task_calendar.dart';
import 'package:life_os/features/workspace/presentation/workspace_screen.dart';
import 'package:life_os/features/workspace/workspace_controller.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';

AppPlugin createWorkspacePlugin({
  required PluginUiRegistry ui,
  required TasksApi tasks,
  required ProjectsQueries projects,
}) {
  final lifecycle = _WorkspaceLifecycle(ui, tasks, projects);
  return UiPluginRegistration(
    plugin: lifecycle,
    registry: ui,
    screens: [
      PluginScreenContribution(
        id: 'workspace',
        label: 'ПРОСТРАНСТВО',
        icon: Icons.dashboard_customize_outlined,
        order: 8,
        builder: (_, screen) {
          final controller = lifecycle.controller!;
          bool active() =>
              screen.isActive &&
              controller.isActive &&
              lifecycle.controller == controller;
          void open(Task task) {
            if (active()) screen.openScreen('tasks', argument: task);
          }

          return WorkspaceScreen(
            controller: controller,
            editors: [
              WorkspaceEditor(
                id: 'tasks',
                label: 'Задачи',
                icon: Icons.checklist_outlined,
                builder: (_, id) => !active()
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        primary: false,
                        child: TasksPanel(
                          viewModel: lifecycle.models[id]!,
                          onOpenTask: open,
                        ),
                      ),
              ),
              WorkspaceEditor(
                id: 'calendar',
                label: 'Календарь',
                icon: Icons.calendar_view_week_outlined,
                builder: (_, id) => !active()
                    ? const SizedBox.shrink()
                    : TaskCalendar(
                        viewModel: lifecycle.models[id]!,
                        isWeek: true,
                        topPadding: 8,
                        onOpenTask: open,
                      ),
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _WorkspaceLifecycle implements AppPlugin {
  _WorkspaceLifecycle(this.ui, this.tasks, this.projects);
  static const storageKey = 'workspace.layout.v1';
  final PluginUiRegistry ui;
  final TasksApi tasks;
  final ProjectsQueries projects;
  WorkspaceController? controller;
  final models = <String, TasksViewModel>{};
  final _retired = <Future<void>>[];
  final _cleanupErrors = <Object>[];
  @override
  String get id => 'workspace.screen';
  @override
  Set<String> get dependencies => const {};

  @override
  Future<void> start() async {
    final preferences = await SharedPreferences.getInstance();
    const editors = {'tasks', 'calendar'};
    final saved = preferences.get(storageKey);
    final restored = saved is String
        ? WorkspaceLayout.decode(saved, editors)
        : null;
    controller = WorkspaceController(
      editorIds: editors,
      initial: restored ?? WorkspaceLayout.initial,
      save: (value) async {
        if (!await preferences.setString(storageKey, value)) {
          throw StateError('Could not save workspace layout');
        }
      },
      onSaveError: (_, _) => ui.notify(
        const PluginNotice(
          'Не удалось сохранить раскладку рабочего пространства',
          isError: true,
        ),
      ),
    );
    controller!.addListener(_reconcile);
    _reconcile();
    if (saved != null && restored == null) {
      ui.notify(
        const PluginNotice(
          'Сохранённая раскладка недоступна. Открыта стандартная раскладка.',
        ),
      );
    }
  }

  void _reconcile() {
    final panes = controller!.layout.root.panes.toList();
    final ids = panes.map((pane) => pane.id).toSet();
    for (final id in models.keys.toList()) {
      if (ids.contains(id)) continue;
      final model = models.remove(id)!;
      model.stopAccepting();
      _retired.add(
        model.dispose().catchError((Object error) {
          _cleanupErrors.add(error);
          ui.notify(
            const PluginNotice(
              'Не удалось закрыть ресурсы области',
              isError: true,
            ),
          );
        }),
      );
    }
    for (final pane in panes) {
      final model = models.putIfAbsent(
        pane.id,
        () => TasksViewModel(
          tasks,
          GetTasksWithProjectsUseCase(tasks, projects),
          projects,
        )..initialize(),
      );
      final period = pane.editorId == 'calendar'
          ? DatePeriod.week
          : DatePeriod.day;
      if (model.currentFilterValue.period != period) {
        model.updateFilter((filter) => filter.copyWith(period: period));
      }
    }
  }

  @override
  Future<void> stop() async {
    final previous = controller;
    controller = null;
    previous?.removeListener(_reconcile);
    for (final model in models.values) {
      model.stopAccepting();
    }
    try {
      await Future.wait<void>([
        if (previous != null) previous.close(),
        ..._retired,
        for (final model in models.values) model.dispose(),
      ]);
      if (_cleanupErrors.isNotEmpty) throw _cleanupErrors.first;
    } finally {
      models.clear();
      _retired.clear();
      _cleanupErrors.clear();
      previous?.dispose();
    }
  }
}
