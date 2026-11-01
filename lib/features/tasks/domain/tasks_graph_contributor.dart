import 'package:graph_api/graph_api.dart';
import 'package:tasks_api/tasks_api.dart';

class TasksGraphContributor implements GraphContributor {
  TasksGraphContributor(this.tasks);
  static const taskKind = 'task';
  static const subTaskKind = 'subTask';
  final TaskQueries tasks;
  @override
  String get id => 'tasks.nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) => tasks.watchTasks().map(
    (values) => [
      for (final task in values)
        GraphNodeData(
          id: task.id,
          kind: task.parentTaskId == null ? taskKind : subTaskKind,
          title: task.title,
          subtitle: task.description.isEmpty
              ? 'Нет описания'
              : task.description,
          color: '#CCC2DC',
          parentId: task.parentTaskId ?? task.projectId,
          inheritParentColor: task.parentTaskId == null,
          attributes: {'taskStatus': task.status.name},
        ),
    ],
  );
}
