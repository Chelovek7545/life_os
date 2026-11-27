import 'dart:convert';
import 'package:tasks_api/tasks_api.dart';

// Keeps the v1 shape for standalone tasks; hierarchy links require revision v2.
class TaskSyncCodec {
  static String encode(Task task) {
    final predecessors = task.predecessorTaskIds;
    if (predecessors.toSet().length != predecessors.length ||
        predecessors.any((id) => id.isEmpty || id.length > 128)) {
      throw const FormatException('Invalid task predecessors.');
    }
    if (task.tags.any((tag) => tag.syncId == null || tag.syncId!.isEmpty)) {
      throw const FormatException('Task tag has no portable identity.');
    }
    if (task.id.isEmpty || !task.effortWeight.isFinite) {
      throw const FormatException('Invalid task.');
    }
    return jsonEncode({
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'status': task.status.name,
      'createdAt': task.createdAt.toIso8601String(),
      'updatedAt': task.updatedAt.toIso8601String(),
      'startsAt': task.startsAt?.toIso8601String(),
      'endsAt': task.endsAt?.toIso8601String(),
      'dueDate': task.dueDate?.toIso8601String(),
      'space': task.space,
      'priority': task.priority,
      'timerSeconds': task.timerSeconds,
      'effortWeight': task.effortWeight,
      if (task.parentTaskId != null) 'parentTaskId': task.parentTaskId,
      if (predecessors.length == 1) 'predecessorTaskId': predecessors.single,
      if (predecessors.length > 1) 'predecessorTaskIds': predecessors,
      if (task.projectId != null) 'projectId': task.projectId,
      if (task.spaceId != null) 'spaceId': task.spaceId,
      if (task.tags.isNotEmpty)
        'tagIds': (task.tags.map((t) => t.syncId!).toSet().toList()..sort()),
    });
  }

  static Task decode(String payload) {
    final map = jsonDecode(payload) as Map<String, dynamic>;
    final predecessors =
        (map['predecessorTaskIds'] as List?)?.cast<String>() ??
        [?(map['predecessorTaskId'] as String?)];
    DateTime? date(String key) =>
        map[key] == null ? null : DateTime.parse(map[key] as String);
    final task = Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      status: TaskStatus.values.byName(map['status'] as String),
      createdAt: date('createdAt')!,
      updatedAt: date('updatedAt')!,
      startsAt: date('startsAt'),
      endsAt: date('endsAt'),
      dueDate: date('dueDate'),
      space: map['space'] as String?,
      priority: map['priority'] as int,
      timerSeconds: map['timerSeconds'] as int,
      effortWeight: (map['effortWeight'] as num).toDouble(),
      tags: ((map['tagIds'] as List?) ?? [])
          .map((id) => Tag(id: 0, name: '', colorHex: 0, syncId: id as String))
          .toList(),
      projectId: map['projectId'] as String?,
      spaceId: map['spaceId'] as String?,
      parentTaskId: map['parentTaskId'] as String?,
      predecessorTaskId: predecessors.firstOrNull,
      additionalPredecessorTaskIds: List.unmodifiable(predecessors.skip(1)),
    );
    // Strict canonical format prevents silently ignoring fields from a newer peer.
    if (encode(task) != payload) {
      throw const FormatException('Noncanonical task payload.');
    }
    return task;
  }
}
