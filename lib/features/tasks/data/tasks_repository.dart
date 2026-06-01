import 'package:life_os/features/tasks/data/tasks_dao.dart';

import '../domain/task_model.dart';

class StorageException implements Exception {
  StorageException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class TasksRepository {
  TasksRepository(this._dao);

  final TasksDao _dao;

  Stream<List<Task>> watchTasks() => _dao.watchAllTasks().asyncMap((tasks) => tasks.map((e) => Task.fromDrift(e)).toList());

  Future<Task?> getById(String id) => _dao.getById(id).then((v) => v == null ? null : Task.fromDrift(v));

  Future<void> addTask(Task task) async {
    try {
      await _dao.insert(task.toDriftCompanion());
    } catch (error) {
      throw StorageException('Failed to save task.', error);
    }
  }

  Future<void> updateTask(Task task) async {
    try {
      await _dao.updateTask(task.toDriftCompanion());
    } catch (error) {
      throw StorageException('Failed to update task.', error);
    }
  }

  Future<void> deleteTask(String id) async {
    try {
      await _dao.deleteTask(id);
    } catch (error) {
      throw StorageException('Failed to delete task.', error);
    }
  }

  // Future<int> count() async {
  //   try {
  //     return await _dao.count();
  //   } catch (error) {
  //     throw StorageException('Failed to count tasks.', error);
  //   }
  // }
}
