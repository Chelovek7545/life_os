import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/lifegraph/data/drift_graph_deletion.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  late AppDatabase aDb, bDb;
  late DriftSyncStore a, b;
  late TasksRepository tasks;
  late WorkLogsRepository logs;
  Future<Task> add(String title, {String? parent}) async {
    final task = Task.blank().copyWith(
      title: title,
      parentTaskId: Wrapped(parent),
    );
    await tasks.addTask(task);
    return (await tasks.getById(task.id))!;
  }

  final engine = SyncEngine();
  test(
    'bootstrap preserves existing hierarchy and work logs without rewriting business dates',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final inactive = DriftSyncStore(db);
      final repo = TasksRepository(TasksDao(db, journal: inactive));
      final logRepo = WorkLogsRepository(WorkLogsDao(db, journal: inactive));
      final root = Task.blank();
      final child = Task.blank().copyWith(parentTaskId: Wrapped(root.id));
      await repo.addTask(root);
      await repo.addTask(child);
      final log = WorkLog.blank(child.id);
      await logRepo.addWorkLog(log);
      await inactive.initialize('dataset');
      final identity = await inactive.identity();
      await inactive.initialize('dataset');
      expect((await inactive.identity()).deviceId, identity.deviceId);
      expect((await inactive.readFeed()).entries, hasLength(3));
      await engine.exchange(inactive, b);
      final remote = TasksRepository(TasksDao(bDb, journal: b));
      expect((await remote.getById(child.id))!.parentTaskId, root.id);
      expect((await remote.getById(root.id))!.updatedAt, root.updatedAt);
      expect((await bDb.select(bDb.workLogs).get()).single.id, log.id);
    },
  );
  test(
    'untracked project graph mutation rolls back the whole command',
    () async {
      final now = DateTime(2026);
      await aDb
          .into(aDb.projects)
          .insert(
            ProjectsCompanion.insert(
              id: 'project',
              name: 'Keep',
              description: '',
              color: '#ffffff',
              createdAt: now,
              updatedAt: now,
            ),
          );
      await expectLater(
        DriftGraphDeletion(
          aDb,
          journal: a,
        ).delete(GraphNodeType.project, 'project', keepChildren: false),
        throwsStateError,
      );
      expect((await aDb.select(aDb.projects).get()).single.name, 'Keep');
      await expectLater(a.readFeed(), throwsStateError);
      expect(await aDb.select(aDb.syncRevisions).get(), isEmpty);
    },
  );
  test(
    'a work log created offline against a deleted task is retained as pending',
    () async {
      final task = await add('Task');
      await engine.exchange(a, b);
      final otherLogs = WorkLogsRepository(WorkLogsDao(bDb, journal: b));
      final log = WorkLog.blank(task.id).copyWith(description: 'Offline time');
      await otherLogs.addWorkLog(log);
      await tasks.deleteTask(task.id);
      await engine.exchange(a, b);
      expect(await aDb.select(aDb.tasks).get(), isEmpty);
      expect(await bDb.select(bDb.workLogs).get(), isEmpty);
      final pending = await a.readPending();
      expect(pending, hasLength(1));
      expect(
        WorkLogSyncCodec.decode(pending.single.payload!).description,
        'Offline time',
      );
      expect((await b.readPending()).single.id, pending.single.id);
    },
  );
  test(
    'groups larger than a feed page never expose a partial projection',
    () async {
      await a.trackGraph(() async {
        for (var i = 0; i < 105; i++) {
          await tasks.addTask(Task.blank().copyWith(title: 'Task $i'));
        }
      });
      final page = await a.readFeed();
      expect(page.entries, hasLength(100));
      await b.receive(page);
      expect(await bDb.select(bDb.tasks).get(), isEmpty);
      expect((await b.readPending()), hasLength(100));
      await engine.exchange(a, b);
      expect(await bDb.select(bDb.tasks).get(), hasLength(105));
      expect((await b.state()).pending, isEmpty);
    },
  );

  test(
    'journal failure in the middle of a group restores root, children and logs',
    () async {
      final root = await add('Root');
      await add('Child', parent: root.id);
      await logs.addWorkLog(WorkLog.blank(root.id));
      final count = (await a.readFeed()).entries.length;
      await aDb.customStatement(
        "CREATE TRIGGER reject_group BEFORE INSERT ON sync_revisions WHEN (SELECT count(*) FROM sync_revisions) > $count BEGIN SELECT RAISE(ABORT, 'test'); END",
      );
      await expectLater(
        DriftGraphDeletion(
          aDb,
          journal: a,
        ).delete(GraphNodeType.task, root.id, keepChildren: false),
        throwsA(anything),
      );
      expect(await aDb.select(aDb.tasks).get(), hasLength(2));
      expect(await aDb.select(aDb.workLogs).get(), hasLength(1));
      expect((await a.readFeed()).entries, hasLength(count));
    },
  );
  setUp(() async {
    aDb = AppDatabase(NativeDatabase.memory());
    bDb = AppDatabase(NativeDatabase.memory());
    a = DriftSyncStore(aDb);
    b = DriftSyncStore(bDb);
    await a.initialize('dataset');
    await b.initialize('dataset');
    tasks = TasksRepository(TasksDao(aDb, journal: a));
    logs = WorkLogsRepository(WorkLogsDao(aDb, journal: a));
  });
  tearDown(() async {
    await aDb.close();
    await bDb.close();
  });
  Future<Set<String>> versions(DriftSyncStore s, String key) async =>
      (await s.heads(key)).map((r) => r.id).toSet();
  Future<List<SyncEntry>> tail(int after) async =>
      (await a.readFeed(after: after)).entries;

  test(
    'work logs preserve identity and interval; completion leaves logs unchanged',
    () async {
      final task = await add('Task');
      final log = WorkLog.blank(task.id).copyWith(
        description: 'Timed',
        startedAt: Wrapped(DateTime(2026, 11, 15, 10)),
        endedAt: Wrapped(DateTime(2026, 11, 15, 11)),
      );
      await logs.addWorkLog(log);
      final read = (await logs.getById(log.id))!;
      expect(read.storageRevision, isNotNull);
      expect(
        (await logs.getWorkLogsForTask(task.id)).single.storageRevision,
        read.storageRevision,
      );
      expect(
        (await logs.watchWorkLogsForTask(task.id).first).single.storageRevision,
        read.storageRevision,
      );
      await tasks.completeTask(task.id);
      await logs.updateWorkLog(read.copyWith(description: 'Updated'));
      await expectLater(
        logs.updateWorkLog(read.copyWith(description: 'Stale')),
        throwsStateError,
      );
      await engine.exchange(a, b);
      final remote = (await bDb.select(bDb.workLogs).get()).single;
      expect(remote.id, log.id);
      expect(remote.description, 'Updated');
      expect(
        remote.endedAt!.difference(remote.startedAt!),
        const Duration(hours: 1),
      );
      expect((await b.heads('workLog/${log.id}')), hasLength(1));
    },
  );

  for (final keepChildren in [true, false]) {
    test(
      'graph deletion keepChildren=$keepChildren is one complete transaction group',
      () async {
        final root = await add('Root');
        final child = await add('Child', parent: root.id);
        final grandchild = await add('Grandchild', parent: child.id);
        await logs.addWorkLog(WorkLog.blank(root.id));
        await logs.addWorkLog(WorkLog.blank(child.id));
        await engine.exchange(a, b);
        final cursor = await b.receivedCursor((await a.identity()).deviceId);
        await DriftGraphDeletion(
          aDb,
          journal: a,
        ).delete(GraphNodeType.task, root.id, keepChildren: keepChildren);
        final entries = await tail(cursor);
        expect(entries.length, greaterThan(1));
        expect(entries.map((e) => e.revision.groupId).toSet(), hasLength(1));
        expect(
          entries.first.revision.groupMembers.toSet(),
          entries.map((e) => e.revision.id).toSet(),
        );
        await b.receive(SyncBatch(await a.identity(), cursor, entries.take(1)));
        expect(await bDb.select(bDb.tasks).get(), hasLength(3));
        expect(await bDb.select(bDb.workLogs).get(), hasLength(2));
        expect((await b.state()).pending, hasLength(1));
        await b.receive(
          SyncBatch(await a.identity(), cursor + 1, entries.skip(1)),
        );
        final remaining = await bDb.select(bDb.tasks).get();
        if (keepChildren) {
          expect(remaining, hasLength(2));
          expect(
            remaining.singleWhere((t) => t.id == child.id).parentTaskId,
            isNull,
          );
          expect(
            remaining.singleWhere((t) => t.id == grandchild.id).parentTaskId,
            child.id,
          );
          expect(await bDb.select(bDb.workLogs).get(), hasLength(1));
        } else {
          expect(remaining, isEmpty);
          expect(await bDb.select(bDb.workLogs).get(), isEmpty);
        }
        expect((await b.state()).pending, isEmpty);
        expect(
          await bDb.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        await engine.exchange(a, b);
        expect(
          (await a.readFeed()).entries.length,
          (await b.readFeed()).entries.length,
        );
      },
    );
  }

  test(
    'failure after a partial group rolls back data, last revision and cursor',
    () async {
      final root = await add('Root');
      await add('Child', parent: root.id);
      await engine.exchange(a, b);
      final cursor = await b.receivedCursor((await a.identity()).deviceId);
      await DriftGraphDeletion(
        aDb,
        journal: a,
      ).delete(GraphNodeType.task, root.id, keepChildren: false);
      final entries = await tail(cursor);
      await b.receive(SyncBatch(await a.identity(), cursor, entries.take(1)));
      await bDb.customStatement(
        "CREATE TRIGGER reject_delete BEFORE DELETE ON tasks BEGIN SELECT RAISE(ABORT, 'test'); END",
      );
      await expectLater(
        b.receive(SyncBatch(await a.identity(), cursor + 1, entries.skip(1))),
        throwsA(anything),
      );
      expect(await b.receivedCursor((await a.identity()).deviceId), cursor + 1);
      expect(await bDb.select(bDb.tasks).get(), hasLength(2));
      expect((await b.state()).pending, hasLength(1));
      await bDb.customStatement('DROP TRIGGER reject_delete');
      await b.receive(
        SyncBatch(await a.identity(), cursor + 1, entries.skip(1)),
      );
      expect(await bDb.select(bDb.tasks).get(), isEmpty);
    },
  );

  test(
    'two concurrent new work logs do not conflict; same log edits preserve both versions',
    () async {
      final task = await add('Task');
      final shared = WorkLog.blank(task.id);
      await logs.addWorkLog(shared);
      await engine.exchange(a, b);
      final otherLogs = WorkLogsRepository(WorkLogsDao(bDb, journal: b));
      final readA = (await logs.getById(shared.id))!;
      final readB = (await otherLogs.getById(shared.id))!;
      await logs.addWorkLog(WorkLog.blank(task.id));
      await otherLogs.addWorkLog(WorkLog.blank(task.id));
      await logs.updateWorkLog(readA.copyWith(description: 'A'));
      await otherLogs.updateWorkLog(readB.copyWith(description: 'B'));
      await engine.exchange(a, b);
      expect(await aDb.select(aDb.workLogs).get(), hasLength(3));
      expect((await a.readConflicts())['workLog/${shared.id}'], hasLength(2));
      await a.saveWorkLog(
        shared.copyWith(description: 'Resolved'),
        expectedHeads: await versions(a, 'workLog/${shared.id}'),
        resolveConflict: true,
      );
      await engine.exchange(a, b);
      expect(await b.readConflicts(), isEmpty);
      expect((await otherLogs.getById(shared.id))!.description, 'Resolved');
    },
  );

  test(
    'work log before its task stays pending until dependency arrives',
    () async {
      final task = Task.blank();
      final log = WorkLog.blank(task.id);
      final logRevision = SyncRevision(
        id: 'log',
        deviceId: 'peer',
        entityId: log.id,
        entityType: 'workLog',
        parents: [],
        payload: WorkLogSyncCodec.encode(log),
        schemaVersion: 2,
      );
      await b.receive(
        SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
          SyncEntry(1, logRevision),
        ]),
      );
      expect(await bDb.select(bDb.workLogs).get(), isEmpty);
      final taskRevision = SyncRevision(
        id: 'task',
        deviceId: 'peer',
        entityId: task.id,
        parents: [],
        payload: TaskSyncCodec.encode(task),
      );
      await b.receive(
        SyncBatch(const SyncIdentity('dataset', 'peer'), 1, [
          SyncEntry(2, taskRevision),
        ]),
      );
      expect(await bDb.select(bDb.workLogs).get(), hasLength(1));
      expect((await b.state()).pending, isEmpty);
    },
  );

  test(
    'local cycle is rejected; concurrent cycle stays pending without corrupting hierarchy',
    () async {
      final first = await add('First');
      final second = await add('Second');
      await engine.exchange(a, b);
      await tasks.updateTask(first.copyWith(parentTaskId: Wrapped(second.id)));
      final localSecond = (await tasks.getById(second.id))!;
      await expectLater(
        tasks.updateTask(localSecond.copyWith(parentTaskId: Wrapped(first.id))),
        throwsA(anything),
      );
      final otherTasks = TasksRepository(TasksDao(bDb, journal: b));
      final otherSecond = (await otherTasks.getById(second.id))!;
      await otherTasks.updateTask(
        otherSecond.copyWith(parentTaskId: Wrapped(first.id)),
      );
      await engine.exchange(a, b);
      expect((await a.state()).pending, hasLength(2));
      expect((await b.state()).pending, hasLength(2));
      expect(
        (await aDb.select(aDb.tasks).get()).every(
          (t) => t.parentTaskId == null,
        ),
        isTrue,
      );
      expect(
        (await bDb.select(bDb.tasks).get()).every(
          (t) => t.parentTaskId == null,
        ),
        isTrue,
      );
      final basis = {
        ...await versions(a, first.id),
        ...(await a.readPending())
            .where((r) => r.key == first.id)
            .map((r) => r.id),
      };
      await expectLater(
        a.repairPendingTask(first, expectedRevisions: {}),
        throwsStateError,
      );
      await a.repairPendingTask(
        first.copyWith(parentTaskId: const Wrapped(null)),
        expectedRevisions: basis,
      );
      await engine.exchange(a, b);
      expect((await a.state()).pending, isEmpty);
      expect((await b.state()).pending, isEmpty);
      expect((await otherTasks.getById(second.id))!.parentTaskId, first.id);
    },
  );

  test(
    'incomplete group survives restart and applies only after final member',
    () async {
      final dir = await Directory.systemTemp.createTemp('life_os_sync_group_');
      var db = AppDatabase(
        NativeDatabase(File('${dir.path}${Platform.pathSeparator}test.sqlite')),
      );
      try {
        var store = DriftSyncStore(db);
        await store.initialize('dataset');
        final first = Task.blank();
        final second = Task.blank();
        final members = ['r1', 'r2'];
        SyncRevision r(String id, Task t) => SyncRevision(
          id: id,
          deviceId: 'peer',
          entityId: t.id,
          parents: [],
          payload: TaskSyncCodec.encode(t),
          schemaVersion: 2,
          groupId: 'group',
          groupMembers: members,
        );
        final one = r('r1', first);
        final two = r('r2', second);
        await store.receive(
          SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
            SyncEntry(1, one),
          ]),
        );
        await db.close();
        db = AppDatabase(
          NativeDatabase(
            File('${dir.path}${Platform.pathSeparator}test.sqlite'),
          ),
        );
        store = DriftSyncStore(db);
        expect((await store.state()).pending, {'r1'});
        expect(await db.select(db.tasks).get(), isEmpty);
        await store.receive(
          SyncBatch(const SyncIdentity('dataset', 'peer'), 1, [
            SyncEntry(2, two),
          ]),
        );
        expect(await db.select(db.tasks).get(), hasLength(2));
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'inconsistent transaction members reject without acknowledging the batch',
    () async {
      final first = Task.blank();
      final second = Task.blank();
      final one = SyncRevision(
        id: 'r1',
        deviceId: 'peer',
        entityId: first.id,
        parents: [],
        payload: TaskSyncCodec.encode(first),
        schemaVersion: 2,
        groupId: 'group',
        groupMembers: ['r1', 'r2'],
      );
      final two = SyncRevision(
        id: 'r2',
        deviceId: 'peer',
        entityId: second.id,
        parents: [],
        payload: TaskSyncCodec.encode(second),
        schemaVersion: 2,
        groupId: 'other',
        groupMembers: ['r1', 'r2'],
      );
      await b.receive(
        SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
          SyncEntry(1, one),
        ]),
      );
      await expectLater(
        b.receive(
          SyncBatch(const SyncIdentity('dataset', 'peer'), 1, [
            SyncEntry(2, two),
          ]),
        ),
        throwsFormatException,
      );
      expect(await b.receivedCursor('peer'), 1);
      expect(await bDb.select(bDb.tasks).get(), isEmpty);
    },
  );
}
