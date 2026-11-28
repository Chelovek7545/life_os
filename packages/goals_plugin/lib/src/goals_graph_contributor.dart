import 'package:graph_api/graph_api.dart';
import 'package:goals_api/goals_api.dart';

class GoalsGraphContributor implements GraphContributor {
  GoalsGraphContributor(this.goals);
  static const kind = 'goal';
  final GoalsQueries goals;
  @override
  String get id => 'goals.nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      goals.watchAllGoals().map(
        (values) => [
          for (final goal in values)
            if (scope.isCanvas ||
                goal.sphereId.isEmpty ||
                goal.sphereId == scope.rootId)
              GraphNodeData(
                id: goal.id,
                kind: kind,
                title: goal.name,
                subtitle: goal.description,
                color: goal.color,
                attributes: {
                  if (scope.isCanvas && goal.dueDate != null)
                    'dueDate': goal.dueDate,
                  if (goal.storageRevision != null)
                    'storageRevision': goal.storageRevision,
                },
                parentId: goal.sphereId.isEmpty ? null : goal.sphereId,
              ),
        ],
      );
}
