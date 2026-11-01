import 'package:core_contracts/core_contracts.dart' show StorageException;
import 'package:tasks_api/tasks_api.dart' show TasksApi, Task;
import 'package:life_os/features/tasks/data/extensions/tag_model_extension.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';


class TasksRepository implements TasksApi {
  TasksRepository(this._dao);

  final TasksDao _dao;

  @override
  Stream<List<Task>> watchTasks() => _dao.watchAllTasksWithTags();

  @override
  Stream<List<Task>> watchTasksForProject(String projectId) =>
      _dao.watchTasksForProject(projectId);

  @override
  Future<Task?> getById(String id) => _dao.getTaskWithTags(id);

  @override
  Future<List<Task>> getAllTasks() async {
    final tasksWithTags = await _dao.getAllTasksWithTags();
    return tasksWithTags.entries.map((entry) {
      return entry.key.toDomain(
        tags: entry.value.map((e) => e.toDomain()).toList(),
      );
    }).toList();
  }

  @override
  Future<void> addTask(Task task) async {
    try {
      await _dao.insertTaskWithTags(
        task.toDrift(),
        task.tags.map((e) => e.name).toList(),
      );
    } catch (error) {
      throw StorageException('Failed to save task.', error);
    }
  }

  @override
  Future<void> updateTask(Task task) async {
    try {
      final companion = task.toDrift();

      // Собираем плоский список ID тегов, которые сейчас привязаны к задаче
      final tagNames = task.tags.map((tag) => tag.name).toList();

      // Вызываем наш обновленный метод из DAO
      await _dao.updateTaskWithTags(companion, tagNames);
    } catch (error) {
      throw StorageException('Failed to update task.', error);
    }
  }

  @override
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
