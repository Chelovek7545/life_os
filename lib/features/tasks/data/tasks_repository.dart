import 'package:core_contracts/core_contracts.dart' show StorageException;
import 'package:tasks_api/tasks_api.dart'
    show
        TasksApi,
        Task,
        TaskStatus,
        TaskCompletionCommands,
        TaskSequenceDirection;
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';

class TasksRepository implements TasksApi, TaskCompletionCommands {
  TasksRepository(this._dao);

  final TasksDao _dao;

  @override
  Future<void> setTaskStatus(String id, TaskStatus status) async {
    try {
      await _dao.setTaskStatus(id, status);
    } catch (error) {
      throw StorageException('Failed to change task status.', error);
    }
  }

  @override
  Future<void> moveTaskUnder(String id, String parentId) async {
    try {
      await _dao.moveTaskUnder(id, parentId);
    } catch (error) {
      throw StorageException('Failed to change task parent.', error);
    }
  }

  @override
  Future<void> linkTaskAfter(String id, String predecessorId) =>
      _dao.linkTaskAfter(id, predecessorId);

  @override
  Future<void> replaceTaskSequenceLink(
    String id,
    TaskSequenceDirection direction, {
    required String? oldTaskId,
    required String? newTaskId,
  }) => _dao.replaceTaskSequenceLink(
    id,
    direction,
    oldTaskId: oldTaskId,
    newTaskId: newTaskId,
  );

  @override
  Future<Task?> completeTask(String id) async {
    try {
      return await _dao.completeTask(id);
    } catch (error) {
      throw StorageException('Failed to complete task.', error);
    }
  }

  @override
  Stream<List<Task>> watchTasks() => _dao.watchAllTasksWithTags();

  @override
  Stream<List<Task>> watchTasksForProject(String projectId) =>
      _dao.watchTasksForProject(projectId);

  @override
  Future<Task?> getById(String id) => _dao.getTaskWithTags(id);

  @override
  Future<List<Task>> getAllTasks() async {
    return _dao.getAllDomainTasks();
  }

  @override
  Future<void> addTask(Task task) async {
    try {
      await _dao.insertTaskWithTags(
        task.toDrift(),
        task.tags.map((e) => e.name).toList(),
        tagSnapshots: task.tags,
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
      await _dao.updateTaskWithTags(
        companion,
        tagNames,
        expectedRevision: task.storageRevision,
        tagSnapshots: task.tags,
      );
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
