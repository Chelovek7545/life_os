import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  Future<void> removeSyncProjection(AppDatabase db) async {
    for (final event in ['insert', 'update', 'delete']) {
      await db.customStatement('DROP TRIGGER sync_entity_heads_after_$event');
    }
    await db.customStatement('DROP TABLE sync_entity_heads');
  }

  Future<void> removeSyncSchema(AppDatabase db) async {
    await removeSyncProjection(db);
    await db.customStatement('DROP INDEX tags_sync_id_unique');
    await db.customStatement('ALTER TABLE tags DROP COLUMN sync_id');
    for (final name in ['sync_cursors', 'sync_revisions', 'sync_identities']) {
      await db.customStatement('DROP TABLE $name');
    }
  }

  late Directory directory;
  late File file;
  test(
    'v12 builds the projection lazily without rewriting the journal',
    () async {
      final old = AppDatabase(NativeDatabase(file));
      final task = Task.blank();
      final journal = DriftSyncStore(old);
      await journal.initialize('dataset');
      await journal.saveTask(task, expectedHeads: {});
      final original = await old.select(old.syncRevisions).getSingle();
      await removeSyncProjection(old);
      await old.customStatement('PRAGMA user_version = 12');
      await old.close();

      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final store = DriftSyncStore(upgraded);
        final dao = TasksDao(upgraded, journal: store);
        expect(await upgraded.select(upgraded.syncEntityHeads).get(), isEmpty);
        await dao.setTaskStatus(task.id, TaskStatus.done);
        final revisions = await upgraded.select(upgraded.syncRevisions).get();
        expect(revisions, hasLength(2));
        expect(revisions.first, original);
        final result = (await dao.getTaskWithTags(task.id))!;
        expect(result.status, TaskStatus.done);
        expect(result.storageRevision, revisions.last.revisionId);
      } finally {
        await upgraded.close();
      }
    },
  );
  test(
    'v11 migration adds portable tag IDs without rewriting immutable revisions',
    () async {
      final old = AppDatabase(NativeDatabase(file));
      final store = DriftSyncStore(old);
      await store.initialize('dataset');
      final task = Task.blank();
      await store.saveTask(task, expectedHeads: {});
      final body = (await old.select(old.syncRevisions).getSingle()).body;
      await old
          .into(old.tags)
          .insert(
            TagsCompanion.insert(
              id: const Value(42),
              name: 'Legacy',
              colorHex: 123,
            ),
          );
      await old.customStatement('DROP INDEX tags_sync_id_unique');
      await old.customStatement('ALTER TABLE tags DROP COLUMN sync_id');
      await removeSyncProjection(old);
      await old.customStatement('PRAGMA user_version = 11');
      await old.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final legacy = await upgraded.select(upgraded.tags).getSingle();
        expect(legacy.id, 42);
        expect(legacy.syncId, isNull);
        await DriftSyncStore(upgraded).initialize('dataset');
        final tag = await upgraded.select(upgraded.tags).getSingle();
        expect(tag.id, 42);
        expect(tag.name, 'Legacy');
        expect(tag.colorHex, 123);
        expect(tag.syncId, isNotNull);
        final revisions = await upgraded.select(upgraded.syncRevisions).get();
        expect(revisions.first.body, body);
        expect(revisions, hasLength(2));
        expect(
          (await upgraded.select(upgraded.tasks).getSingle()).updatedAt,
          task.updatedAt,
        );
      } finally {
        await upgraded.close();
      }
    },
  );
  test(
    'v10 upgrade preserves tasks and explicitly bootstraps stable revisions',
    () async {
      final old = AppDatabase(NativeDatabase(file));
      final date = DateTime(2026, 10, 1);
      await old
          .into(old.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'legacy',
              title: 'Existing',
              description: 'Keep',
              status: TaskStatus.open,
              createdAt: date,
              updatedAt: date,
            ),
          );
      await removeSyncSchema(old);
      await old.customStatement('PRAGMA user_version = 10');
      await old.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        expect(
          (await upgraded.select(upgraded.tasks).getSingle()).updatedAt,
          date,
        );
        expect(await upgraded.select(upgraded.syncRevisions).get(), isEmpty);
        final store = DriftSyncStore(upgraded);
        await store.initialize('dataset');
        final first = (await store.readFeed()).entries.single.revision;
        await store.initialize('dataset');
        expect((await store.readFeed()).entries.single.revision.id, first.id);
        expect(first.entityId, 'legacy');
        expect(
          (await upgraded.select(upgraded.tasks).getSingle()).updatedAt,
          date,
        );
        expect(
          await upgraded.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await upgraded.close();
      }
    },
  );
  test(
    'upgrading v9 preserves legacy work logs and supports optional intervals',
    () async {
      final previous = AppDatabase(NativeDatabase(file));
      final now = DateTime(2026, 11, 8);
      await previous
          .into(previous.tasks)
          .insert(
            TasksCompanion.insert(
              id: 'task',
              title: 'Preserve',
              description: '',
              status: TaskStatus.open,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await previous
          .into(previous.workLogs)
          .insert(
            WorkLogsCompanion.insert(
              id: 'old-log',
              taskId: 'task',
              status: 1,
              date: now,
              description: 'Legacy description',
            ),
          );
      await previous.customStatement(
        'ALTER TABLE work_logs DROP COLUMN started_at',
      );
      await previous.customStatement(
        'ALTER TABLE work_logs DROP COLUMN ended_at',
      );
      await removeSyncSchema(previous);
      await previous.customStatement('PRAGMA user_version = 9');
      await previous.close();
      final upgraded = AppDatabase(NativeDatabase(file));
      try {
        final log = await upgraded.select(upgraded.workLogs).getSingle();
        expect(log.description, 'Legacy description');
        expect(log.status, 1);
        expect(log.startedAt, isNull);
        expect(log.endedAt, isNull);
        await upgraded
            .into(upgraded.workLogs)
            .insert(
              WorkLogsCompanion.insert(
                id: 'timed',
                taskId: 'task',
                status: 1,
                date: now,
                description: 'Timed',
                startedAt: Value(now.copyWith(hour: 14, minute: 10)),
                endedAt: Value(now.copyWith(hour: 15, minute: 30)),
              ),
            );
        final timed = await (upgraded.select(
          upgraded.workLogs,
        )..where((row) => row.id.equals('timed'))).getSingle();
        expect(
          timed.endedAt!.difference(timed.startedAt!),
          const Duration(minutes: 80),
        );
      } finally {
        await upgraded.close();
      }
    },
  );

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
    await removeSyncSchema(previous);
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
