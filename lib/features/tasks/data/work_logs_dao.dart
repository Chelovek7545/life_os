import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';

part 'work_logs_dao.g.dart';

class WorkLogsDaoAccessor {
  // Can be used if needed
}

@DriftAccessor(tables: [WorkLogs, Tasks])
class WorkLogsDao extends DatabaseAccessor<AppDatabase>
    with _$WorkLogsDaoMixin {
  WorkLogsDao(AppDatabase db) : super(db);

  Future<List<WorkLogModel>> getWorkLogsForTask(String taskId) {
    return (select(workLogs)..where((tbl) => tbl.taskId.equals(taskId))).get();
  }

  Future<List<WorkLogModel>> getPageForTask(
    String taskId, {
    required int limit,
    required int offset,
    DateTime? from,
    DateTime? until,
    int? status,
    String? search,
  }) {
    return (select(workLogs)
          ..where((tbl) {
            Expression<bool> condition = tbl.taskId.equals(taskId);
            if (from != null)
              condition = condition & tbl.date.isBiggerOrEqualValue(from);
            if (until != null)
              condition = condition & tbl.date.isSmallerThanValue(until);
            if (status != null)
              condition = condition & tbl.status.equals(status);
            if (search != null) {
              final capitalized =
                  '${search[0].toUpperCase()}${search.substring(1)}';
              condition =
                  condition &
                  (tbl.description.like('%$search%') |
                      tbl.description.like('%$capitalized%') |
                      tbl.description.like('%${search.toUpperCase()}%'));
            }
            return condition;
          })
          ..orderBy([
            (tbl) =>
                OrderingTerm(expression: tbl.date, mode: OrderingMode.desc),
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<WorkLogModel?> getById(String id) =>
      (select(workLogs)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();

  Stream<List<WorkLogModel>> watchWorkLogsForTask(String taskId) {
    return (select(
      workLogs,
    )..where((tbl) => tbl.taskId.equals(taskId))).watch();
  }

  Future<int> insertWorkLog(WorkLogsCompanion entry) {
    return into(workLogs).insert(entry);
  }

  Future<bool> updateWorkLog(WorkLogsCompanion entry) {
    return update(workLogs).replace(entry);
  }

  Future<int> deleteWorkLog(String id) {
    return (delete(workLogs)..where((tbl) => tbl.id.equals(id))).go();
  }
}
