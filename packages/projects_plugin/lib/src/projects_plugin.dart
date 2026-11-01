import 'package:flutter/material.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'projects_view_model.dart';
import 'projects_graph_contributor.dart';
import 'projects_graph_commands.dart';

/// The application's visual adapters for the projects module.
class ProjectsUiBindings {
  const ProjectsUiBindings({
    required this.screen,
    required this.nodeCard,
    required this.nodeSize,
    required this.editor,
    required this.createForm,
  });
  final Widget Function(BuildContext, ProjectsViewModel) screen;
  final Widget Function(BuildContext, GraphNodeData, GraphNodeInteraction)
  nodeCard;
  final Size nodeSize;
  final GraphFormBuilder editor;
  final GraphFormBuilder createForm;
}

List<GraphChildAction> projectsChildActions(GraphFormBuilder createForm) => [
  GraphChildAction(
    id: 'projects.create',
    label: 'Новый проект',
    childKind: 'project',
    parentKinds: {'goal'},
    builder: createForm,
  ),
  GraphChildAction(
    id: 'projects.createChild',
    label: 'Новый подпроект',
    childKind: 'project',
    parentKinds: {'project'},
    order: 20,
    builder: createForm,
  ),
];

PluginScreenContribution projectsScreenContribution({
  required ProjectsViewModel Function() model,
  required Widget Function(BuildContext, ProjectsViewModel) builder,
}) => PluginScreenContribution(
  id: 'projects',
  label: 'PROJECTS',
  icon: Icons.hub_outlined,
  order: 20,
  builder: (context, _) => builder(context, model()),
);

/// Owns project graph registrations and the lifetime of its screen model.
///
/// Storage and visual adapters are provided by the composition root. Each
/// start of the screen component creates a fresh model; stopped models reject
/// new work.
class ProjectsPlugin {
  ProjectsPlugin({
    required this._projects,
    required this._tasks,
    required GraphContributorRegistry contributors,
    required GraphNodePresentationRegistry presentations,
    required GraphEditorRegistry editors,
    required GraphCommandRegistry commands,
    required PluginUiRegistry ui,
    required ProjectsUiBindings visuals,
    required GraphDeleteHandler delete,
  }) {
    final graph = GraphModulePlugin(
      module: GraphModule(
        id: 'projects.graph',
        dependencies: {'goals.graph'},
        contributors: [ProjectsGraphContributor(_projects)],
        commands: [projectsGraphCommands(_projects, delete: delete)],
        presentations: [
          GraphNodePresentation(
            kind: 'project',
            size: visuals.nodeSize,
            builder: visuals.nodeCard,
          ),
        ],
        editors: [GraphNodeEditor(kind: 'project', builder: visuals.editor)],
        childActions: projectsChildActions(visuals.createForm),
      ),
      contributors: contributors,
      presentations: presentations,
      editors: editors,
      commands: commands,
    );
    final screen = UiPluginRegistration(
      plugin: _ProjectsScreenLifecycle(this),
      registry: ui,
      screens: [
        projectsScreenContribution(
          model: () => viewModel,
          builder: visuals.screen,
        ),
      ],
    );
    plugins = List.unmodifiable([graph, screen]);
  }

  final ProjectsApi _projects;
  final TasksApi _tasks;
  ProjectsViewModel? _viewModel;
  late final List<AppPlugin> plugins;
  ProjectsViewModel get viewModel =>
      _viewModel ?? (throw StateError('Projects screen is not active.'));
}

class _ProjectsScreenLifecycle implements AppPlugin {
  _ProjectsScreenLifecycle(this.module);
  final ProjectsPlugin module;
  @override
  String get id => 'projects.screen';
  @override
  Set<String> get dependencies => {'projects.graph'};
  @override
  Future<void> start() async {
    if (module._viewModel != null) return;
    final viewModel = ProjectsViewModel(
      repository: module._projects,
      taskRepo: module._tasks,
    );
    module._viewModel = viewModel;
    viewModel.initialize();
  }

  @override
  Future<void> stop() async {
    final viewModel = module._viewModel;
    module._viewModel = null;
    await viewModel?.dispose();
  }
}
