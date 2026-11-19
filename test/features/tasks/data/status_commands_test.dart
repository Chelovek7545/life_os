import 'dart:async';
import 'package:core_contracts/core_contracts.dart' show StorageException;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  for (final enrolled in [false, true]) {
    group('narrow status commands (sync=$enrolled)', () {
      late AppDatabase db;
      late DriftSyncStore journal;
      late TasksRepository tasks;
      late WorkLogsRepository logs;
      late Task task;
      late WorkLog log;

      setUp(() async {
        db = AppDatabase(NativeDatabase.memory());
        journal = DriftSyncStore(db);
        tasks = TasksRepository(TasksDao(db, journal: journal));
        logs = WorkLogsRepository(WorkLogsDao(db, journal: journal));
        if (enrolled) await journal.initialize('status-test');
        task = Task.blank().copyWith(
          title: 'Current title',
          description: 'Keep description',
          startsAt: Wrapped(DateTime(2026, 11, 17, 9)),
          timerSeconds: 123,
          priority: 2,
          tags: [const Tag(id: 0, name: 'Keep', colorHex: 123)],
        );
        await tasks.addTask(task);
        log = WorkLog.blank(task.id).copyWith(
          description: 'Current log',
          startedAt: Wrapped(DateTime(2026, 11, 17, 9)),
          endedAt: Wrapped(DateTime(2026, 11, 17, 10)),
        );
        await logs.addWorkLog(log);
      });
      tearDown(() => db.close());

      test(
        'preserve every other column, tags and publish committed states',
        () async {
          final beforeTask = (await db.select(db.tasks).getSingle()).toJson();
          final beforeLog = (await db.select(db.workLogs).getSingle()).toJson();
          final tag = await db.select(db.tags).getSingle();
          final link = await db.select(db.taskTagEntries).getSingle();
          for (final table in ['tags', 'task_tag_entries']) {
            for (final operation in ['INSERT', 'UPDATE', 'DELETE']) {
              await db.customStatement(
                'CREATE TRIGGER reject_${table}_$operation BEFORE $operation ON $table '
                "BEGIN SELECT RAISE(ABORT, 'Status must not touch tags'); END",
              );
            }
          }
          final taskStates = StreamIterator(tasks.watchTasks());
          final logStates = StreamIterator(logs.watchWorkLogsForTask(task.id));
          addTearDown(taskStates.cancel);
          addTearDown(logStates.cancel);
          await taskStates.moveNext();
          await logStates.moveNext();
          final nextTask = taskStates.moveNext();
          await tasks.setTaskStatus(task.id, TaskStatus.done);
          expect(await nextTask, isTrue);
          expect(taskStates.current.single.status, TaskStatus.done);
          final nextLog = logStates.moveNext();
          await logs.setWorkLogStatus(log.id, 1);
          expect(await nextLog, isTrue);
          expect(logStates.current.single.status, 1);
          final afterTask = (await db.select(db.tasks).getSingle()).toJson();
          final afterLog = (await db.select(db.workLogs).getSingle()).toJson();
          for (final field in ['status', 'updatedAt']) {
            beforeTask.remove(field);
            afterTask.remove(field);
          }
          beforeLog.remove('status');
          afterLog.remove('status');
          expect(afterTask, beforeTask);
          expect(afterLog, beforeLog);
          expect(await db.select(db.tags).getSingle(), tag);
          expect(await db.select(db.taskTagEntries).getSingle(), link);
          await tasks.setTaskStatus(task.id, TaskStatus.inProgress);
          await logs.setWorkLogStatus(log.id, 0);
          expect((await tasks.getById(task.id))!.status, TaskStatus.inProgress);
          expect((await logs.getById(log.id))!.status, 0);
          if (enrolled) {
            expect(
              (await journal.heads(task.id)).single.payload,
              TaskSyncCodec.encode((await tasks.getById(task.id))!),
            );
            expect(
              (await journal.heads('workLog/${log.id}')).single.payload,
              WorkLogSyncCodec.encode((await logs.getById(log.id))!),
            );
          }
        },
      );

      test(
        'same status and missing IDs do not write or create revisions',
        () async {
          final before = await tasks.getById(task.id);
          final revisions = await db.select(db.syncRevisions).get();
          await tasks.setTaskStatus(task.id, task.status);
          await logs.setWorkLogStatus(log.id, log.status);
          await tasks.setTaskStatus('missing', TaskStatus.done);
          await logs.setWorkLogStatus('missing', 1);
          expect((await tasks.getById(task.id))!.updatedAt, before!.updatedAt);
          expect(await db.select(db.tasks).get(), hasLength(1));
          expect(await db.select(db.workLogs).get(), hasLength(1));
          expect(await db.select(db.syncRevisions).get(), revisions);
        },
      );

      if (enrolled) {
        test('status writes update only the corresponding indexed head', () async {
          final peerDb = AppDatabase(NativeDatabase.memory());
          addTearDown(peerDb.close);
          final peer = DriftSyncStore(peerDb);
          await peer.initialize('status-test');
          final original = await journal.readFeed();
          await peer.receive(original);
          await db.customStatement(
            'CREATE TRIGGER reject_index_rebuild BEFORE DELETE ON sync_entity_heads '
            "WHEN OLD.entity_key <> '' BEGIN SELECT RAISE(ABORT, 'Index rebuild'); END",
          );
          final oldTask = (await tasks.getById(task.id))!;
          await tasks.setTaskStatus(task.id, TaskStatus.done);
          await logs.setWorkLogStatus(log.id, 1);
          final feed = await journal.readFeed(after: original.cursor);
          expect(feed.entries, hasLength(2));
          expect(feed.entries.first.revision.parents, [
            oldTask.storageRevision,
          ]);
          await peer.receive(feed);
          await peer.receive(feed);
          expect(await peerDb.select(peerDb.syncRevisions).get(), hasLength(5));
          final remoteTasks = TasksRepository(TasksDao(peerDb, journal: peer));
          final remote = (await remoteTasks.getById(task.id))!;
          expect(remote.status, TaskStatus.done);
          expect(remote.tags.single.name, 'Keep');
          expect(remote.storageRevision, feed.entries.first.revision.id);
          expect((await peerDb.select(peerDb.workLogs).getSingle()).status, 1);
          await expectLater(
            tasks.updateTask(oldTask.copyWith(title: 'Stale')),
            throwsA(isA<StorageException>()),
          );
        });

        test(
          'pending blocks its entity and unrelated statuses preserve it',
          () async {
            final incoming = SyncRevision(
              id: 'pending-log',
              deviceId: 'peer',
              entityId: log.id,
              entityType: 'workLog',
              schemaVersion: 2,
              parents: ['not-arrived'],
              payload: WorkLogSyncCodec.encode(log.copyWith(status: 1)),
            );
            await journal.receive(
              SyncBatch(const SyncIdentity('status-test', 'peer'), 0, [
                SyncEntry(1, incoming),
              ]),
            );
            await expectLater(
              logs.setWorkLogStatus(log.id, 1),
              throwsStateError,
            );
            await tasks.setTaskStatus(task.id, TaskStatus.done);
            expect((await journal.readPending()).single.id, incoming.id);
            expect((await tasks.getById(task.id))!.isCompleted, isTrue);
            expect((await logs.getById(log.id))!.status, log.status);
          },
        );

        test('failed index update rolls back status and revision', () async {
          final current = (await tasks.getById(task.id))!;
          final before = await db.select(db.syncRevisions).get();
          await db.customStatement(
            'CREATE TRIGGER reject_index_update BEFORE UPDATE ON sync_entity_heads '
            "BEGIN SELECT RAISE(ABORT, 'Index write failed'); END",
          );
          await expectLater(
            tasks.setTaskStatus(task.id, TaskStatus.done),
            throwsA(isA<StorageException>()),
          );
          final after = (await tasks.getById(task.id))!;
          expect(after.status, current.status);
          expect(after.storageRevision, current.storageRevision);
          expect(await db.select(db.syncRevisions).get(), before);
        });

        test('journal failure rolls back both status commands', () async {
          final revisions = await db.select(db.syncRevisions).get();
          await db.customStatement(
            'CREATE TRIGGER reject_revision BEFORE INSERT ON sync_revisions '
            "BEGIN SELECT RAISE(ABORT, 'Disk failure'); END",
          );
          await expectLater(
            tasks.setTaskStatus(task.id, TaskStatus.done),
            throwsA(isA<StorageException>()),
          );
          await expectLater(
            logs.setWorkLogStatus(log.id, 1),
            throwsA(anything),
          );
          expect((await tasks.getById(task.id))!.status, task.status);
          expect((await logs.getById(log.id))!.status, log.status);
          expect(await db.select(db.syncRevisions).get(), revisions);
        });

        test('work log conflicts reject narrow status changes', () async {
          final key = 'workLog/${log.id}';
          final parent = (await journal.heads(key)).single.id;
          await logs.setWorkLogStatus(log.id, 1);
          await journal.receive(
            SyncBatch(const SyncIdentity('status-test', 'peer'), 0, [
              SyncEntry(
                1,
                SyncRevision(
                  id: 'remote-log',
                  deviceId: 'peer',
                  entityId: log.id,
                  entityType: 'workLog',
                  schemaVersion: 2,
                  parents: [parent],
                  payload: WorkLogSyncCodec.encode(
                    log.copyWith(description: 'Remote'),
                  ),
                ),
              ),
            ]),
          );
          final before = (await db.select(db.workLogs).getSingle()).status;
          await expectLater(logs.setWorkLogStatus(log.id, 0), throwsStateError);
          expect((await db.select(db.workLogs).getSingle()).status, before);
          expect((await journal.readConflicts())[key], hasLength(2));
        });
      }
    });
  }
}
