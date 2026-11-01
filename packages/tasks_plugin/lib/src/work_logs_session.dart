import 'dart:async';
import 'package:tasks_api/tasks_api.dart';
import 'package:plugin_runtime/owned_streams.dart';

/// A plugin-owned lifetime for work log requests and subscriptions.
class WorkLogsSession implements WorkLogsApi {
  WorkLogsSession(this._repository);
  final WorkLogsApi _repository;
  final _streams = OwnedStreams();
  bool _accepting = true;
  Future<void> _operations = Future.value();
  Future<void>? _closing;

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (!_accepting) {
      return Future.error(StateError('Work logs session is closed.'));
    }
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  @override
  Future<List<WorkLog>> getWorkLogsForTask(String taskId) => _enqueue(
    () async => List.unmodifiable(await _repository.getWorkLogsForTask(taskId)),
  );
  @override
  Future<List<WorkLog>> getPageForTask(
    String taskId, {
    required int limit,
    required int offset,
    DateTime? from,
    DateTime? until,
    int? status,
    String? search,
  }) => _enqueue(
    () async => List.unmodifiable(
      await _repository.getPageForTask(
        taskId,
        limit: limit,
        offset: offset,
        from: from,
        until: until,
        status: status,
        search: search,
      ),
    ),
  );
  @override
  Future<WorkLog?> getById(String id) =>
      _enqueue(() => _repository.getById(id));
  @override
  Stream<List<WorkLog>> watchWorkLogsForTask(String taskId) => _streams.watch(
    () => _repository
        .watchWorkLogsForTask(taskId)
        .map((values) => List<WorkLog>.unmodifiable(values)),
  );
  @override
  Future<void> addWorkLog(WorkLog log) =>
      _enqueue(() => _repository.addWorkLog(log));
  @override
  Future<void> updateWorkLog(WorkLog log) =>
      _enqueue(() => _repository.updateWorkLog(log));
  @override
  Future<void> deleteWorkLog(String id) =>
      _enqueue(() => _repository.deleteWorkLog(id));
  void stopAccepting() {
    _accepting = false;
    _streams.stopAccepting();
  }

  Future<void> dispose() => _closing ??= _dispose();
  Future<void> _dispose() async {
    stopAccepting();
    final closingStreams = _streams.close();
    await Future.wait([_operations, closingStreams]);
  }
}
