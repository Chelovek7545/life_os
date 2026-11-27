import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/extensions/tag_model_extension.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';

import 'package:tasks_api/tasks_api.dart'
    show Task, TaskStatus, Tag, TaskSequenceDirection;
import 'task_mutation_journal.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks, Tags, TaskTagEntries])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db, {this.journal});
  final TaskMutationJournal? journal;

  Future<T> _mutate<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) =>
      journal?.trackTask(
        id,
        write,
        expectedRevision: expectedRevision,
        requireExpected: requireExpected,
        createOnly: createOnly,
      ) ??
      transaction(write);

  Future<Task> _observe(Task task) async =>
      journal == null ? task : await journal!.observe(task);

  Future<List<Task>> _observeAll(Iterable<Task> tasks) async {
    final items = tasks.toList();
    return journal == null ? items : journal!.observeTasks(items);
  }

  Future<void> setTaskStatus(String id, TaskStatus status) {
    Future<void> write() async {
      await (update(tasks)..where(
            (row) => row.id.equals(id) & row.status.equalsValue(status).not(),
          ))
          .write(
            TasksCompanion(
              status: Value(status),
              updatedAt: Value(DateTime.now()),
            ),
          );
    }

    return journal?.trackStatus('task', id, write) ?? transaction(write);
  }

  Future<Task?> completeTask(String id) => transaction(() async {
    await setTaskStatus(id, TaskStatus.done);
    return getTaskWithTags(id);
  });

  Future<void> moveTaskUnder(String id, String parentId) => _mutate(
    id,
    () async {
      final task = await getById(id);
      if (task == null || task.parentTaskId == parentId) return;

      final visited = {id};
      String? ancestorId = parentId;
      while (ancestorId != null) {
        if (!visited.add(ancestorId)) {
          throw StateError('Moving this task would create a cycle.');
        }
        final ancestor = await getById(ancestorId);
        if (ancestor == null) throw StateError('Task parent no longer exists.');
        ancestorId = ancestor.parentTaskId;
      }

      await (update(tasks)..where((row) => row.id.equals(id))).write(
        TasksCompanion(
          parentTaskId: Value(parentId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    },
  );

  Future<void> linkTaskAfter(String id, String predecessorId) =>
      _mutate(id, () async {
        final task = await getById(id);
        if (task == null) throw StateError('Задача удалена.');
        final predecessors = task.predecessorIds;
        if (predecessors.contains(predecessorId)) return;
        await _checkPredecessors(id, [predecessorId]);
        await _writePredecessors(id, [...predecessors, predecessorId]);
      });

  Future<void> replaceTaskSequenceLink(
    String id,
    TaskSequenceDirection direction, {
    required String? oldTaskId,
    required String? newTaskId,
  }) => _mutate(id, () async {
    final task = await getById(id);
    if (task == null) throw StateError('Задача удалена.');
    if (oldTaskId == newTaskId) return;

    if (direction == TaskSequenceDirection.previous) {
      final predecessors = task.predecessorIds;
      if (oldTaskId != null && !predecessors.contains(oldTaskId)) {
        throw StateError('Предыдущая задача уже изменилась.');
      }
      await _checkPredecessors(id, [?newTaskId]);
      await _writePredecessors(
        id,
        {
          for (final predecessor in predecessors)
            if (predecessor != oldTaskId) predecessor,
          ?newTaskId,
        }.toList(),
      );
      return;
    }

    final old = oldTaskId == null ? null : await getById(oldTaskId);
    if (oldTaskId != null && !(old?.predecessorIds.contains(id) ?? false)) {
      throw StateError('Следующая задача уже изменилась.');
    }
    final next = newTaskId == null ? null : await getById(newTaskId);
    if (newTaskId != null) {
      if (next == null) throw StateError('Задача удалена.');
      await _checkPredecessors(newTaskId, [id]);
    }
    if (old != null) {
      await _writePredecessors(
        old.id,
        old.predecessorIds.where((predecessor) => predecessor != id).toList(),
      );
    }
    if (next != null && !next.predecessorIds.contains(id)) {
      await _writePredecessors(next.id, [...next.predecessorIds, id]);
    }
  });

  Future<void> _writePredecessors(String id, List<String> predecessors) async {
    await (update(tasks)..where((row) => row.id.equals(id))).write(
      taskPredecessorUpdate(predecessors, DateTime.now()),
    );
  }

  Future<void> _checkPredecessors(String id, List<String> predecessors) async {
    if (predecessors.toSet().length != predecessors.length) {
      throw StateError('Связь уже существует.');
    }
    final visited = <String>{};
    final pending = predecessors.toList();
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (next == id) {
        throw StateError('Получится замкнутая последовательность.');
      }
      if (!visited.add(next)) continue;
      final previous = await getById(next);
      if (previous == null) {
        throw StateError('Предшествующая задача удалена.');
      }
      pending.addAll(previous.predecessorIds);
    }
  }

  Future<void> _checkCompanionPredecessors(TasksCompanion task) async {
    final first = task.predecessorTaskId;
    final additional = task.additionalPredecessorTaskIds;
    if (!first.present && !additional.present) return;
    final existing = first.present && additional.present
        ? null
        : await getById(task.id.value);
    await _checkPredecessors(
      task.id.value,
      decodeTaskPredecessors(
        first.present ? first.value : existing?.predecessorTaskId,
        additional.present
            ? additional.value
            : existing?.additionalPredecessorTaskIds,
      ),
    );
  }

  // =============== CREATE ===============

  Future<int> insert(TasksCompanion task) {
    return _mutate(task.id.value, () async {
      await _checkCompanionPredecessors(task);
      return into(tasks).insert(task);
    }, createOnly: true);
  }

  Future<void> insertTaskWithTags(
    TasksCompanion taskCompanion,
    List<String> tagNames, {
    List<Tag>? tagSnapshots,
  }) async {
    await _mutate(taskCompanion.id.value, () async {
      await _checkCompanionPredecessors(taskCompanion);
      await into(tasks).insertOnConflictUpdate(taskCompanion);

      // Вызываем общий метод, передавая имена тегов
      await _syncTaskTags(taskCompanion.id.value, tagNames, tagSnapshots);
    }, createOnly: true);
  }

  //Заполняет таблицу taskTagEntries
  Future<void> _syncTaskTags(
    String taskId,
    List<String> tagNames,
    List<Tag>? snapshots,
  ) async {
    await (delete(taskTagEntries)..where((t) => t.taskId.equals(taskId))).go();

    if (tagNames.isEmpty) return;

    final List<int> finalTagIds = [];

    final requested =
        snapshots ??
        tagNames
            .toSet()
            .map((name) => Tag(id: 0, name: name, colorHex: 0xFF9E9E9E))
            .toList();
    for (final tag in requested) {
      final name = tag.name;
      final existingTag =
          await (select(tags)..where(
                (t) => tag.syncId == null
                    ? t.name.equals(name)
                    : t.syncId.equals(tag.syncId!),
              ))
              .getSingleOrNull();
      if (tag.syncId != null && existingTag == null) {
        throw StateError('Tag changed; reload the task before saving.');
      }

      if (existingTag != null) {
        finalTagIds.add(existingTag.id);
      } else {
        final newTagId = await into(
          tags,
        ).insert(TagsCompanion.insert(name: name, colorHex: tag.colorHex));
        finalTagIds.add(newTagId);
      }
    }

    await batch((batch) {
      batch.insertAll(
        taskTagEntries,
        finalTagIds
            .toSet()
            .map(
              (tagId) =>
                  TaskTagEntriesCompanion.insert(taskId: taskId, tagId: tagId),
            )
            .toList(),
      );
    });
  }

  // =============== READ ===============

  Future<List<TaskModel>> getAllTasks() {
    return select(tasks).get();
  }

  Future<Map<TaskModel, List<TagModel>>> getAllTasksWithTags() async {
    final query = select(tasks).join([
      leftOuterJoin(taskTagEntries, taskTagEntries.taskId.equalsExp(tasks.id)),
      leftOuterJoin(tags, tags.id.equalsExp(taskTagEntries.tagId)),
    ]);
    final rows = await query.get();

    // 2. Группируем результат, так как для одной задачи может прийти несколько строк (по одной на каждый тег)
    final Map<TaskModel, List<TagModel>> grouped = {};

    for (final row in rows) {
      final task = row.readTable(tasks);
      final tag = row.readTableOrNull(tags);

      final list = grouped.putIfAbsent(task, () => []);
      if (tag != null) {
        list.add(tag);
      }
    }

    return grouped;
  }

  Future<TaskModel?> getById(String id) async {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<Task?> getTaskWithTags(String id) => transaction(() async {
    final row = await getById(id);
    if (row == null) return null;
    final taskTags = await getTagsForTask(id);
    return _observe(
      row.toDomain(tags: taskTags.map((tag) => tag.toDomain()).toList()),
    );
  });

  Future<List<TagModel>> getTagsForTask(String id) async {
    final query = select(tags).join([
      innerJoin(taskTagEntries, taskTagEntries.tagId.equalsExp(tags.id)),
    ])..where(taskTagEntries.taskId.equals(id));
    return (await query.get()).map((row) => row.readTable(tags)).toList();
  }

  Stream<List<TaskModel>> watchAllTasks() {
    return select(tasks).watch();
  }

  Stream<List<Task>> watchAllTasksWithTags() {
    // 1. Строим запрос с JOIN (точно так же, как делали для Future)
    final query = select(tasks).join([
      leftOuterJoin(taskTagEntries, taskTagEntries.taskId.equalsExp(tasks.id)),
      leftOuterJoin(tags, tags.id.equalsExp(taskTagEntries.tagId)),
    ]);

    // 2. Вызываем watch() вместо get(), чтобы получить поток (Stream)
    return query.watch().asyncMap((rows) async {
      // Внутри .map(...) мы трансформируем каждую новую порцию данных от БД

      final Map<TaskModel, List<TagModel>> grouped = {};

      for (final row in rows) {
        final task = row.readTable(tasks);
        final tag = row.readTableOrNull(tags);

        final list = grouped.putIfAbsent(task, () => []);
        if (tag != null) {
          list.add(tag);
          //print(tag);
        }
      }

      // 3. Переводим сгруппированную мапу в список доменных моделей Task через маппер
      return _observeAll(
        grouped.entries.map((entry) {
          return entry.key.toDomain(
            tags: entry.value.map((e) => e.toDomain()).toList(),
          );
        }),
      );
    });
  }

  Stream<List<Task>> watchTasksForProject(String projectId) {
    final query = select(tasks).join([
      leftOuterJoin(taskTagEntries, taskTagEntries.taskId.equalsExp(tasks.id)),
      leftOuterJoin(tags, tags.id.equalsExp(taskTagEntries.tagId)),
    ])..where(tasks.projectId.equals(projectId));

    return query.watch().asyncMap((rows) async {
      final Map<TaskModel, List<TagModel>> grouped = {};

      for (final row in rows) {
        final task = row.readTable(tasks);
        final tag = row.readTableOrNull(tags);

        final list = grouped.putIfAbsent(task, () => []);
        if (tag != null) {
          list.add(tag);
        }
      }

      return _observeAll(
        grouped.entries.map((entry) {
          return entry.key.toDomain(
            tags: entry.value.map((e) => e.toDomain()).toList(),
          );
        }),
      );
    });
  }

  // =============== UPDATE ===============

  Future<bool> updateTaskWithTags(
    TasksCompanion taskCompanion,
    List<String> tagNames, {
    String? expectedRevision,
    List<Tag>? tagSnapshots,
  }) async {
    // if (!taskCompanion.id.isPresent) {
    //   throw ArgumentError('Для обновления задачи необходим ID');
    // }
    final String taskId = taskCompanion.id.value;

    return _mutate(
      taskId,
      () async {
        await _checkCompanionPredecessors(taskCompanion);
        final bool isTaskUpdated = await update(tasks).replace(taskCompanion);
        if (!isTaskUpdated) return false;

        // Вызываем тот же метод синхронизации по именам
        await _syncTaskTags(taskId, tagNames, tagSnapshots);

        return true;
      },
      expectedRevision: expectedRevision,
      requireExpected: true,
    );
  }

  // =============== DELETE ===============

  /// Удалить задачу
  Future<void> deleteTask(String id) async {
    await _mutate(id, () async {
      await attachedDatabase.clearTaskPredecessors({id});
      await (delete(tasks)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<List<Task>> getAllDomainTasks() => transaction(() async {
    final grouped = await getAllTasksWithTags();
    return _observeAll(
      grouped.entries.map(
        (entry) => entry.key.toDomain(
          tags: entry.value.map((tag) => tag.toDomain()).toList(),
        ),
      ),
    );
  });
}
