import 'package:graph_api/graph_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'tasks_graph_contributor.dart';

List<GraphNodeCommands> tasksGraphCommands(
  TasksApi tasks, {
  required GraphDeleteHandler delete,
}) => [
  _commands(tasks, TasksGraphContributor.taskKind, {'project'}, delete),
  _commands(tasks, TasksGraphContributor.subTaskKind, {
    TasksGraphContributor.taskKind,
    TasksGraphContributor.subTaskKind,
  }, delete),
];

GraphNodeCommands _commands(
  TasksApi tasks,
  String kind,
  Set<String> parentKinds,
  GraphDeleteHandler delete,
) {
  final subtask = kind == TasksGraphContributor.subTaskKind;
  return GraphNodeCommands(
    kind: kind,
    parentKinds: parentKinds,
    create: (request) async {
      final draft = request.draft;
      final task = Task.blank().copyWith(
        title: draft.title,
        description: draft.subtitle,
        projectId: subtask ? const Wrapped(null) : Wrapped(request.parent.id),
        parentTaskId: subtask
            ? Wrapped(request.parent.id)
            : const Wrapped(null),
        status: TaskStatus.notStarted,
        dueDate: Wrapped(draft.attributes['dueDate'] as DateTime?),
        startsAt: Wrapped(draft.attributes['startsAt'] as DateTime?),
        endsAt: Wrapped(draft.attributes['endsAt'] as DateTime?),
      );
      await tasks.addTask(task);
      return task.id;
    },
    update: (request) async {
      final existing = await tasks.getById(request.current.id);
      if (existing == null) return;
      final status = request.updated.attributes['taskStatus'];
      await tasks.updateTask(
        existing.copyWith(
          title: request.updated.title,
          description: request.updated.subtitle,
          status: status is String
              ? taskStatusFromStorage(status)
              : existing.status,
          updatedAt: DateTime.now(),
        ),
      );
    },
    attach: (request) async {
      final existing = await tasks.getById(request.id);
      if (existing == null) return null;
      if (!subtask) {
        if (existing.projectId != null || existing.parentTaskId != null) {
          return null;
        }
        await tasks.updateTask(
          existing.copyWith(projectId: Wrapped(request.parent.id)),
        );
      } else {
        // Walk ancestors before writing: attaching a root below its descendant
        // would otherwise remove the whole branch from the graph.
        final byId = {
          for (final task in await tasks.getAllTasks()) task.id: task,
        };
        final visited = <String>{};
        String? ancestor = request.parent.id;
        while (ancestor != null) {
          if (ancestor == existing.id || !visited.add(ancestor)) {
            throw StateError('Attaching this task would create a cycle.');
          }
          ancestor = byId[ancestor]?.parentTaskId;
        }
        await tasks.updateTask(
          existing.copyWith(parentTaskId: Wrapped(request.parent.id)),
        );
      }
      return existing.id;
    },
    delete: delete,
  );
}
