import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  late AppDatabase aDb;
  late AppDatabase bDb;
  late DriftSyncStore a;
  late DriftSyncStore b;
  final engine = SyncEngine();
  test('large UTF-8 payloads are split into receivable batches', () async {
    final title = List.filled(200000, 'я').join();
    for (var i = 0; i < 12; i++) {
      await a.saveTask(Task.blank().copyWith(title: title), expectedHeads: {});
    }
    expect((await a.readFeed()).entries.length, lessThan(12));
    await engine.exchange(a, b);
    expect(await bDb.select(bDb.tasks).get(), hasLength(12));
  });
  Future<Set<String>> versions(DriftSyncStore store, String id) async =>
      (await store.heads(id)).map((r) => r.id).toSet();
  Future<Task?> task(AppDatabase db, String id) =>
      TasksDao(db).getTaskWithTags(id);
  setUp(() async {
    aDb = AppDatabase(NativeDatabase.memory());
    bDb = AppDatabase(NativeDatabase.memory());
    a = DriftSyncStore(aDb);
    b = DriftSyncStore(bDb);
    await a.initialize('dataset');
    await b.initialize('dataset');
  });
  tearDown(() async {
    await aDb.close();
    await bDb.close();
  });

  test(
    'a merged payload resolves the recorded heads and converges after exchange',
    () async {
      final original = Task.blank();
      await a.saveTask(original, expectedHeads: {});
      await engine.exchange(a, b);
      final local = original.copyWith(title: 'Изменение на ПК');
      final remote = original.copyWith(description: 'Изменение на планшете');
      await a.saveTask(local, expectedHeads: await versions(a, original.id));
      await b.saveTask(remote, expectedHeads: await versions(b, original.id));
      await engine.exchange(a, b);
      final heads = await a.heads(original.id);
      final basis = heads.map((revision) => revision.id).toSet();
      final merged = TaskSyncCodec.encode(
        local.copyWith(description: remote.description),
      );
      await expectLater(
        a.resolve(heads.first, {heads.first.id}, mergedPayload: merged),
        throwsStateError,
      );
      expect(await versions(a, original.id), basis);
      await a.resolve(heads.first, basis, mergedPayload: merged);
      final resolved = (await a.heads(original.id)).single;
      expect(resolved.parents.toSet(), basis);
      expect(resolved.payload, merged);
      await engine.exchange(a, b);
      final onTablet = (await task(bDb, original.id))!;
      expect(onTablet.title, local.title);
      expect(onTablet.description, remote.description);
      expect((await b.heads(original.id)).single.id, resolved.id);
    },
  );

  test(
    'unsupported bootstrap rolls back identity and all initial revisions',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final original = Task.blank();
      await db
          .into(db.tasks)
          .insert(
            TasksCompanion.insert(
              id: original.id,
              title: original.title,
              description: '',
              status: TaskStatus.open,
              createdAt: original.createdAt,
              updatedAt: original.updatedAt,
              projectId: const Value('project'),
            ),
          );
      final store = DriftSyncStore(db);
      await expectLater(store.initialize('dataset'), throwsStateError);
      expect(await db.select(db.syncIdentities).get(), isEmpty);
      expect(await db.select(db.syncRevisions).get(), isEmpty);
      expect((await db.select(db.tasks).getSingle()).projectId, 'project');
    },
  );

  test(
    'exchange drains multiple feed pages and preserves stale edit protection',
    () async {
      final original = Task.blank();
      await a.saveTask(original, expectedHeads: {});
      final stale = await versions(a, original.id);
      for (var i = 0; i < 101; i++) {
        await a.saveTask(
          original.copyWith(title: 'Version $i'),
          expectedHeads: await versions(a, original.id),
        );
      }
      await engine.exchange(a, b);
      expect((await task(bDb, original.id))!.title, 'Version 100');
      expect(await b.receivedCursor((await a.identity()).deviceId), 102);
      await expectLater(
        a.saveTask(original, expectedHeads: stale),
        throwsStateError,
      );
    },
  );

  test(
    'create, edit, complete, delete and replay converge without echoes',
    () async {
      final original = Task.blank().copyWith(
        title: 'Первое',
        startsAt: Wrapped(DateTime(2026, 12, 1)),
        endsAt: Wrapped(DateTime(2026, 12, 1, 15)),
        dueDate: Wrapped(DateTime.utc(2026, 12, 2)),
        space: const Wrapped('personal'),
        priority: 2,
        timerSeconds: 20,
        effortWeight: 2.5,
      );
      await a.saveTask(original, expectedHeads: {});
      final first = await a.readFeed();
      await b.receive(first);
      await b.receive(first);
      expect(
        TaskSyncCodec.encode((await task(bDb, original.id))!),
        TaskSyncCodec.encode(original),
      );
      await b.saveTask(
        original.copyWith(title: 'Второе'),
        expectedHeads: await versions(b, original.id),
      );
      await engine.exchange(a, b);
      await a.completeTask(
        original.id,
        expectedHeads: await versions(a, original.id),
      );
      final doneHeads = await versions(a, original.id);
      await a.completeTask(original.id, expectedHeads: doneHeads);
      expect(await versions(a, original.id), doneHeads);
      await engine.exchange(a, b);
      expect((await task(bDb, original.id))!.status, TaskStatus.done);
      await b.deleteTask(
        original.id,
        expectedHeads: await versions(b, original.id),
      );
      await engine.exchange(a, b);
      await engine.exchange(a, b);
      await b.receive(first);
      expect(await task(aDb, original.id), isNull);
      expect(await task(bDb, original.id), isNull);
      expect((await a.readFeed()).entries, hasLength(4));
      expect((await b.readFeed()).entries, hasLength(4));
      await expectLater(
        a.saveTask(original, expectedHeads: await versions(a, original.id)),
        throwsStateError,
      );
    },
  );

  test(
    'concurrent edits ignore clocks and explicit resolution joins both branches',
    () async {
      final original = Task.blank();
      await a.saveTask(original, expectedHeads: {});
      await engine.exchange(a, b);
      final stale = await versions(a, original.id);
      await a.saveTask(
        original.copyWith(title: 'A', updatedAt: DateTime(2000)),
        expectedHeads: stale,
      );
      await b.saveTask(
        original.copyWith(title: 'B', updatedAt: DateTime(2099)),
        expectedHeads: stale,
      );
      await engine.exchange(a, b);
      expect((await a.readConflicts())[original.id], hasLength(2));
      expect(
        (await task(aDb, original.id))!.title,
        (await task(bDb, original.id))!.title,
      );
      await expectLater(
        a.saveTask(original, expectedHeads: stale, resolveConflict: true),
        throwsStateError,
      );
      final current = await versions(a, original.id);
      await expectLater(
        a.saveTask(original, expectedHeads: current),
        throwsStateError,
      );
      await a.saveTask(
        original.copyWith(title: 'Merged'),
        expectedHeads: current,
        resolveConflict: true,
      );
      await engine.exchange(a, b);
      expect(await b.readConflicts(), isEmpty);
      expect((await task(bDb, original.id))!.title, 'Merged');
    },
  );

  test(
    'delete wins concurrent edit, retains edit and resolves only to deletion',
    () async {
      final original = Task.blank();
      await a.saveTask(original, expectedHeads: {});
      await engine.exchange(a, b);
      await a.deleteTask(
        original.id,
        expectedHeads: await versions(a, original.id),
      );
      await b.saveTask(
        original.copyWith(title: 'Offline edit'),
        expectedHeads: await versions(b, original.id),
      );
      await engine.exchange(a, b);
      expect(await task(bDb, original.id), isNull);
      expect(
        (await b.readConflicts())[original.id]!.where((r) => !r.deleted),
        hasLength(1),
      );
      final current = await versions(b, original.id);
      await expectLater(
        b.saveTask(original, expectedHeads: current, resolveConflict: true),
        throwsStateError,
      );
      await b.deleteTask(
        original.id,
        expectedHeads: current,
        resolveConflict: true,
      );
      await engine.exchange(a, b);
      expect(await a.readConflicts(), isEmpty);
    },
  );

  test(
    'child before parent stays pending then materializes newest version',
    () async {
      final original = Task.blank();
      final root = SyncRevision(
        id: 'root',
        deviceId: 'peer',
        entityId: original.id,
        parents: [],
        payload: TaskSyncCodec.encode(original),
      );
      final child = SyncRevision(
        id: 'child',
        deviceId: 'peer',
        entityId: original.id,
        parents: ['root'],
        payload: TaskSyncCodec.encode(original.copyWith(title: 'Child')),
      );
      await a.receive(
        SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
          SyncEntry(1, child),
        ]),
      );
      expect((await a.state()).pending, {'child'});
      expect(await task(aDb, original.id), isNull);
      await a.receive(
        SyncBatch(const SyncIdentity('dataset', 'peer'), 1, [
          SyncEntry(2, root),
        ]),
      );
      expect((await a.state()).pending, isEmpty);
      expect((await task(aDb, original.id))!.title, 'Child');
    },
  );

  test('A to B to C forwards original identity without echo growth', () async {
    final cDb = AppDatabase(NativeDatabase.memory());
    addTearDown(cDb.close);
    final c = DriftSyncStore(cDb);
    await c.initialize('dataset');
    final original = Task.blank();
    await a.saveTask(original, expectedHeads: {});
    await engine.exchange(a, b);
    await engine.exchange(b, c);
    await engine.exchange(c, a);
    expect(
      (await c.readFeed()).entries.single.revision.deviceId,
      (await a.identity()).deviceId,
    );
    expect((await a.readFeed()).entries, hasLength(1));
    expect((await task(cDb, original.id))!.title, original.title);
  });

  test('materialization failure rolls back journal and receive cursor', () async {
    final original = Task.blank();
    await a.saveTask(original, expectedHeads: {});
    await bDb.customStatement(
      "CREATE TRIGGER reject_task BEFORE INSERT ON tasks BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(b.receive(await a.readFeed()), throwsA(anything));
    expect((await b.readFeed()).entries, isEmpty);
    expect(await b.receivedCursor((await a.identity()).deviceId), 0);
    await bDb.customStatement('DROP TRIGGER reject_task');
    await b.receive(await a.readFeed());
    expect(await task(bDb, original.id), isNotNull);
  });

  test('journal failure prevents local edits', () async {
    final original = Task.blank();
    await a.saveTask(original, expectedHeads: {});
    await aDb.customStatement(
      "CREATE TRIGGER reject_revision BEFORE INSERT ON sync_revisions BEGIN SELECT RAISE(ABORT, 'test failure'); END",
    );
    await expectLater(
      a.saveTask(
        original.copyWith(title: 'Lost'),
        expectedHeads: await versions(a, original.id),
      ),
      throwsA(anything),
    );
    expect((await task(aDb, original.id))!.title, original.title);
    expect((await a.readFeed()).entries, hasLength(1));
  });

  test('untracked DAO edits cannot be overwritten by import', () async {
    final original = Task.blank();
    await a.saveTask(original, expectedHeads: {});
    await engine.exchange(a, b);
    await (bDb.update(bDb.tasks)..where((r) => r.id.equals(original.id))).write(
      const TasksCompanion(title: Value('Untracked')),
    );
    await a.saveTask(
      original.copyWith(title: 'Remote'),
      expectedHeads: await versions(a, original.id),
    );
    await expectLater(engine.exchange(a, b), throwsStateError);
    expect((await task(bDb, original.id))!.title, 'Untracked');
  });

  test('missing project links and untracked logs cannot be imported', () async {
    final original = Task.blank();
    await expectLater(
      Future.sync(
        () => a.saveTask(
          original.copyWith(projectId: const Wrapped('project')),
          expectedHeads: {},
        ),
      ),
      throwsStateError,
    );
    await a.saveTask(original, expectedHeads: {});
    await aDb
        .into(aDb.workLogs)
        .insert(
          WorkLogsCompanion.insert(
            id: 'log',
            status: 0,
            taskId: original.id,
            date: DateTime(2026),
            description: 'Keep',
          ),
        );
    await expectLater(
      a.deleteTask(original.id, expectedHeads: await versions(a, original.id)),
      throwsStateError,
    );
    expect(await aDb.select(aDb.workLogs).get(), hasLength(1));
    expect(await task(aDb, original.id), isNotNull);
  });

  test(
    'wrong dataset, missing range, collision and unknown schema reject atomically',
    () async {
      final original = Task.blank();
      await a.saveTask(original, expectedHeads: {});
      final batch = await a.readFeed();
      final r = batch.entries.single.revision;
      await expectLater(
        b.receive(
          SyncBatch(const SyncIdentity('other', 'peer'), 0, batch.entries),
        ),
        throwsStateError,
      );
      await expectLater(
        b.receive(SyncBatch(batch.source, 1, [SyncEntry(2, r)])),
        throwsStateError,
      );
      await b.receive(batch);
      final collision = SyncRevision(
        id: r.id,
        deviceId: r.deviceId,
        entityId: r.entityId,
        parents: [],
        payload: TaskSyncCodec.encode(original.copyWith(title: 'Collision')),
      );
      await expectLater(
        b.receive(SyncBatch(batch.source, 1, [SyncEntry(2, collision)])),
        throwsFormatException,
      );
      final unknown = SyncRevision(
        id: 'new',
        deviceId: r.deviceId,
        entityId: r.entityId,
        parents: [],
        payload: r.payload,
        schemaVersion: SyncRevision.supportedSchema + 1,
      );
      await expectLater(
        b.receive(SyncBatch(batch.source, 1, [SyncEntry(2, unknown)])),
        throwsUnsupportedError,
      );
      expect((await b.readFeed()).entries, hasLength(1));
      expect(await b.receivedCursor(batch.source.deviceId), 1);
    },
  );

  test(
    'cyclic revisions and parents from another entity reject atomically',
    () async {
      final original = Task.blank();
      SyncRevision revision(
        String id,
        List<String> parents, {
        String? entity,
      }) => SyncRevision(
        id: id,
        deviceId: 'peer',
        entityId: entity ?? original.id,
        parents: parents,
        payload: TaskSyncCodec.encode(original.copyWith(id: entity)),
      );
      await expectLater(
        a.receive(
          SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
            SyncEntry(1, revision('x', ['y'])),
            SyncEntry(2, revision('y', ['x'])),
          ]),
        ),
        throwsFormatException,
      );
      await expectLater(
        a.receive(
          SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
            SyncEntry(1, revision('x', [])),
            SyncEntry(2, revision('y', ['x'], entity: 'other')),
          ]),
        ),
        throwsFormatException,
      );
      expect((await a.readFeed()).entries, isEmpty);
    },
  );

  test(
    'restart preserves identity, pending revisions, tombstones and cursors',
    () async {
      final dir = await Directory.systemTemp.createTemp('life_os_sync_');
      final file = File('${dir.path}${Platform.pathSeparator}sync.sqlite');
      var db = AppDatabase(NativeDatabase(file));
      try {
        var store = DriftSyncStore(db);
        await store.initialize('dataset');
        final id = (await store.identity()).deviceId;
        final original = Task.blank();
        await store.saveTask(original, expectedHeads: {});
        await store.deleteTask(
          original.id,
          expectedHeads: await versions(store, original.id),
        );
        final pending = SyncRevision(
          id: 'waiting',
          deviceId: 'peer',
          entityId: 'other',
          parents: ['missing'],
          payload: null,
        );
        await store.receive(
          SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
            SyncEntry(1, pending),
          ]),
        );
        await db.close();
        db = AppDatabase(NativeDatabase(file));
        store = DriftSyncStore(db);
        await store.initialize('dataset');
        expect((await store.identity()).deviceId, id);
        expect((await store.state()).pending, {'waiting'});
        expect((await store.heads(original.id)).single.deleted, isTrue);
        expect(await store.receivedCursor('peer'), 1);
        expect((await store.readFeed()).entries, hasLength(3));
      } finally {
        await db.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
