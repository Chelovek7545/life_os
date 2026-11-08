import 'package:flutter/material.dart';
import 'dart:async';
import 'package:tasks_api/tasks_api.dart';
import 'package:uuid/uuid.dart';

class WorkLogsViewModel extends ChangeNotifier {
  WorkLogsViewModel(this._repository, this.taskId) {
    _load();
  }

  final WorkLogsApi _repository;
  final String taskId;

  List<WorkLog> _workLogs = const [];
  StreamSubscription<List<WorkLog>>? _subscription;
  bool _disposed = false;
  List<WorkLog> get workLogs => _workLogs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _load() {
    _isLoading = true;
    notifyListeners();

    _subscription = _repository
        .watchWorkLogsForTask(taskId)
        .listen(
          (logs) {
            if (_disposed) return;
            _workLogs = List.unmodifiable(logs);
            _isLoading = false;
            notifyListeners();
          },
          onError: (_) {
            if (_disposed) return;
            _isLoading = false;
            notifyListeners();
          },
        );
  }

  Future<void> addWorkLog({
    required String description,
    int status = 0,
    DateTime? date,
    DateTime? startedAt,
    DateTime? endedAt,
  }) async {
    if (_disposed) throw StateError('Work logs model is closed.');
    final log = WorkLog(
      id: const Uuid().v4(),
      status: status,
      taskId: taskId,
      date: date ?? DateTime.now(),
      description: description,
      startedAt: startedAt,
      endedAt: endedAt,
    );
    await _repository.addWorkLog(log);
  }

  Future<void> updateWorkLog(WorkLog log) async {
    if (_disposed) throw StateError('Work logs model is closed.');
    await _repository.updateWorkLog(log);
  }

  Future<void> deleteWorkLog(String id) async {
    if (_disposed) throw StateError('Work logs model is closed.');
    await _repository.deleteWorkLog(id);
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(
      _subscription?.cancel().catchError((Object _) {}) ?? Future<void>.value(),
    );
    super.dispose();
  }
}
