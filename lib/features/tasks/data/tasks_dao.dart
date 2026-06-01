import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:rxdart/rxdart.dart';

import 'package:life_os/features/tasks/domain/task_model.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(AppDatabase db) : super(db);

  // =============== CREATE ===============

  Future<int> insert(TasksCompanion task) {
    return into(tasks).insert(task);
  }




  // =============== READ ===============
  
  Future<List<TaskModel>> getAllTasks() {
    return select(tasks).get();
  }

  Future<TaskModel?> getById(String id) async {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingle();
  }

  Stream<List<TaskModel>> watchAllTasks() {
    return select(tasks).watch();
  }




  // =============== UPDATE ===============

  Future<bool> updateTask(TasksCompanion task) {
    return update(tasks).replace(task);
  }

  // =============== DELETE ===============
  
  /// Удалить задачу
  Future<void> deleteTask(String id) async {
    await (delete(tasks)..where((t) => t.id.equals(id))).go();
  }

}
