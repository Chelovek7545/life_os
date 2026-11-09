import 'task.dart';
import 'work_log.dart';

abstract interface class TaskQueries {
  Future<Task?> getById(String id);
  Future<List<Task>> getAllTasks();
  Stream<List<Task>> watchTasks();
  Stream<List<Task>> watchTasksForProject(String projectId);
}

abstract interface class TaskCommands {
  Future<void> addTask(Task task);
  Future<void> updateTask(Task task);
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
  Future<void> deleteWorkLog(String id);
}
