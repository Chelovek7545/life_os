import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'task_mutation_journal.dart';

part 'work_logs_dao.g.dart';

class WorkLogsDaoAccessor {
  // Can be used if needed
}

@DriftAccessor(tables: [WorkLogs, Tasks])
class WorkLogsDao extends DatabaseAccessor<AppDatabase>
    with _$WorkLogsDaoMixin {
  WorkLogsDao(AppDatabase db, {this.journal}) : super(db);
  final TaskMutationJournal? journal;

  Future<T> _track<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) =>
      journal?.trackWorkLog(
        id,
        write,
        expectedRevision: expectedRevision,
        requireExpected: requireExpected,
        createOnly: createOnly,
      ) ??
      transaction(write);

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
    return _track(
      entry.id.value,
      () => into(workLogs).insert(entry),
      createOnly: true,
    );
  }

  Future<bool> updateWorkLog(
    WorkLogsCompanion entry, {
    String? expectedRevision,
  }) {
    return transaction(() async {
      final previous = await getById(entry.id.value);
      if (previous == null) return false;
      return _track(
        entry.id.value,
        () => update(workLogs).replace(entry),
        expectedRevision: expectedRevision,
        requireExpected: true,
      );
    });
  }

  Future<int> deleteWorkLog(String id) {
    return transaction(() async {
      final previous = await getById(id);
      if (previous == null) return 0;
      return _track(
        id,
        () => (delete(workLogs)..where((tbl) => tbl.id.equals(id))).go(),
      );
    });
  }
}
