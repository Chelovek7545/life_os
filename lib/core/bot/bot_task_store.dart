import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

class BotTaskFilter {
  const BotTaskFilter({
    this.from,
    this.until,
    this.overdue = false,
    this.status,
    this.project,
    this.priority,
    this.search,
  });
  final DateTime? from;
  final DateTime? until;
  final bool overdue;
  final TaskStatus? status;
  final String? project;
  final int? priority;
  final String? search;
}

class BotTaskRow {
  const BotTaskRow(this.task, this.project);
  final TaskModel task;
  final String? project;
}

/// One bounded SQL query combines all selected filters.
class BotTaskStore {
  const BotTaskStore(this.db);
  final AppDatabase db;

  Future<List<BotTaskRow>> find(
    BotTaskFilter filter, {
    int page = 0,
    int pageSize = 10,
  }) async {
    final t = db.tasks;
    final p = db.projects;
    final query = db.select(t).join([
      leftOuterJoin(p, p.id.equalsExp(t.projectId)),
    ]);
    Expression<bool> condition = const Constant(true);
    if (filter.from != null) {
      condition = condition & t.startsAt.isBiggerOrEqualValue(filter.from!);
    }
    if (filter.until != null) {
      condition = condition & t.startsAt.isSmallerThanValue(filter.until!);
    }
    if (filter.overdue) {
      condition =
          condition &
          t.dueDate.isSmallerThanValue(
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ),
          ) &
          t.status.equals(TaskStatus.done.index).not() &
          t.dueDate.isNotNull();
    }
    if (filter.status != null) {
      condition = condition & t.status.equals(filter.status!.index);
    }
    if (filter.project != null) {
      condition = condition & p.name.equals(filter.project!);
    }
    if (filter.priority != null) {
      condition = condition & t.priority.equals(filter.priority!);
    }
    if (filter.search != null) {
      final value = filter.search!;
      final capitalized = '${value[0].toUpperCase()}${value.substring(1)}';
      final upper = value.toUpperCase();
      condition =
          condition &
          (t.title.like('%$value%') |
              t.description.like('%$value%') |
              t.title.like('%$capitalized%') |
              t.description.like('%$capitalized%') |
              t.title.like('%$upper%') |
              t.description.like('%$upper%'));
    }
    query.where(condition);
    query.orderBy([
      OrderingTerm(expression: t.startsAt.isNull()),
      OrderingTerm(expression: t.startsAt),
      OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
    ]);
    query.limit(pageSize + 1, offset: page * pageSize);
    return (await query.get())
        .map(
          (row) => BotTaskRow(row.readTable(t), row.readTableOrNull(p)?.name),
        )
        .toList();
  }

  Future<List<ProjectModel>> findProjects(String name) =>
      (db.select(db.projects)
            ..where((p) => p.name.equals(name))
            ..limit(2))
          .get();

  Future<TaskModel?> getTask(String id) =>
      (db.select(db.tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<String?> getProjectName(String id) async => (await (db.select(
    db.projects,
  )..where((p) => p.id.equals(id))).getSingleOrNull())?.name;
}
