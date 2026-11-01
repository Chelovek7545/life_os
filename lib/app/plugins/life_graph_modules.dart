import 'package:graph_ui/graph_ui.dart';
import 'package:graph_api/graph_api.dart';
import 'package:life_os/features/spheres/presentation/spheres_graph_ui.dart';
import 'package:life_os/features/goals/presentation/goals_graph_ui.dart';
import 'package:life_os/features/projects/presentation/projects_graph_ui.dart';
import 'package:life_os/features/tasks/presentation/tasks_graph_ui.dart';
import 'package:life_os/features/lifegraph/domain/graph_deletion.dart';
import 'package:life_os/features/spheres/domain/spheres_graph_commands.dart';
import 'package:life_os/features/goals/domain/goals_graph_commands.dart';
import 'package:life_os/features/projects/domain/projects_graph_commands.dart';
import 'package:life_os/features/tasks/domain/tasks_graph_commands.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/projects/domain/projects_api.dart';
import 'package:life_os/features/spheres/domain/spheres_graph_contributor.dart';
import 'package:life_os/features/goals/domain/goals_graph_contributor.dart';
import 'package:life_os/features/projects/domain/projects_graph_contributor.dart';
import 'package:life_os/features/tasks/domain/tasks_graph_contributor.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_card.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_sizes.dart';

List<GraphModule> lifeGraphModules({
  required SpheresApi spheres,
  required GoalsApi goals,
  required ProjectsApi projects,
  required TasksApi tasks,
  required GraphDeletion deletion,
}) => [
  GraphModule(
    id: 'spheres.graph',
    contributors: [SpheresGraphContributor(spheres)],
    presentations: [_presentation(GraphNodeType.sphere)],
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
    presentations: [_presentation(GraphNodeType.goal)],
    editors: [goalsGraphEditor()],
    childActions: [goalsGraphChildAction()],
    commands: [
      goalsGraphCommands(goals, delete: _delete(deletion, GraphNodeType.goal)),
    ],
  ),
  GraphModule(
    id: 'projects.graph',
    dependencies: {'goals.graph'},
    contributors: [ProjectsGraphContributor(projects)],
    presentations: [_presentation(GraphNodeType.project)],
    editors: [projectsGraphEditor()],
    childActions: projectsGraphChildActions(),
    commands: [
      projectsGraphCommands(
        projects,
        delete: _delete(deletion, GraphNodeType.project),
      ),
    ],
  ),
  GraphModule(
    id: 'tasks.graph',
    dependencies: {'projects.graph'},
    contributors: [TasksGraphContributor(tasks)],
    editors: tasksGraphEditors(),
    childActions: tasksGraphChildActions(tasks),
    presentations: [
      _presentation(GraphNodeType.task),
      _presentation(GraphNodeType.subTask),
    ],
    commands: tasksGraphCommands(
      tasks,
      delete: _delete(deletion, GraphNodeType.task),
    ),
  ),
];

GraphDeleteHandler _delete(GraphDeletion deletion, GraphNodeType type) =>
    (request) => deletion.delete(
      type,
      request.node.id,
      keepChildren: request.keepChildren,
    );

GraphNodePresentation _presentation(GraphNodeType type) =>
    GraphNodePresentation(
      kind: type.name,
      size: graphNodeSizeOf(type),
      builder: (context, node, interaction) => GraphNodeCard(
        state: interaction,
        node: GraphNode.fromData(node),
        onTap: interaction.edit,
        onAddChild: interaction.addChild,
        onDelete: interaction.remove,
      ),
    );
