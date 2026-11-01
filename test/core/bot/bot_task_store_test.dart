import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:telegram_plugin/telegram_plugin.dart' show BotTaskFilter;
import 'package:life_os/features/tasks/data/telegram_task_queries.dart';
import 'package:life_os/core/database/database.dart';
import 'package:tasks_api/tasks_api.dart' show TaskStatus;

void main() {
  late AppDatabase db;
  late BotTaskStore store;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    store = BotTaskStore(db);
  });
  tearDown(() => db.close());

  test('combines filters and advances pages without skipping a task', () async {
    final now = DateTime.now();
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'id-$i',
              title: 'Анатомия $i',
              description: '',
              status: TaskStatus.notStarted,
              createdAt: now.add(Duration(minutes: i)),
              updatedAt: now,
              dueDate: Value(DateTime(now.year, now.month, now.day)),
            ),
          );
    }
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'other',
            title: 'Иное',
            description: '',
            status: TaskStatus.done,
            createdAt: now,
            updatedAt: now,
          ),
        );
    final filter = BotTaskFilter(
      status: TaskStatus.notStarted,
      search: 'анатомия',
    );
    final first = await store.find(filter, pageSize: 2);
    final second = await store.find(filter, page: 1, pageSize: 2);
    expect(first.length, 3); // Two shown plus look-ahead row.
    expect(second.length, 1);
    expect(
      first
          .take(2)
          .map((row) => row.task.id)
          .toSet()
          .intersection(second.map((row) => row.task.id).toSet()),
      isEmpty,
    );
  });

  test('day filters use planned date, while overdue uses deadline', () async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Future<void> add(String id, {DateTime? planned, DateTime? deadline}) => db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: id,
            title: id,
            description: '',
            status: TaskStatus.notStarted,
            createdAt: now,
            updatedAt: now,
            startsAt: Value(planned),
            dueDate: Value(deadline),
          ),
        )
        .then((_) {});

    await add(
      'planned-today',
      planned: today,
      deadline: today.add(const Duration(days: 1)),
    );
    await add(
      'planned-tomorrow',
      planned: today.add(const Duration(days: 1)),
      deadline: today,
    );
    await add('only-deadline', deadline: today);
    await add(
      'overdue',
      planned: today.add(const Duration(days: 1)),
      deadline: today.subtract(const Duration(days: 1)),
    );

    final todayRows = await store.find(
      BotTaskFilter(from: today, until: today.add(const Duration(days: 1))),
    );
    expect(todayRows.map((row) => row.task.id), ['planned-today']);

    final allRows = await store.find(const BotTaskFilter());
    expect(allRows.first.task.id, 'planned-today');
    expect(allRows.last.task.id, 'only-deadline');

    final overdueRows = await store.find(const BotTaskFilter(overdue: true));
    expect(overdueRows.map((row) => row.task.id), ['overdue']);
  });

  test('worklog filters combine within one bounded query', () async {
    final now = DateTime(2026, 10, 30, 12);
    await db
        .into(db.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'task-1',
            title: 'Задача',
            description: '',
            status: TaskStatus.open,
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.workLogs)
          .insert(
            WorkLogsCompanion.insert(
              id: 'log-$i',
              taskId: 'task-1',
              status: i == 2 ? 1 : 0,
              date: now.add(Duration(days: i)),
              description: i == 1 ? 'Анатомия' : 'Другое',
            ),
          );
    }
    final rows = await WorkLogsDao(db).getPageForTask(
      'task-1',
      limit: 10,
      offset: 0,
      from: DateTime(2026, 10, 31),
      until: DateTime(2026, 11, 1),
      status: 0,
      search: 'анатомия',
    );
    expect(rows.map((row) => row.id), ['log-1']);
  });
}
