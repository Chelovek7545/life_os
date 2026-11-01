import 'package:spheres_plugin/spheres_plugin.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:graph_components/graph_components.dart';
import 'package:life_os/features/spheres/presentation/spheres_graph_ui.dart';

SpheresUiBindings spheresUiBindings() {
  final card = graphNodePresentation(sphereGraphComponent);
  return SpheresUiBindings(
    nodeCard: card.builder,
    nodeSize: card.size,
    editor: graphNodeEditor(sphereGraphComponent).builder,
  );
}

SpheresPlugin createSpheresPlugin({
  required SpheresApi spheres,
  required GraphContributorRegistry contributors,
  required GraphNodePresentationRegistry presentations,
  required GraphEditorRegistry editors,
  required GraphCommandRegistry commands,
  required GraphDeleteHandler delete,
}) => SpheresPlugin(
  spheres: spheres,
  contributors: contributors,
  presentations: presentations,
  editors: editors,
  commands: commands,
  visuals: spheresUiBindings(),
  delete: delete,
);
