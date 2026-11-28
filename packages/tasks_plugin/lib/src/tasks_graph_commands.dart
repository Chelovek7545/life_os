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
  Future<String> create(GraphNodeDraft draft, String? parentId) async {
    final task = Task.blank().copyWith(
      title: draft.title,
      description: draft.subtitle,
      projectId: Wrapped(subtask ? null : parentId),
      parentTaskId: Wrapped(subtask ? parentId : null),
      status: TaskStatus.notStarted,
      dueDate: Wrapped(draft.attributes['dueDate'] as DateTime?),
      startsAt: Wrapped(draft.attributes['startsAt'] as DateTime?),
      endsAt: Wrapped(draft.attributes['endsAt'] as DateTime?),
    );
    await tasks.addTask(task);
    return task.id;
  }

  return GraphNodeCommands(
    kind: kind,
    parentKinds: parentKinds,
    create: (request) => create(request.draft, request.parent.id),
    createStandalone: subtask ? null : (draft) => create(draft, null),
    update: (request) async {
      final existing = await tasks.getById(request.current.id);
      if (existing == null) return;
      if (existing.storageRevision != null &&
          request.current.attributes['storageRevision'] !=
              existing.storageRevision) {
        throw StateError('Node changed; reload before saving.');
      }
      final attributes = request.updated.attributes;
      final status = attributes['taskStatus'];
      await tasks.updateTask(
        existing.copyWith(
          title: request.updated.title,
          description: request.updated.subtitle == request.current.subtitle
              ? existing.description
              : request.updated.subtitle,
          status: status is String
              ? taskStatusFromStorage(status)
              : existing.status,
          priority: attributes['priority'] as int?,
          startsAt: _datePatch(attributes, 'startsAt'),
          endsAt: _datePatch(attributes, 'endsAt'),
          dueDate: _datePatch(attributes, 'dueDate'),
          projectId: !subtask && attributes.containsKey('projectId')
              ? Wrapped(attributes['projectId'] as String?)
              : null,
          updatedAt: DateTime.now(),
        ),
      );
    },
    attach: (request) async {
      if (request.linkType == GraphLinkType.sequence) {
        if (!subtask) throw UnsupportedError('Sequence requires two tasks.');
        await tasks.linkTaskAfter(request.id, request.parent.id);
        return request.id;
      }
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
        await tasks.moveTaskUnder(existing.id, request.parent.id);
      }
      return existing.id;
    },
    detach: (request) async {
      final id = request.target.id;
      final sourceId = request.source.id;
      if (request.linkType == GraphLinkType.sequence) {
        await tasks.replaceTaskSequenceLink(
          id,
          TaskSequenceDirection.previous,
          oldTaskId: sourceId,
          newTaskId: null,
        );
        return;
      }
      final task = await tasks.getById(id);
      if (task == null || (task.parentTaskId ?? task.projectId) != sourceId) {
        throw StateError('Связь задачи уже изменилась.');
      }
      final now = DateTime.now();
      await tasks.updateTask(
        task.parentTaskId != null
            ? task.copyWith(parentTaskId: const Wrapped(null), updatedAt: now)
            : task.copyWith(projectId: const Wrapped(null), updatedAt: now),
      );
    },
    delete: delete,
  );
}

Wrapped<DateTime?>? _datePatch(Map<String, Object?> attributes, String field) =>
    attributes.containsKey(field)
    ? Wrapped(attributes[field] as DateTime?)
    : null;
