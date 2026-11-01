import 'dart:async';
import 'package:tasks_api/tasks_api.dart';
import 'package:projects_api/projects_api.dart';

class MemoryTasks implements TasksApi {
  final items = <String, Task>{};
  final listeners = <MultiStreamController<List<Task>>>{};
  final writes = <String>[];
  Completer<void>? writeGate;
  Completer<void>? entered;
  Completer<void>? cancelGate;
  bool failWrite = false;
  bool failWatch = false;
  bool failCancel = false;
  int watches = 0;
  @override
  Stream<List<Task>> watchTasks() {
    if (failWatch) throw StateError('Task source failed');
    return Stream.multi((sink) {
      watches++;
      listeners.add(sink);
      sink.add(items.values.toList());
      sink.onCancel = () async {
        await cancelGate?.future;
        listeners.remove(sink);
        if (failCancel) throw StateError('Task cancellation failed');
      };
    });
  }

  void emit() {
    for (final sink in listeners) {
      sink.add(items.values.toList());
    }
  }

  @override
  Stream<List<Task>> watchTasksForProject(String id) => watchTasks().map(
    (tasks) => tasks.where((task) => task.projectId == id).toList(),
  );
  @override
  Future<List<Task>> getAllTasks() async => items.values.toList();
  @override
  Future<Task?> getById(String id) async => items[id];
  Future<void> _write(String id, void Function() action) async {
    writes.add(id);
    if (entered case final signal? when !signal.isCompleted) signal.complete();
    await writeGate?.future;
    if (failWrite) {
      failWrite = false;
      throw StateError('Task write failed');
    }
    action();
    emit();
  }

  @override
  Future<void> addTask(Task task) =>
      _write(task.id, () => items[task.id] = task);
  @override
  Future<void> updateTask(Task task) =>
      _write(task.id, () => items[task.id] = task);
  @override
  Future<void> deleteTask(String id) => _write(id, () => items.remove(id));
}

class MemoryProjectQueries implements ProjectsQueries {
  final items = <String, Project>{};
  final listeners = <MultiStreamController<List<Project>>>{};
  @override
  Future<List<Project>> getAllProjects() async => items.values.toList();
  @override
  Future<Project?> getProjectById(String id) async => items[id];
  @override
  Stream<List<Project>> watchAllProjects() => Stream.multi((sink) {
    listeners.add(sink);
    sink.add(items.values.toList());
    sink.onCancel = () => listeners.remove(sink);
  });
}

class MemoryWorkLogs implements WorkLogsApi {
  final items = <String, WorkLog>{};
  final listeners = <MultiStreamController<List<WorkLog>>, String>{};
  Completer<void>? writeGate;
  Completer<void>? entered;
  Completer<void>? cancelGate;
  bool failWrite = false;
  bool failCancel = false;
  int watches = 0;
  List<Object?>? lastPage;
  @override
  Stream<List<WorkLog>> watchWorkLogsForTask(String taskId) =>
      Stream.multi((sink) {
        watches++;
        listeners[sink] = taskId;
        sink.add(items.values.where((log) => log.taskId == taskId).toList());
        sink.onCancel = () async {
          await cancelGate?.future;
          listeners.remove(sink);
          if (failCancel) throw StateError('Work log cancellation failed');
        };
      });
  void emit() {
    for (final entry in listeners.entries) {
      entry.key.add(
        items.values.where((log) => log.taskId == entry.value).toList(),
      );
    }
  }

  @override
  Future<List<WorkLog>> getWorkLogsForTask(String taskId) async =>
      items.values.where((log) => log.taskId == taskId).toList();
  @override
  Future<List<WorkLog>> getPageForTask(
    String taskId, {
    required int limit,
    required int offset,
    DateTime? from,
    DateTime? until,
    int? status,
    String? search,
  }) async {
    lastPage = [taskId, limit, offset, from, until, status, search];
    return (await getWorkLogsForTask(taskId)).skip(offset).take(limit).toList();
  }

  @override
  Future<WorkLog?> getById(String id) async => items[id];
  Future<void> _write(void Function() action) async {
    if (entered case final signal? when !signal.isCompleted) signal.complete();
    await writeGate?.future;
    if (failWrite) {
      failWrite = false;
      throw StateError('Work log write failed');
    }
    action();
    emit();
  }

  @override
  Future<void> addWorkLog(WorkLog log) => _write(() => items[log.id] = log);
  @override
  Future<void> updateWorkLog(WorkLog log) => _write(() => items[log.id] = log);
  @override
  Future<void> deleteWorkLog(String id) => _write(() => items.remove(id));
}
