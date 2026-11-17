import 'package:tasks_api/tasks_api.dart';

/// Transaction boundary injected by the application composition.
abstract interface class TaskMutationJournal {
  Future<String?> observedRevision(String key, String payload);
  Future<Map<String, String>> observedRevisions(Map<String, String> payloads);
  Future<T> trackEntity<T>(
    String type,
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  });
  Future<T> trackTask<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  });
  Future<T> trackGraph<T>(Future<T> Function() write);
  Future<Task> observe(Task task);
  Future<List<Task>> observeTasks(List<Task> tasks);
  Future<WorkLog> observeWorkLog(WorkLog log);
  Future<List<WorkLog>> observeWorkLogs(List<WorkLog> logs);
  Future<T> trackWorkLog<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  });
}
