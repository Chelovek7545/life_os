import 'package:graph_ui/graph_ui.dart';
import 'package:graph_api/graph_api.dart';
import 'package:goals_plugin/goals_plugin.dart';
import 'package:spheres_plugin/spheres_plugin.dart';
import 'package:life_os/features/lifegraph/domain/graph_deletion.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'goals_plugin_adapter.dart';
import 'spheres_plugin_adapter.dart';

// Compatibility composition for callers that still supply GraphModule lists.
List<GraphModule> lifeGraphModules({
  required SpheresApi spheres,
  required GoalsApi goals,
  required GraphDeletion deletion,
}) => [
  spheresGraphModule(
    spheres: spheres,
    visuals: spheresUiBindings(),
    delete: _delete(deletion, GraphNodeType.sphere),
  ),
  goalsGraphModule(
    goals: goals,
    visuals: goalsUiBindings(),
    delete: _delete(deletion, GraphNodeType.goal),
  ),
];

GraphDeleteHandler _delete(GraphDeletion deletion, GraphNodeType type) =>
    (request) => deletion.delete(
      type,
      request.node.id,
      keepChildren: request.keepChildren,
    );
