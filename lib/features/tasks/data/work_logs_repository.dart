import 'package:tasks_api/tasks_api.dart' show WorkLogsApi;
import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/extensions/work_log_model_extension.dart';
import 'package:life_os/features/tasks/domain/work_log_model.dart';

class WorkLogsRepository implements WorkLogsApi {
  WorkLogsRepository(this._workLogsDao);

  final WorkLogsDao _workLogsDao;

  @override
  Future<List<WorkLog>> getWorkLogsForTask(String taskId) async {
    final models = await _workLogsDao.getWorkLogsForTask(taskId);
    return models.map((m) => m.toDomain()).toList();
  }

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
    final models = await _workLogsDao.getPageForTask(
      taskId,
      limit: limit,
      offset: offset,
      from: from,
      until: until,
      status: status,
      search: search,
    );
    return models.map((m) => m.toDomain()).toList();
  }

  @override
  Future<WorkLog?> getById(String id) async =>
      (await _workLogsDao.getById(id))?.toDomain();

  @override
  Stream<List<WorkLog>> watchWorkLogsForTask(String taskId) {
    return _workLogsDao
        .watchWorkLogsForTask(taskId)
        .map((models) => models.map((m) => m.toDomain()).toList());
  }

  @override
  Future<void> addWorkLog(WorkLog workLog) async {
    await _workLogsDao.insertWorkLog(workLog.toCompanion());
  }

  @override
  Future<void> updateWorkLog(WorkLog workLog) async {
    await _workLogsDao.updateWorkLog(
      WorkLogsCompanion(
        id: Value(workLog.id),
        status: Value(workLog.status),
        taskId: Value(workLog.taskId),
        date: Value(workLog.date),
        description: Value(workLog.description),
      ),
    );
  }

  @override
  Future<void> deleteWorkLog(String id) async {
    await _workLogsDao.deleteWorkLog(id);
  }
}
