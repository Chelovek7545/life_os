import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart' show WorkLogsApi;
import 'package:life_os/features/tasks/domain/work_log_model.dart';

class WorkLogsViewModel extends ChangeNotifier {
  WorkLogsViewModel(this._repository, this.taskId) {
    _load();
  }

  final WorkLogsApi _repository;
  final String taskId;

  List<WorkLog> _workLogs = [];
  List<WorkLog> get workLogs => _workLogs;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _load() {
    _isLoading = true;
    notifyListeners();

    _repository.watchWorkLogsForTask(taskId).listen((logs) {
      _workLogs = logs;
      _isLoading = false;
      notifyListeners();
    }, onError: (_) {
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> addWorkLog({required String description, int status = 0, DateTime? date}) async {
    final log = WorkLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(), // or uuid
      status: status,
      taskId: taskId,
      date: date ?? DateTime.now(),
      description: description,
    );
    await _repository.addWorkLog(log);
  }

  Future<void> updateWorkLog(WorkLog log) async {
    await _repository.updateWorkLog(log);
  }

  Future<void> deleteWorkLog(String id) async {
    await _repository.deleteWorkLog(id);
  }
}
