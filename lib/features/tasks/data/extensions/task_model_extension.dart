import 'dart:convert';
import 'package:life_os/core/database/database.dart';
import 'package:drift/drift.dart';
import 'package:tasks_api/tasks_api.dart' show Tag, Task;

/// Extension для преобразования Drift модели в domain модель
extension TaskDataToDomain on TaskModel {
  List<String> get predecessorIds =>
      decodeTaskPredecessors(predecessorTaskId, additionalPredecessorTaskIds);

  Task toDomain({List<Tag>? tags, String? storageRevision}) {
    return Task(
      id: id,
      title: title,
      description: description,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      startsAt: startsAt,
      endsAt: endsAt,
      dueDate: dueDate,
      projectId: projectId,
      parentTaskId: parentTaskId,
      predecessorTaskId: predecessorTaskId,
      additionalPredecessorTaskIds: List.unmodifiable(
        _decodeAdditionalPredecessors(additionalPredecessorTaskIds),
      ),
      space: space,
      spaceId: spaceId,
      priority: priority,
      timerSeconds: timerSeconds,
      effortWeight: effortWeight,
      tags: tags ?? const [],
      storageRevision: storageRevision,
    );
  }
}

List<String> _decodeAdditionalPredecessors(String? additional) =>
    additional == null
    ? const []
    : (jsonDecode(additional) as List).cast<String>();

String? _encodeAdditionalPredecessors(Iterable<String> ids) =>
    ids.isEmpty ? null : jsonEncode(ids.toList());

List<String> decodeTaskPredecessors(String? first, String? additional) => [
  ?first,
  ..._decodeAdditionalPredecessors(additional),
];

TasksCompanion taskPredecessorUpdate(List<String> ids, DateTime updatedAt) =>
    TasksCompanion(
      predecessorTaskId: Value(ids.firstOrNull),
      additionalPredecessorTaskIds: Value(
        _encodeAdditionalPredecessors(ids.skip(1)),
      ),
      updatedAt: Value(updatedAt),
    );

extension TaskPredecessorCleanup on AppDatabase {
  Future<void> clearTaskPredecessors(Set<String> removedIds) async {
    final candidates =
        await (select(tasks)..where(
              (row) =>
                  row.predecessorTaskId.isIn(removedIds) |
                  row.additionalPredecessorTaskIds.isNotNull(),
            ))
            .get();
    final now = DateTime.now();
    for (final task in candidates) {
      if (removedIds.contains(task.id)) continue;
      final before = task.predecessorIds;
      final kept = before.where((id) => !removedIds.contains(id)).toList();
      if (kept.length == before.length) continue;
      await (update(tasks)..where((row) => row.id.equals(task.id))).write(
        taskPredecessorUpdate(kept, now),
      );
    }
  }
}

/// Extension для преобразования domain модели в Drift companion
extension TaskToDrift on Task {
  TasksCompanion toDrift() {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      status: Value(status),

      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      startsAt: Value(startsAt),
      endsAt: Value(endsAt),
      dueDate: Value(dueDate),
      projectId: Value(projectId),
      parentTaskId: Value(parentTaskId),
      predecessorTaskId: Value(predecessorTaskId),
      additionalPredecessorTaskIds: Value(
        _encodeAdditionalPredecessors(additionalPredecessorTaskIds),
      ),
      space: Value(space),
      spaceId: Value(spaceId),
      priority: Value(priority),
      timerSeconds: Value(timerSeconds),
      effortWeight: Value(effortWeight),
    );
  }
}
