import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'get_tasks_with_projects_use_case.dart';
import 'tasks_graph_commands.dart';
import 'tasks_graph_contributor.dart';
import 'tasks_view_model.dart';
import 'work_logs_session.dart';

class TasksNodeUi {
  const TasksNodeUi({
    required this.size,
    required this.card,
    required this.editor,
    required this.create,
    required this.attach,
  });
  final Size size;
  final Widget Function(BuildContext, GraphNodeData, GraphNodeInteraction) card;
  final GraphFormBuilder editor;
  final GraphFormBuilder create;
  final GraphFormBuilder Function(Stream<List<Task>> Function() watchTasks)
  attach;
}

class TasksUiBindings {
  const TasksUiBindings({
    required this.screen,
    required this.task,
    required this.subtask,
  });
  final Widget Function(
    BuildContext,
    TasksViewModel,
    WorkLogsApi,
    ValueChanged<bool>,
  )
  screen;
  final TasksNodeUi task;
  final TasksNodeUi subtask;
}

List<GraphChildAction> tasksChildActions(
  TasksUiBindings visuals,
  Stream<List<Task>> Function() watchTasks,
) => [
  GraphChildAction(
    id: 'tasks.create',
    label: 'Новую задачу',
    childKind: 'task',
    parentKinds: {'project'},
    order: 10,
    builder: visuals.task.create,
  ),
  GraphChildAction(
    id: 'tasks.createSubtask',
    label: 'Новую подзадачу',
    childKind: 'subTask',
    parentKinds: {'task'},
    order: 10,
    builder: visuals.subtask.create,
  ),
  GraphChildAction(
    id: 'tasks.attach',
    label: 'Существующую задачу',
    childKind: 'task',
    parentKinds: {'project'},
    operation: GraphChildOperation.attach,
    builder: visuals.task.attach(watchTasks),
  ),
  GraphChildAction(
    id: 'tasks.attachSubtask',
    label: 'Существующую задачу',
    childKind: 'subTask',
    parentKinds: {'task'},
    operation: GraphChildOperation.attach,
    builder: visuals.subtask.attach(watchTasks),
  ),
];

class TasksPlugin {
  TasksPlugin({
    required this._tasks,
    required this._projects,
    required this._workLogs,
    required PluginUiRegistry ui,
    required GraphContributorRegistry contributors,
    required GraphNodePresentationRegistry presentations,
    required GraphEditorRegistry editors,
    required GraphCommandRegistry commands,
    required GraphDeleteHandler delete,
    required TasksUiBindings visuals,
  }) {
    final graph = GraphModulePlugin(
      module: GraphModule(
        id: 'tasks.graph',
        dependencies: {'tasks.core', 'projects.graph'},
        contributors: [TasksGraphContributor(_tasks)],
        commands: tasksGraphCommands(_tasks, delete: delete),
        presentations: [
          GraphNodePresentation(
            kind: 'task',
            size: visuals.task.size,
            builder: visuals.task.card,
          ),
          GraphNodePresentation(
            kind: 'subTask',
            size: visuals.subtask.size,
            builder: visuals.subtask.card,
          ),
        ],
        editors: [
          GraphNodeEditor(kind: 'task', builder: visuals.task.editor),
          GraphNodeEditor(kind: 'subTask', builder: visuals.subtask.editor),
        ],
        childActions: tasksChildActions(visuals, _watchFormTasks),
      ),
      contributors: contributors,
      presentations: presentations,
      editors: editors,
      commands: commands,
    );
    final screen = UiPluginRegistration(
      plugin: _TasksScreenLifecycle(this),
      registry: ui,
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
          builder: (context, screen) => visuals.screen(
            context,
            viewModel,
            workLogs,
            screen.setResizeToAvoidBottomInset,
          ),
        ),
      ],
    );
    plugins = List.unmodifiable([_TasksLifecycle(this), graph, screen]);
  }
  Stream<List<Task>> _watchFormTasks() {
    final model = _viewModel;
    return model == null || !model.isActive
        ? Stream.value(const [])
        : model.watchAllTasks();
  }

  final TasksApi _tasks;
  final ProjectsQueries _projects;
  final WorkLogsApi _workLogs;
  TasksViewModel? _viewModel;
  WorkLogsSession? _session;
  late final List<AppPlugin> plugins;
  TasksViewModel get viewModel =>
      _viewModel ?? (throw StateError('Tasks module is not active.'));
  WorkLogsApi get workLogs =>
      _session ?? (throw StateError('Tasks module is not active.'));
}

class _TasksLifecycle implements AppPlugin {
  _TasksLifecycle(this.module);
  final TasksPlugin module;
  @override
  String get id => 'tasks.core';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    if (module._viewModel != null) return;
    final useCase = GetTasksWithProjectsUseCase(
      module._tasks,
      module._projects,
    );
    module._session = WorkLogsSession(module._workLogs);
    final model = TasksViewModel(module._tasks, useCase, module._projects);
    module._viewModel = model;
    model.initialize();
  }

  @override
  Future<void> stop() async {
    final model = module._viewModel;
    final logs = module._session;
    module._viewModel = null;
    module._session = null;
    await Future.wait([
      if (model != null) model.dispose(),
      if (logs != null) logs.dispose(),
    ]);
  }
}

class _TasksScreenLifecycle implements AppPlugin {
  _TasksScreenLifecycle(this.module);
  final TasksPlugin module;
  @override
  String get id => 'tasks.screen';
  @override
  Set<String> get dependencies => {'tasks.graph'};
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {
    module._viewModel?.stopAccepting();
    module._session?.stopAccepting();
  }
}
