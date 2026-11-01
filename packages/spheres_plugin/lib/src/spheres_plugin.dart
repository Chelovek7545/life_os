import 'package:flutter/widgets.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'spheres_graph_commands.dart';
import 'spheres_graph_contributor.dart';

class SpheresUiBindings {
  const SpheresUiBindings({
    required this.nodeCard,
    required this.nodeSize,
    required this.editor,
  });
  final Widget Function(BuildContext, GraphNodeData, GraphNodeInteraction)
  nodeCard;
  final Size nodeSize;
  final GraphFormBuilder editor;
}

GraphModule spheresGraphModule({
  required SpheresApi spheres,
  required SpheresUiBindings visuals,
  required GraphDeleteHandler delete,
}) => GraphModule(
  id: 'spheres.graph',
  contributors: [SpheresGraphContributor(spheres)],
  commands: [spheresGraphCommands(spheres, delete: delete)],
  presentations: [
    GraphNodePresentation(
      kind: 'sphere',
      size: visuals.nodeSize,
      builder: visuals.nodeCard,
    ),
  ],
  editors: [GraphNodeEditor(kind: 'sphere', builder: visuals.editor)],
);

class SpheresPlugin {
  SpheresPlugin({
    required SpheresApi spheres,
    required GraphContributorRegistry contributors,
    required GraphNodePresentationRegistry presentations,
    required GraphEditorRegistry editors,
    required GraphCommandRegistry commands,
    required SpheresUiBindings visuals,
    required GraphDeleteHandler delete,
  }) {
    module = spheresGraphModule(
      spheres: spheres,
      visuals: visuals,
      delete: delete,
    );
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
