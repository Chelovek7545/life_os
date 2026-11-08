import 'dart:async';
import 'package:flutter/material.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:projects_api/projects_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:tasks_plugin/tasks_panels.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/features/workspace/presentation/workspace_habits.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:life_os/features/lifegraph/presentation/pulse_screen.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/create_sphere_dialog.dart';
import 'package:life_os/features/workspace/presentation/workspace_hierarchy.dart';
import 'package:life_os/features/tasks/presentation/components/task_calendar.dart';
import 'package:life_os/features/workspace/presentation/workspace_screen.dart';
import 'package:life_os/features/workspace/workspace_controller.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';

AppPlugin createWorkspacePlugin({
  required PluginUiRegistry ui,
  required TasksApi tasks,
  required ProjectsQueries projects,
  required HabitsApi habits,
  required PulseScreenViewModel Function() pulse,
  WorkLogsApi Function()? workLogs,
}) {
  final lifecycle = _WorkspaceLifecycle(ui, tasks, projects, habits, pulse);
  return UiPluginRegistration(
    plugin: lifecycle,
    registry: ui,
    screens: [
      PluginScreenContribution(
        id: 'workspace',
        label: 'ПРОСТРАНСТВО',
        icon: Icons.dashboard_customize_outlined,
        order: 8,
        ownsAppBar: true,
        builder: (_, screen) {
          final controller = lifecycle.controller!;
          final pulseModel = lifecycle.pulseModel!;
          bool active() =>
              screen.isActive &&
              controller.isActive &&
              lifecycle.controller == controller;
          void open(Task task) {
            if (active()) {
              screen.openScreen('tasks', argument: task, select: false);
            }
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
                          taskBuilder: (_, item, onToggle, onOpen) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: TaskCard(
                              workLogs: workLogs?.call(),
                              key: ValueKey('workspace-task:${item.task.id}'),
                              task: item.task,
                              projectTitle: item.project?.name,
                              leftBorderColor: item.project == null
                                  ? null
                                  : parseHexColor(item.project!.color),
                              isSelected: false,
                              isOverdue:
                                  item.task.dueDate?.isBefore(
                                    DateUtils.dateOnly(DateTime.now()),
                                  ) ??
                                  false,
                              onCheckChanged: onToggle,
                              onTap: onOpen,
                            ),
                          ),
                        ),
                      ),
              ),
              WorkspaceEditor(
                id: 'hierarchy',
                label: 'Иерархия',
                icon: Icons.account_tree_outlined,
                builder: (_, id) => !active()
                    ? const SizedBox.shrink()
                    : WorkspaceHierarchy(
                        model: lifecycle.models[id]!,
                        onOpenTask: open,
                        isActive: active,
                      ),
              ),
              WorkspaceEditor(
                id: 'habits',
                label: 'Привычки',
                icon: Icons.autorenew,
                builder: (_, id) => !active()
                    ? const SizedBox.shrink()
                    : WorkspaceHabits(
                        model: lifecycle.habitModels[id]!,
                        isActive: active,
                      ),
              ),
              WorkspaceEditor(
                id: 'stats',
                label: 'Статистика',
                icon: Icons.bar_chart_outlined,
                builder: (_, id) => !active()
                    ? const SizedBox.shrink()
                    : StatsPanel(
                        viewModel: pulseModel,
                        onOpenTask: open,
                        onCompleteTask: (task) async {
                          if (!active()) return;
                          try {
                            await lifecycle.models[id]!.toggleTask(task);
                          } catch (_) {
                            if (active()) {
                              ui.notify(
                                const PluginNotice(
                                  'Не удалось обновить задачу',
                                  isError: true,
                                ),
                              );
                            }
                          }
                        },
                      ),
              ),
              WorkspaceEditor(
                id: 'spheres',
                label: 'Сферы',
                icon: Icons.public_outlined,
                builder: (context, id) => !active()
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        primary: false,
                        child: SpheresPanel(
                          viewModel: pulseModel,
                          expand: false,
                          onCreate: () {
                            if (active()) {
                              showDialog<void>(
                                context: context,
                                builder: (_) => CreateSphereDialog(
                                  viewModel: pulseModel,
                                  isActive: active,
                                ),
                              );
                            }
                          },
                          onOpenSphere: (sphere) async {
                            if (!active()) return;
                            try {
                              final graph = await pulseModel.openGraph(
                                sphere.id,
                              );
                              if (active() && context.mounted) {
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        LifeGraphScreen(viewModel: graph),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (active()) {
                                ui.notify(
                                  const PluginNotice(
                                    'Не удалось открыть сферу',
                                    isError: true,
                                  ),
                                );
                              }
                            }
                          },
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
  _WorkspaceLifecycle(
    this.ui,
    this.tasks,
    this.projects,
    this.habits,
    this.pulse,
  );
  static const storageKey = 'workspace.layout.v1';
  final PluginUiRegistry ui;
  final TasksApi tasks;
  final ProjectsQueries projects;
  final HabitsApi habits;
  final PulseScreenViewModel Function() pulse;
  PulseScreenViewModel? pulseModel;
  WorkspaceController? controller;
  final models = <String, TasksViewModel>{};
  final habitModels = <String, HabitsViewModel>{};
  final _retired = <Future<void>>[];
  final _cleanupErrors = <Object>[];
  @override
  String get id => 'workspace.screen';
  @override
  Set<String> get dependencies => const {'lifegraph.screen'};

  @override
  Future<void> start() async {
    final preferences = await SharedPreferences.getInstance();
    pulseModel = pulse();
    const editors = {
      'tasks',
      'calendar',
      'hierarchy',
      'habits',
      'stats',
      'spheres',
    };
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
    for (final id in habitModels.keys.toList()) {
      if (!ids.contains(id)) {
        _retired.add(
          habitModels.remove(id)!.dispose().catchError((Object error) {
            _cleanupErrors.add(error);
          }),
        );
      }
    }
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
      if (pane.editorId == 'habits') {
        habitModels.putIfAbsent(
          pane.id,
          () => HabitsViewModel(habits)..initialize(),
        );
      }
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
        for (final model in habitModels.values) model.dispose(),
      ]);
      if (_cleanupErrors.isNotEmpty) throw _cleanupErrors.first;
    } finally {
      models.clear();
      habitModels.clear();
      pulseModel = null;
      _retired.clear();
      _cleanupErrors.clear();
      previous?.dispose();
    }
  }
}
