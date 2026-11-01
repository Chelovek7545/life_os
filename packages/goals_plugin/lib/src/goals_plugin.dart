import 'package:flutter/widgets.dart';
import 'package:goals_api/goals_api.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'goals_graph_commands.dart';
import 'goals_graph_contributor.dart';

class GoalsUiBindings {
  const GoalsUiBindings({
    required this.nodeCard,
    required this.nodeSize,
    required this.editor,
    required this.createForm,
  });
  final Widget Function(BuildContext, GraphNodeData, GraphNodeInteraction)
  nodeCard;
  final Size nodeSize;
  final GraphFormBuilder editor;
  final GraphFormBuilder createForm;
}

GraphChildAction goalsChildAction(GraphFormBuilder createForm) =>
    GraphChildAction(
      id: 'goals.create',
      label: 'Новую цель',
      childKind: 'goal',
      parentKinds: {'sphere'},
      builder: createForm,
    );

GraphModule goalsGraphModule({
  required GoalsApi goals,
  required GoalsUiBindings visuals,
  required GraphDeleteHandler delete,
}) => GraphModule(
  id: 'goals.graph',
  dependencies: {'spheres.graph'},
  contributors: [GoalsGraphContributor(goals)],
  commands: [goalsGraphCommands(goals, delete: delete)],
  presentations: [
    GraphNodePresentation(
      kind: 'goal',
      size: visuals.nodeSize,
      builder: visuals.nodeCard,
    ),
  ],
  editors: [GraphNodeEditor(kind: 'goal', builder: visuals.editor)],
  childActions: [goalsChildAction(visuals.createForm)],
);

class GoalsPlugin {
  GoalsPlugin({
    required GoalsApi goals,
    required GraphContributorRegistry contributors,
    required GraphNodePresentationRegistry presentations,
    required GraphEditorRegistry editors,
    required GraphCommandRegistry commands,
    required GoalsUiBindings visuals,
    required GraphDeleteHandler delete,
  }) {
    module = goalsGraphModule(goals: goals, visuals: visuals, delete: delete);
    plugins = List.unmodifiable([
      GraphModulePlugin(
        module: module,
        contributors: contributors,
        presentations: presentations,
        editors: editors,
        commands: commands,
      ),
    ]);
  }
  late final GraphModule module;
  late final List<AppPlugin> plugins;
}
