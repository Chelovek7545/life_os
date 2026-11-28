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
    if (existing.storageRevision != null &&
        request.current.attributes['storageRevision'] !=
            existing.storageRevision) {
      throw StateError('Node changed; reload before saving.');
    }
    final attributes = request.updated.attributes;
    final dueDate = attributes['dueDate'] as DateTime?;
    await goals.updateGoal(
      existing.copyWith(
        name: request.updated.title,
        description: request.updated.subtitle,
        color: request.updated.color,
        dueDate: dueDate,
        clearDueDate: attributes.containsKey('dueDate') && dueDate == null,
        updatedAt: DateTime.now(),
      ),
    );
  },
  detach: (request) async {
    final goal = await goals.getGoal(request.target.id);
    if (request.linkType != GraphLinkType.hierarchy ||
        goal == null ||
        goal.sphereId != request.source.id) {
      throw StateError('Связь цели уже изменилась.');
    }
    await goals.updateGoal(goal.copyWith(sphereId: ''));
  },
  delete: delete,
);
