import 'package:graph_api/graph_api.dart';
import 'package:goals_api/goals_api.dart';
import 'goals_graph_contributor.dart';

GraphNodeCommands goalsGraphCommands(
  GoalsApi goals, {
  required GraphDeleteHandler delete,
}) => GraphNodeCommands(
  kind: GoalsGraphContributor.kind,
  parentKinds: {'sphere'},
  create: (request) async {
    final goal = Goal.create(
      name: request.draft.title,
      description: request.draft.subtitle,
      color: request.draft.color ?? '#FF5C00',
      sphereId: request.parent.id,
    );
    await goals.addGoal(goal);
    return goal.id;
  },
  update: (request) async {
    final existing = await goals.getGoal(request.current.id);
    if (existing == null) return;
    await goals.updateGoal(
      existing.copyWith(
        name: request.updated.title,
        description: request.updated.subtitle,
        color: request.updated.color,
        updatedAt: DateTime.now(),
      ),
    );
  },
  delete: delete,
);
