import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  late AppDatabase db;
  late TasksRepository tasks;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    tasks = TasksRepository(TasksDao(db));
  });
  tearDown(() => db.close());
  test('loading and assigning a task preserves all tags', () async {
    final task = Task.blank().copyWith(
      tags: [const Tag(id: 1, name: 'important', colorHex: 0xFF9E9E9E)],
    );
    await tasks.addTask(task);
    final loaded = (await tasks.getById(task.id))!;
    expect(loaded.tags.single.name, 'important');
    await tasks.updateTask(
      loaded.copyWith(projectId: const Wrapped('project')),
    );
    expect((await tasks.getAllTasks()).single.tags.single.name, 'important');
  });
  test(
    'upsert preserves work logs and deletion cascades logs and tags',
    () async {
      final task = Task.blank().copyWith(
        tags: [
          const Tag(id: 1, name: 'tag', colorHex: 0),
          const Tag(id: 1, name: 'tag', colorHex: 0),
        ],
      );
      await tasks.addTask(task);
      await db
          .into(db.workLogs)
          .insert(
            WorkLogsCompanion.insert(
              id: 'log',
              status: 0,
              taskId: task.id,
              date: DateTime(2026, 10, 31),
              description: 'work',
            ),
          );
      await tasks.addTask(task.copyWith(title: 'Updated'));
      expect(await db.select(db.workLogs).get(), hasLength(1));
      expect(await db.select(db.taskTagEntries).get(), hasLength(1));
      await tasks.deleteTask(task.id);
      expect(await db.select(db.workLogs).get(), isEmpty);
      expect(await db.select(db.taskTagEntries).get(), isEmpty);
    },
  );
  test('foreign keys reject new orphan work logs', () async {
    await expectLater(
      db
          .into(db.workLogs)
          .insert(
            WorkLogsCompanion.insert(
              id: 'orphan',
              status: 0,
              taskId: 'missing',
              date: DateTime(2026, 10, 31),
              description: 'invalid',
            ),
          ),
      throwsA(anything),
    );
  });
}
