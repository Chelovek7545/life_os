import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';

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

  Stream<List<Task>> watchTasks() => _dao.watchAllTasksWithTags();


  Future<Task?> getById(String id) => _dao.getById(id).then((v) => v == null ? null : v.toDomain());

  Future<void> addTask(Task task) async {
    try {
      await _dao.insertTaskWithTags(task.toDrift(), task.tags.map((e) => e.name).toList());
    } catch (error) {
      throw StorageException('Failed to save task.', error);
    }
  }


  Future<void> updateTask(Task task) async {
    try {
      final companion = task.toDrift();
  
      // Собираем плоский список ID тегов, которые сейчас привязаны к задаче
      final tagNames = task.tags.map((tag) => tag.name).toList();

      // Вызываем наш обновленный метод из DAO
      _dao.updateTaskWithTags(companion, tagNames);
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
