import 'package:core_contracts/core_contracts.dart' show StorageException;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/sync/data/drift_sync_store.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/lifegraph/data/drift_graph_deletion.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';

void main() {
  late AppDatabase db;
  late DriftSyncStore store;
  late TasksDao dao;
  late TasksRepository repo;
  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    store = DriftSyncStore(db);
    dao = TasksDao(db, journal: store);
    repo = TasksRepository(dao);
    await store.initialize('dataset');
  });
  tearDown(() => db.close());

  test(
    'repository create, edit, narrow completion and delete share journal',
    () async {
      final original = Task.blank();
      await repo.addTask(original);
      final loaded = (await repo.getById(original.id))!;
      expect(
        loaded.storageRevision,
        (await store.heads(original.id)).single.id,
      );
      expect(
        loaded.copyWith(title: 'Edit').storageRevision,
        loaded.storageRevision,
      );
      await repo.updateTask(loaded.copyWith(title: 'Edit'));
      final completed = (await repo.completeTask(original.id))!;
      expect(completed.title, 'Edit');
      expect(
        completed.storageRevision,
        (await store.heads(original.id)).single.id,
      );
      final count = (await store.readFeed()).entries.length;
      await repo.completeTask(original.id);
      expect((await store.readFeed()).entries.length, count);
      await repo.deleteTask(original.id);
      expect((await store.heads(original.id)).single.deleted, isTrue);
      expect((await store.readFeed()).entries.length, 4);
    },
  );

  test(
    'stale or missing read token rejects even when updatedAt is unchanged',
    () async {
      final original = Task.blank();
      await repo.addTask(original);
      final stale = (await repo.getById(original.id))!;
      await repo.updateTask(stale.copyWith(title: 'New'));
      await expectLater(
        repo.updateTask(stale.copyWith(title: 'Stale')),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        repo.updateTask(original),
        throwsA(isA<StorageException>()),
      );
      expect((await repo.getById(original.id))!.title, 'New');
      expect((await store.readFeed()).entries, hasLength(2));
    },
  );

  test('list and stream snapshots carry matching versions', () async {
    final original = Task.blank();
    await repo.addTask(original);
    final all = await repo.getAllTasks();
    final streamed = await repo.watchTasks().first;
    final projectStream = await repo.watchTasksForProject('none').first;
    expect(projectStream, isEmpty);
    expect(all.single.storageRevision, streamed.single.storageRevision);
    expect(all.single.storageRevision, isNotNull);
    await repo.updateTask(streamed.single.copyWith(title: 'From stream'));
    // Simulate a delayed stream snapshot explicitly: it must not acquire the new token.
    expect((await store.observe(all.single)).storageRevision, isNull);
  });

  test(
    'received edit invalidates previously opened repository snapshot',
    () async {
      final otherDb = AppDatabase(NativeDatabase.memory());
      addTearDown(otherDb.close);
      final other = DriftSyncStore(otherDb);
      await other.initialize('dataset');
      final original = Task.blank();
      await repo.addTask(original);
      final stale = (await repo.getById(original.id))!;
      final engine = SyncEngine();
      await engine.exchange(store, other);
      await other.saveTask(
        original.copyWith(title: 'Remote'),
        expectedHeads: (await other.heads(
          original.id,
        )).map((r) => r.id).toSet(),
      );
      await engine.exchange(store, other);
      await expectLater(
        repo.updateTask(stale),
        throwsA(isA<StorageException>()),
      );
      final current = (await repo.getById(original.id))!;
      await repo.updateTask(current.copyWith(title: 'Next'));
      await engine.exchange(store, other);
      expect(
        TaskSyncCodec.decode(
          (await other.heads(original.id)).single.payload!,
        ).title,
        'Next',
      );
    },
  );

  test('conflicts refuse normal edits, completion and deletion', () async {
    final original = Task.blank();
    await repo.addTask(original);
    final stale = (await repo.getById(original.id))!;
    final parent = stale.storageRevision!;
    await repo.updateTask(stale.copyWith(title: 'Local'));
    final remote = SyncRevision(
      id: 'remote',
      deviceId: 'peer',
      entityId: original.id,
      parents: [parent],
      payload: TaskSyncCodec.encode(original.copyWith(title: 'Remote')),
    );
    await store.receive(
      SyncBatch(const SyncIdentity('dataset', 'peer'), 0, [
        SyncEntry(1, remote),
      ]),
    );
    final conflicted = (await repo.getById(original.id))!;
    expect(conflicted.storageRevision, isNull);
    for (final action in [
      () => repo.updateTask(conflicted),
      () => repo.completeTask(original.id),
      () => repo.deleteTask(original.id),
    ]) {
      await expectLater(action(), throwsA(isA<StorageException>()));
    }
    expect((await store.readConflicts())[original.id], hasLength(2));
  });

  test(
    'failed journal rolls back task write and never publishes committed edit',
    () async {
      final original = Task.blank();
      await repo.addTask(original);
      final loaded = (await repo.getById(original.id))!;
      await db.customStatement(
        "CREATE TRIGGER reject_revision BEFORE INSERT ON sync_revisions BEGIN SELECT RAISE(ABORT, 'test failure'); END",
      );
      await expectLater(
        repo.updateTask(loaded.copyWith(title: 'Lost')),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        repo.completeTask(original.id),
        throwsA(isA<StorageException>()),
      );
      await expectLater(
        repo.deleteTask(original.id),
        throwsA(isA<StorageException>()),
      );
      expect((await repo.getById(original.id))!.title, original.title);
      expect((await repo.getById(original.id))!.status, original.status);
      expect((await store.readFeed()).entries, hasLength(1));
    },
  );

  test(
    'tags and work logs are journaled; missing task parents roll back',
    () async {
      final original = Task.blank();
      await repo.addTask(original);
      final loaded = (await repo.getById(original.id))!;
      await repo.updateTask(
        loaded.copyWith(tags: [const Tag(id: 0, name: 'tag', colorHex: 0)]),
      );
      await expectLater(
        repo.updateTask(loaded.copyWith(parentTaskId: const Wrapped('parent'))),
        throwsA(isA<StorageException>()),
      );
      final logs = WorkLogsDao(db, journal: store);
      await logs.insertWorkLog(
        WorkLogsCompanion.insert(
          id: 'log',
          status: 0,
          taskId: original.id,
          date: DateTime(2026),
          description: 'Unsupported',
        ),
      );
      expect(await db.select(db.tags).get(), hasLength(1));
      expect(await db.select(db.workLogs).get(), hasLength(1));
      expect((await repo.getById(original.id))!.parentTaskId, isNull);
      expect((await store.readFeed()).entries, hasLength(4));
    },
  );

  test('add cannot overwrite an existing or deleted ID', () async {
    final original = Task.blank();
    await repo.addTask(original);
    await expectLater(
      repo.addTask(original.copyWith(title: 'Overwrite')),
      throwsA(isA<StorageException>()),
    );
    await repo.deleteTask(original.id);
    await expectLater(repo.addTask(original), throwsA(isA<StorageException>()));
    expect(await repo.getById(original.id), isNull);
  });

  test('raw DAO insert and graph deletion are both journaled', () async {
    final original = Task.blank();
    await dao.insert(
      TasksCompanion.insert(
        id: original.id,
        title: original.title,
        description: '',
        status: TaskStatus.open,
        createdAt: original.createdAt,
        updatedAt: original.updatedAt,
      ),
    );
    final deletion = DriftGraphDeletion(db, journal: store);
    for (final keepChildren in [false, true]) {
      await deletion.delete(
        GraphNodeType.task,
        original.id,
        keepChildren: keepChildren,
      );
    }
    expect(await repo.getById(original.id), isNull);
    expect((await store.readFeed()).entries, hasLength(2));
  });

  test(
    'journal before initialization preserves existing task and worklog behavior',
    () async {
      final freshDb = AppDatabase(NativeDatabase.memory());
      addTearDown(freshDb.close);
      final inactive = DriftSyncStore(freshDb);
      final fresh = TasksRepository(TasksDao(freshDb, journal: inactive));
      final original = Task.blank().copyWith(
        projectId: const Wrapped('project'),
      );
      await fresh.addTask(original);
      await fresh.updateTask(original.copyWith(title: 'Update'));
      final logs = WorkLogsDao(freshDb, journal: inactive);
      await logs.insertWorkLog(
        WorkLogsCompanion.insert(
          id: 'log',
          status: 0,
          taskId: original.id,
          date: DateTime(2026),
          description: 'Keep',
        ),
      );
      await fresh.completeTask(original.id);
      expect(await freshDb.select(freshDb.workLogs).get(), hasLength(1));
      expect(await freshDb.select(freshDb.syncRevisions).get(), isEmpty);
      final savedLog = (await logs.getById('log'))!;
      await logs.updateWorkLog(
        savedLog.copyWith(description: 'Changed').toCompanion(true),
      );
      expect((await logs.getById('log'))!.description, 'Changed');
      await logs.deleteWorkLog('log');
      expect(await freshDb.select(freshDb.workLogs).get(), isEmpty);
    },
  );
}
