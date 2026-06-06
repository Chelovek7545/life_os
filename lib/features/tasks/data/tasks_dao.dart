import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/extensions/tag_model_extension.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';
import 'package:rxdart/rxdart.dart';

import 'package:life_os/features/tasks/domain/task_model.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks, Tags, TaskTagEntries])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(AppDatabase db) : super(db);

  // =============== CREATE ===============

  Future<int> insert(TasksCompanion task) {
    return into(tasks).insert(task);
  }

  Future<void> insertTaskWithTags(TasksCompanion taskCompanion, List<String> tagNames) async {
    await transaction(() async {
      await into(tasks).insert(taskCompanion, mode: InsertMode.insertOrReplace);
      
      // Вызываем общий метод, передавая имена тегов
      await _syncTaskTags(taskCompanion.id.value, tagNames);
    });
  }



  //Заполняет таблицу taskTagEntries
  Future<void> _syncTaskTags(String taskId, List<String> tagNames) async {
    await (delete(taskTagEntries)..where((t) => t.taskId.equals(taskId))).go();

    if (tagNames.isEmpty) return;

    final List<int> finalTagIds = [];

    for (final name in tagNames) {
      final existingTag = await (select(
        tags,
      )..where((t) => t.name.equals(name))).getSingleOrNull();

      if (existingTag != null) {
        finalTagIds.add(existingTag.id);
      } else {
        final newTagId = await into(
          tags,
        ).insert(TagsCompanion.insert(name: name, colorHex: 0xFF9E9E9E));
        finalTagIds.add(newTagId);
      }
    }

    await batch((batch) {
      batch.insertAll(
        taskTagEntries,
        finalTagIds
            .map(
              (tagId) =>
                  TaskTagEntriesCompanion.insert(taskId: taskId, tagId: tagId),
            ).toList(),
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
    return (select(tasks)..where((t) => t.id.equals(id))).getSingle();
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
    return query.watch().map((rows) {
      // Внутри .map(...) мы трансформируем каждую новую порцию данных от БД

      final Map<TaskModel, List<TagModel>> grouped = {};

      for (final row in rows) {
        final task = row.readTable(tasks);
        final tag = row.readTableOrNull(tags);

        final list = grouped.putIfAbsent(task, () => []);
        if (tag != null) {
          list.add(tag);
          print(tag);
        }
      }

      // 3. Переводим сгруппированную мапу в список доменных моделей Task через маппер
      return grouped.entries.map((entry) {
        return entry.key.toDomain(
          tags: entry.value.map((e) => e.toDomain()).toList(),
        );
      }).toList();
    });
  }

  // =============== UPDATE ===============

  Future<bool> updateTaskWithTags(TasksCompanion taskCompanion, List<String> tagNames) async {
    // if (!taskCompanion.id.isPresent) {
    //   throw ArgumentError('Для обновления задачи необходим ID');
    // }
    final String taskId = taskCompanion.id.value;

    return transaction(() async {
      final bool isTaskUpdated = await update(tasks).replace(taskCompanion);
      if (!isTaskUpdated) return false;

      // Вызываем тот же метод синхронизации по именам
      await _syncTaskTags(taskId, tagNames);
      
      return true;
    });
  }

  // =============== DELETE ===============

  /// Удалить задачу
  Future<void> deleteTask(String id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }
}
