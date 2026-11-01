import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  late Directory directory;
  late File file;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('life_os_migration_');
    file = File(directory.path + Platform.pathSeparator + 'test.sqlite');
  });
  tearDown(() async {
    if (await file.exists()) await file.delete();
    await directory.delete();
  });
  test('upgrading v8 preserves tasks and enables work log cascades', () async {
    final previous = AppDatabase(NativeDatabase(file));
    final now = DateTime(2026, 10, 31);
    await previous
        .into(previous.tasks)
        .insert(
          TasksCompanion.insert(
            id: 'preserved',
            title: 'Existing task',
            description: '',
            status: TaskStatus.inProgress,
            createdAt: now,
            updatedAt: now,
          ),
        );
    // v8 has the same tables as v9 except for the newly introduced work_logs.
    await previous.customStatement('DROP TABLE work_logs');
    await previous.customStatement('PRAGMA user_version = 8');
    await previous.close();
    final upgraded = AppDatabase(NativeDatabase(file));
    try {
      final task = await upgraded.select(upgraded.tasks).getSingle();
      expect(task.id, 'preserved');
      expect(task.status, TaskStatus.inProgress);
      await upgraded
          .into(upgraded.workLogs)
          .insert(
            WorkLogsCompanion.insert(
              id: 'log',
              status: 0,
              taskId: task.id,
              date: now,
              description: 'new log',
            ),
          );
      await upgraded.delete(upgraded.tasks).go();
      expect(await upgraded.select(upgraded.workLogs).get(), isEmpty);
      expect(
        await upgraded.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    } finally {
      await upgraded.close();
    }
  });
  test(
    'opening v9 preserves legacy orphan data and rejects new invalid rows',
    () async {
      final previous = AppDatabase(NativeDatabase(file));
      await previous.customSelect('SELECT 1').get();
      await previous.customStatement('PRAGMA foreign_keys = OFF');
      await previous
          .into(previous.workLogs)
          .insert(
            WorkLogsCompanion.insert(
              id: 'legacy-log',
              status: 0,
              taskId: 'missing',
              date: DateTime(2026, 10, 31),
              description: 'legacy data',
            ),
          );
      await previous.close();
      final reopened = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await reopened.select(reopened.workLogs).get()).single.description,
          'legacy data',
        );
        expect(
          await reopened.customSelect('PRAGMA foreign_key_check').get(),
          hasLength(1),
        );
        await expectLater(
          reopened
              .into(reopened.workLogs)
              .insert(
                WorkLogsCompanion.insert(
                  id: 'new-log',
                  status: 0,
                  taskId: 'missing',
                  date: DateTime(2026, 10, 31),
                  description: 'must be rejected',
                ),
              ),
          throwsA(anything),
        );
      } finally {
        await reopened.close();
      }
    },
  );
}
