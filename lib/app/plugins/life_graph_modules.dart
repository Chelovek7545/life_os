import 'package:graph_ui/graph_ui.dart';
import 'package:graph_api/graph_api.dart';
import 'package:life_os/features/spheres/presentation/spheres_graph_ui.dart';
import 'package:life_os/features/goals/presentation/goals_graph_ui.dart';
import 'package:life_os/features/lifegraph/domain/graph_deletion.dart';
import 'package:life_os/features/spheres/domain/spheres_graph_commands.dart';
import 'package:life_os/features/goals/domain/goals_graph_commands.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:life_os/features/spheres/domain/spheres_graph_contributor.dart';
import 'package:life_os/features/goals/domain/goals_graph_contributor.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:life_os/features/lifegraph/presentation/widgets/builtin_graph_forms.dart';

List<GraphModule> lifeGraphModules({
  required SpheresApi spheres,
  required GoalsApi goals,
  required GraphDeletion deletion,
}) => [
  GraphModule(
    id: 'spheres.graph',
    contributors: [SpheresGraphContributor(spheres)],
    presentations: [builtinGraphPresentation(GraphNodeType.sphere)],
    editors: [spheresGraphEditor()],
    commands: [
      spheresGraphCommands(
        spheres,
        delete: _delete(deletion, GraphNodeType.sphere),
      ),
    ],
  ),
  GraphModule(
    id: 'goals.graph',
    dependencies: {'spheres.graph'},
    contributors: [GoalsGraphContributor(goals)],
    presentations: [builtinGraphPresentation(GraphNodeType.goal)],
    editors: [goalsGraphEditor()],
    childActions: [goalsGraphChildAction()],
    commands: [
      goalsGraphCommands(goals, delete: _delete(deletion, GraphNodeType.goal)),
    ],
  ),
];

GraphDeleteHandler _delete(GraphDeletion deletion, GraphNodeType type) =>
    (request) => deletion.delete(
      type,
      request.node.id,
      keepChildren: request.keepChildren,
    );
