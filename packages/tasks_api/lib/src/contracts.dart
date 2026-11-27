import 'task.dart';
import 'work_log.dart';

enum TaskSequenceDirection { previous, next }

abstract interface class TaskQueries {
  Future<Task?> getById(String id);
  Future<List<Task>> getAllTasks();
  Stream<List<Task>> watchTasks();
  Stream<List<Task>> watchTasksForProject(String projectId);
}

abstract interface class TaskCommands {
  Future<void> addTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> setTaskStatus(String id, TaskStatus status);
  Future<void> moveTaskUnder(String id, String parentId);
  Future<void> linkTaskAfter(String id, String predecessorId);
  Future<void> replaceTaskSequenceLink(
    String id,
    TaskSequenceDirection direction, {
    required String? oldTaskId,
    required String? newTaskId,
  });
  Future<void> deleteTask(String id);
}

abstract interface class TasksApi implements TaskQueries, TaskCommands {}

abstract interface class TaskCompletionCommands {
  Future<Task?> completeTask(String id);
}

abstract interface class WorkLogsApi {
  Future<List<WorkLog>> getWorkLogsForTask(String taskId);
  Future<List<WorkLog>> getPageForTask(
    String taskId, {
    required int limit,
    required int offset,
    DateTime? from,
    DateTime? until,
    int? status,
    String? search,
  });
  Future<WorkLog?> getById(String id);
  Stream<List<WorkLog>> watchWorkLogsForTask(String taskId);
  Future<void> addWorkLog(WorkLog workLog);
  Future<void> updateWorkLog(WorkLog workLog);
  Future<void> setWorkLogStatus(String id, int status);
  Future<void> deleteWorkLog(String id);
}
