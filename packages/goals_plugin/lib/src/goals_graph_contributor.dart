import 'package:graph_api/graph_api.dart';
import 'package:goals_api/goals_api.dart';

class GoalsGraphContributor implements GraphContributor {
  GoalsGraphContributor(this.goals);
  static const kind = 'goal';
  final GoalsQueries goals;
  @override
  String get id => 'goals.nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) => goals
      .watchGoalsBySphere(scope.rootId)
      .map(
        (values) => [
          for (final goal in values)
            GraphNodeData(
              id: goal.id,
              kind: kind,
              title: goal.name,
              subtitle: goal.description,
              color: goal.color,
              parentId: goal.sphereId,
            ),
        ],
      );
}
