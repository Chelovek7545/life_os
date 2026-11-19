import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';
import 'package:life_os/features/tasks/data/extensions/work_log_model_extension.dart';
import 'package:life_os/features/tasks/data/task_mutation_journal.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:uuid/uuid.dart';
import 'package:life_os/features/projects/data/extensions/project_model_extension.dart';
import 'package:life_os/features/goals/data/goal_model_extension.dart';
import 'package:life_os/features/spheres/data/sphere_model_extension.dart';
import 'package:life_os/features/tasks/data/extensions/tag_model_extension.dart';

class DriftSyncStore implements SyncStore, TaskMutationJournal, LocalSyncData {
  DriftSyncStore(this.db);
  final AppDatabase db;
  final Object _captureZone = Object();
  static const _projectionMarker = '';
  @override
  SyncStore get store => this;
  @override
  Future<SyncIdentity?> existingIdentity() async {
    final row = await db.select(db.syncIdentities).getSingleOrNull();
    return row == null ? null : SyncIdentity(row.datasetId, row.deviceId);
  }

  @override
  Future<bool> canJoin() => db.transaction(() async {
    if (await existingIdentity() != null) return false;
    for (final table in [
      'tasks',
      'work_logs',
      'projects',
      'goals',
      'spheres',
      'tags',
    ]) {
      if ((await db.customSelect('SELECT 1 FROM $table LIMIT 1').get())
          .isNotEmpty) {
        return false;
      }
    }
    return true;
  });
  @override
  Future<void> enroll(
    String datasetId,
    String deviceId, {
    required bool requireEmpty,
  }) => db.transaction(() async {
    if (requireEmpty && !await canJoin()) {
      throw const LocalSyncException(
        'Для подключения нужна пустая база. Существующие данные не изменены.',
      );
    }
    await initialize(datasetId, deviceId: deviceId);
  });
  @override
  Future<List<SyncRevision>> pendingRevisions() => readPending();
  @override
  Future<Map<String, List<SyncRevision>>> conflicts() => readConflicts();
  @override
  Future<Map<String, String>> entityNames({bool liveOnly = false}) =>
      db.transaction(() async {
        final revisions = await _revisions();
        final graph = SyncGraph(revisions);
        final names = <String, String>{};
        void remember(SyncRevision revision) {
          if (revision.payload == null) return;
          final m = jsonDecode(revision.payload!) as Map<String, dynamic>;
          names[revision.key] =
              (m['title'] ?? m['name'] ?? m['description'] ?? 'Запись')
                  .toString();
        }

        if (!liveOnly) {
          for (final r in revisions) {
            remember(r);
          }
        }
        for (final key in graph.heads.keys) {
          remember(graph.winner(key)!);
        }
        return names;
      });
  @override
  Future<List<LocalSyncPending>> pendingRepairs() => db.transaction(() async {
    final revisions = await _revisions();
    final graph = SyncGraph(revisions);
    return [
      for (final r in revisions)
        if (graph.pending.contains(r.id))
          LocalSyncPending(r, {
            ...(graph.heads[r.key] ?? []).map((h) => h.id),
            ...revisions
                .where((p) => p.key == r.key && graph.pending.contains(p.id))
                .map((p) => p.id),
          }),
    ];
  });
  @override
  Future<void> repair(
    SyncRevision revision,
    String payload,
    Set<String> expected,
  ) async {
    if (SyncPayload.payloadId(revision.entityType, payload) !=
        revision.entityId) {
      throw const FormatException('Repair identity changed.');
    }
    await repairPendingEntity(
      revision.entityType,
      payload,
      expectedRevisions: expected,
    );
  }

  @override
  Future<void> resolve(SyncRevision chosen, Set<String> expected) => _write(
    chosen.key,
    chosen.payload,
    expectedHeads: expected,
    resolveConflict: true,
  );

  static int _version(String type, String? payload, {bool grouped = false}) {
    if (!['task', 'workLog'].contains(type)) return 3;
    if (type == 'workLog') return 2;
    if (payload != null) {
      final task = TaskSyncCodec.decode(payload);
      if (task.projectId != null ||
          task.spaceId != null ||
          task.tags.isNotEmpty) {
        return 3;
      }
      if (task.parentTaskId != null) return 2;
    }
    return grouped ? 2 : 1;
  }

  @override
  Future<String?> observedRevision(String key, String payload) async =>
      (await observedRevisions({key: payload}))[key];

  Future<void> _saveProjection(
    SyncGraph graph,
    Iterable<SyncRevision> revisions,
  ) async {
    final pendingKeys = {
      for (final revision in revisions)
        if (graph.pending.contains(revision.id)) revision.key,
    };
    await db.batch((batch) {
      batch.deleteAll(db.syncEntityHeads);
      batch.insertAll(db.syncEntityHeads, [
        for (final key in {...graph.heads.keys, ...pendingKeys})
          SyncEntityHeadRow(
            entityKey: key,
            revisionId: graph.heads[key]?.length == 1
                ? graph.heads[key]!.single.id
                : null,
            payload: graph.heads[key]?.length == 1
                ? graph.heads[key]!.single.payload
                : null,
            blocked:
                pendingKeys.contains(key) ||
                (graph.heads[key]?.length ?? 0) > 1,
          ),
        _marker(hasPending: pendingKeys.isNotEmpty),
      ]);
    });
  }

  SyncEntityHeadRow _marker({required bool hasPending}) =>
      SyncEntityHeadRow(entityKey: _projectionMarker, blocked: hasPending);

  Future<SyncEntityHeadRow?> _projectedHead(String key) => (db.select(
    db.syncEntityHeads,
  )..where((row) => row.entityKey.equals(key))).getSingleOrNull();

  Future<SyncEntityHeadRow> _ensureProjection() async {
    final marker = await _projectedHead(_projectionMarker);
    if (marker != null) return marker;
    final revisions = await _revisions();
    final graph = SyncGraph(revisions);
    await _saveProjection(graph, revisions);
    return _marker(hasPending: graph.pending.isNotEmpty);
  }

  Future<Map<String, String>> _observedTokens(
    Map<String, String> payloads,
  ) async {
    await _ensureProjection();
    final keys = payloads.keys.toList(growable: false);
    final tokens = <String, String>{};
    const batchSize = 500;
    for (var offset = 0; offset < keys.length; offset += batchSize) {
      final rows =
          await (db.select(db.syncEntityHeads)..where(
                (row) => row.entityKey.isIn(keys.skip(offset).take(batchSize)),
              ))
              .get();
      for (final row in rows) {
        if (row.revisionId != null && row.payload == payloads[row.entityKey]) {
          tokens[row.entityKey] = row.revisionId!;
        }
      }
    }
    return tokens;
  }

  @override
  Future<Map<String, String>> observedRevisions(Map<String, String> payloads) =>
      db.transaction(() async {
        if (payloads.isEmpty ||
            await db.select(db.syncIdentities).getSingleOrNull() == null) {
          return {};
        }
        return _observedTokens(payloads);
      });
  @override
  Future<T> trackEntity<T>(
    String type,
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) => trackTask(
    SyncPayload.key(type, id),
    write,
    expectedRevision: expectedRevision,
    requireExpected: requireExpected,
    createOnly: createOnly,
  );

  @override
  Future<Task> observe(Task task) async => (await observeTasks([task])).single;

  @override
  Future<List<Task>> observeTasks(List<Task> tasks) => db.transaction(() async {
    if (tasks.isEmpty) return tasks;
    if (await db.select(db.syncIdentities).getSingleOrNull() == null) {
      return tasks;
    }
    final tokens = await _observedTokens({
      for (final task in tasks) task.id: TaskSyncCodec.encode(task),
    });
    return [
      for (final task in tasks)
        Task(
          id: task.id,
          title: task.title,
          description: task.description,
          status: task.status,
          createdAt: task.createdAt,
          updatedAt: task.updatedAt,
          startsAt: task.startsAt,
          endsAt: task.endsAt,
          dueDate: task.dueDate,
          projectId: task.projectId,
          parentTaskId: task.parentTaskId,
          space: task.space,
          spaceId: task.spaceId,
          priority: task.priority,
          timerSeconds: task.timerSeconds,
          effortWeight: task.effortWeight,
          tags: task.tags,
          storageRevision: tokens[task.id],
        ),
    ];
  });

  @override
  Future<WorkLog> observeWorkLog(WorkLog log) async =>
      (await observeWorkLogs([log])).single;

  @override
  Future<List<WorkLog>> observeWorkLogs(List<WorkLog> logs) =>
      db.transaction(() async {
        if (logs.isEmpty) return logs;
        if (await db.select(db.syncIdentities).getSingleOrNull() == null) {
          return logs;
        }
        final tokens = await _observedTokens({
          for (final log in logs)
            'workLog/${log.id}': WorkLogSyncCodec.encode(log),
        });
        return [
          for (final log in logs)
            WorkLog(
              id: log.id,
              taskId: log.taskId,
              status: log.status,
              date: log.date,
              description: log.description,
              startedAt: log.startedAt,
              endedAt: log.endedAt,
              storageRevision: tokens['workLog/${log.id}'],
            ),
        ];
      });

  Future<List<SyncRevision>> _revisions() async =>
      (await db.select(db.syncRevisions).get())
          .map((r) => SyncRevision.decode(r.body))
          .toList();
  Future<SyncGraph> state() async => SyncGraph(await _revisions());
  Future<List<SyncRevision>> heads(String key) async =>
      List.unmodifiable((await state()).heads[key] ?? []);
  Future<Map<String, List<SyncRevision>>> readConflicts() async =>
      Map.unmodifiable({
        for (final entry in (await state()).heads.entries)
          if (entry.value.length > 1)
            entry.key: List<SyncRevision>.unmodifiable(entry.value),
      });

  Future<List<SyncRevision>> readPending() async {
    final revisions = await _revisions();
    final graph = SyncGraph(revisions);
    return List.unmodifiable(
      revisions.where((r) => graph.pending.contains(r.id)),
    );
  }

  // Explicit recovery for a structurally blocked edit (for example, an offline
  // hierarchy cycle). Unknown causal parents must still arrive before repair.
  Future<void> repairPendingTask(
    Task task, {
    required Set<String> expectedRevisions,
  }) => repairPendingEntity(
    'task',
    TaskSyncCodec.encode(task),
    expectedRevisions: expectedRevisions,
  );
  Future<void> repairPendingEntity(
    String type,
    String payload, {
    required Set<String> expectedRevisions,
  }) => db.transaction(() async {
    final local = await identity();
    final id = SyncPayload.payloadId(type, payload);
    final key = SyncPayload.key(type, id);
    final revisions = await _revisions();
    final before = SyncGraph(revisions);
    final pending = revisions
        .where((r) => r.key == key && before.pending.contains(r.id))
        .toList();
    final basis = {
      ...(before.heads[key] ?? []).map((r) => r.id),
      ...pending.map((r) => r.id),
    };
    if (pending.isEmpty ||
        basis.length != expectedRevisions.length ||
        !basis.containsAll(expectedRevisions)) {
      throw StateError('Pending revisions changed; reload before repairing.');
    }
    _assertSnapshot(await _snapshot(), before);
    final revision = SyncRevision(
      id: const Uuid().v4(),
      deviceId: local.deviceId,
      entityId: id,
      entityType: type,
      parents: basis,
      payload: payload,
      schemaVersion: 3,
    );
    final after = SyncGraph([...revisions, revision]);
    if (!after.applied.contains(revision.id)) {
      throw StateError('Repair still has unresolved dependencies.');
    }
    await _insert(revision);
    await _materialize(after);
    await _saveProjection(after, [...revisions, revision]);
  });
  Future<void> _ensureTagIds() async {
    for (final row in await (db.select(
      db.tags,
    )..where((t) => t.syncId.isNull())).get()) {
      await (db.update(db.tags)..where((t) => t.id.equals(row.id))).write(
        TagsCompanion(syncId: Value(const Uuid().v4())),
      );
    }
  }

  Future<Map<String, String>> _snapshot() async {
    final tags = {
      for (final tag in await db.select(db.tags).get()) tag.id: tag.toDomain(),
    };
    final entries = await db.select(db.taskTagEntries).get();
    return {
      for (final row in await db.select(db.tasks).get())
        row.id: TaskSyncCodec.encode(
          row.toDomain(
            tags: entries
                .where((e) => e.taskId == row.id)
                .map((e) => tags[e.tagId]!)
                .toList(),
          ),
        ),
      for (final row in await db.select(db.workLogs).get())
        'workLog/${row.id}': WorkLogSyncCodec.encode(row.toDomain()),
      for (final row in await db.select(db.projects).get())
        'project/${row.id}': HierarchySyncCodec.project(row.toDomain()),
      for (final row in await db.select(db.goals).get())
        'goal/${row.id}': HierarchySyncCodec.goal(row.toDomain()),
      for (final row in await db.select(db.spheres).get())
        'sphere/${row.id}': HierarchySyncCodec.sphere(row.toDomain()),
      for (final tag in tags.values)
        'tag/${tag.syncId}': HierarchySyncCodec.tag(tag),
    };
  }

  void _assertSnapshot(Map<String, String> snapshot, SyncGraph graph) {
    for (final key in {...snapshot.keys, ...graph.heads.keys}) {
      if (snapshot[key] != graph.winner(key)?.payload) {
        throw StateError(
          'Untracked local changes; refusing to overwrite $key.',
        );
      }
    }
  }

  void _checkEdit(
    String key,
    SyncGraph graph,
    List<SyncRevision> revisions, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
    bool resolveConflict = false,
  }) {
    final versions = graph.heads[key] ?? [];
    if ((!resolveConflict && versions.length > 1) ||
        revisions.any((r) => r.key == key && graph.pending.contains(r.id))) {
      throw StateError(
        'Resolve pending revisions and conflicts before editing.',
      );
    }
    if (createOnly &&
        (versions.isNotEmpty || revisions.any((r) => r.key == key))) {
      throw StateError('Entity ID already exists.');
    }
    if (requireExpected &&
        (expectedRevision == null ||
            versions.length != 1 ||
            versions.single.id != expectedRevision)) {
      throw StateError('Entity changed; reload before saving.');
    }
  }

  Future<T> _capture<T>(Future<T> Function() write, {String? resolving}) =>
      db.transaction(() async {
        if (Zone.current[_captureZone] == true) return write();
        final local = await db.select(db.syncIdentities).getSingleOrNull();
        if (local == null) return write();
        final revisions = await _revisions();
        final beforeGraph = SyncGraph(revisions);
        final before = await _snapshot();
        _assertSnapshot(before, beforeGraph);

        final result = await runZoned(write, zoneValues: {_captureZone: true});
        await _ensureTagIds();
        final after = await _snapshot();
        final changed =
            {...before.keys, ...after.keys, ?resolving}
                .where(
                  (key) =>
                      before[key] != after[key] ||
                      (key == resolving &&
                          (beforeGraph.heads[key]?.length ?? 0) > 1),
                )
                .toList()
              ..sort();
        final ids = {for (final key in changed) key: const Uuid().v4()};
        final groupId = changed.length > 1 ? const Uuid().v4() : null;
        final added = <SyncRevision>[];
        for (final key in changed) {
          _checkEdit(
            key,
            beforeGraph,
            revisions,
            resolveConflict: key == resolving,
          );
          final versions = beforeGraph.heads[key] ?? [];
          if (versions.any((r) => r.deleted) && after[key] != null) {
            throw StateError('Restore with a new entity ID.');
          }
          final type = SyncPayload.typeOf(key);
          added.add(
            SyncRevision(
              id: ids[key]!,
              deviceId: local.deviceId,
              entityId: SyncPayload.idOf(key),
              entityType: type,
              parents: versions.map((r) => r.id),
              payload: after[key],
              schemaVersion: _version(
                type,
                after[key],
                grouped: groupId != null,
              ),
              groupId: groupId,
              groupMembers: groupId == null ? [] : ids.values,
            ),
          );
        }
        final graph = SyncGraph([...revisions, ...added]);
        if (added.any((r) => !graph.applied.contains(r.id))) {
          throw StateError(
            'Mutation would leave a missing dependency or hierarchy cycle.',
          );
        }
        _assertSnapshot(after, graph);
        for (final r in added) {
          await _insert(r);
        }
        if (added.isNotEmpty) {
          await _saveProjection(graph, [...revisions, ...added]);
        }
        return result;
      });

  @override
  Future<T> trackTask<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) => db.transaction(() async {
    if (Zone.current[_captureZone] == true ||
        await db.select(db.syncIdentities).getSingleOrNull() == null) {
      return write();
    }
    final revisions = await _revisions();
    _checkEdit(
      id,
      SyncGraph(revisions),
      revisions,
      expectedRevision: expectedRevision,
      requireExpected: requireExpected,
      createOnly: createOnly,
    );
    return _capture(write);
  });

  @override
  Future<T> trackWorkLog<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) => trackTask(
    'workLog/$id',
    write,
    expectedRevision: expectedRevision,
    requireExpected: requireExpected,
    createOnly: createOnly,
  );

  @override
  Future<T> trackGraph<T>(Future<T> Function() write) => _capture(write);

  Future<String?> _statusPayload(String type, String id) async {
    if (type == 'workLog') {
      final row = await (db.select(
        db.workLogs,
      )..where((row) => row.id.equals(id))).getSingleOrNull();
      return row == null ? null : WorkLogSyncCodec.encode(row.toDomain());
    }
    final task = await (db.select(
      db.tasks,
    )..where((row) => row.id.equals(id))).getSingleOrNull();
    if (task == null) return null;
    final tags = await (db.select(db.tags).join([
      innerJoin(
        db.taskTagEntries,
        db.tags.id.equalsExp(db.taskTagEntries.tagId),
      ),
    ])..where(db.taskTagEntries.taskId.equals(id))).get();
    return TaskSyncCodec.encode(
      task.toDomain(
        tags: tags.map((row) => row.readTable(db.tags).toDomain()).toList(),
      ),
    );
  }

  @override
  Future<void> trackStatus(
    String type,
    String id,
    Future<void> Function() write,
  ) => db.transaction(() async {
    if (type != 'task' && type != 'workLog') {
      throw ArgumentError.value(type, 'type');
    }
    if (Zone.current[_captureZone] == true) return write();
    final local = await existingIdentity();
    if (local == null) return write();
    final key = SyncPayload.key(type, id);
    final marker = await _ensureProjection();
    final head = await _projectedHead(key);
    if (head?.blocked == true) {
      throw StateError(
        'Resolve pending revisions and conflicts before editing.',
      );
    }
    final before = await _statusPayload(type, id);
    if (head?.payload != before) {
      throw StateError('Untracked local changes; refusing to overwrite $key.');
    }
    if (before == null) return;
    if (marker.blocked) return _capture(write);
    await write();
    final after = await _statusPayload(type, id);
    if (after == before) return;
    String withoutStatus(String payload) {
      final fields = jsonDecode(payload) as Map<String, dynamic>;
      fields.remove('status');
      if (type == 'task') fields.remove('updatedAt');
      return jsonEncode(fields);
    }

    if (after == null || withoutStatus(before) != withoutStatus(after)) {
      throw StateError('Status command changed other fields of $key.');
    }
    final revision = SyncRevision(
      id: const Uuid().v4(),
      deviceId: local.deviceId,
      entityId: id,
      entityType: type,
      parents: [head!.revisionId!],
      payload: after,
      schemaVersion: _version(type, after),
    );
    await _insert(revision);
    await db
        .into(db.syncEntityHeads)
        .insertOnConflictUpdate(
          head.copyWith(revisionId: Value(revision.id), payload: Value(after)),
        );
    await db.into(db.syncEntityHeads).insert(marker);
  });

  Future<void> initialize(
    String datasetId, {
    String? deviceId,
  }) => db.transaction(() async {
    if (datasetId.isEmpty || datasetId.length > 128) {
      throw ArgumentError.value(datasetId, 'datasetId');
    }
    final existing = await db.select(db.syncIdentities).getSingleOrNull();
    if (existing != null && existing.datasetId != datasetId) {
      throw StateError('Dataset cannot change.');
    }
    await _ensureTagIds();
    final snapshot = await _snapshot();
    final installationId = existing?.deviceId ?? deviceId ?? const Uuid().v4();
    if (existing == null) {
      await db
          .into(db.syncIdentities)
          .insert(
            SyncIdentitiesCompanion.insert(
              datasetId: datasetId,
              deviceId: installationId,
            ),
          );
    }
    final old = await _revisions();
    final before = SyncGraph(old);
    final added = <SyncRevision>[];
    for (final entry in snapshot.entries) {
      if (before.winner(entry.key)?.payload == entry.value) continue;
      if (old.any((r) => r.key == entry.key) ||
          (existing != null &&
              ['task', 'workLog'].contains(SyncPayload.typeOf(entry.key)))) {
        throw StateError('Untracked changes during enrollment upgrade.');
      }
      final type = SyncPayload.typeOf(entry.key);
      added.add(
        SyncRevision(
          id: const Uuid().v4(),
          deviceId: installationId,
          entityId: SyncPayload.idOf(entry.key),
          entityType: type,
          parents: [],
          payload: entry.value,
          schemaVersion: 3,
        ),
      );
    }
    final graph = SyncGraph([...old, ...added]);
    if (added.any((r) => !graph.applied.contains(r.id))) {
      throw StateError(
        'Invalid bootstrap relationships or duplicate tag names.',
      );
    }
    _assertSnapshot(snapshot, graph);
    for (final r in added) {
      await _insert(r);
    }
    await _saveProjection(graph, [...old, ...added]);
  });
  @override
  Future<SyncIdentity> identity() async {
    final row = await db.select(db.syncIdentities).getSingle();
    return SyncIdentity(row.datasetId, row.deviceId);
  }

  Future<void> _insert(SyncRevision r) async {
    r.validate();
    await db
        .into(db.syncRevisions)
        .insert(
          SyncRevisionsCompanion.insert(revisionId: r.id, body: r.encode()),
        );
  }

  Future<void> saveTask(
    Task task, {
    required Set<String> expectedHeads,
    bool resolveConflict = false,
  }) => _write(
    task.id,
    TaskSyncCodec.encode(task),
    expectedHeads: expectedHeads,
    resolveConflict: resolveConflict,
  );
  Future<void> saveEntity(
    String type,
    String payload, {
    required Set<String> expectedHeads,
    bool resolveConflict = false,
  }) => _write(
    SyncPayload.key(type, SyncPayload.payloadId(type, payload)),
    payload,
    expectedHeads: expectedHeads,
    resolveConflict: resolveConflict,
  );
  Future<void> deleteEntity(
    String type,
    String id, {
    required Set<String> expectedHeads,
    bool resolveConflict = false,
  }) => _write(
    SyncPayload.key(type, id),
    null,
    expectedHeads: expectedHeads,
    resolveConflict: resolveConflict,
  );
  Future<void> deleteTask(
    String id, {
    required Set<String> expectedHeads,
    bool resolveConflict = false,
  }) => _write(
    id,
    null,
    expectedHeads: expectedHeads,
    resolveConflict: resolveConflict,
  );
  Future<void> saveWorkLog(
    WorkLog log, {
    required Set<String> expectedHeads,
    bool resolveConflict = false,
  }) => _write(
    'workLog/${log.id}',
    WorkLogSyncCodec.encode(log),
    expectedHeads: expectedHeads,
    resolveConflict: resolveConflict,
  );
  Future<void> deleteWorkLog(
    String id, {
    required Set<String> expectedHeads,
    bool resolveConflict = false,
  }) => _write(
    'workLog/$id',
    null,
    expectedHeads: expectedHeads,
    resolveConflict: resolveConflict,
  );
  Future<void> completeTask(String id, {required Set<String> expectedHeads}) =>
      db.transaction(() async {
        final row = await (db.select(
          db.tasks,
        )..where((r) => r.id.equals(id))).getSingle();
        await saveTask(
          row.toDomain().copyWith(
            status: TaskStatus.done,
            updatedAt: row.status == TaskStatus.done
                ? row.updatedAt
                : DateTime.now(),
          ),
          expectedHeads: expectedHeads,
        );
      });
  Future<void> _write(
    String id,
    String? payload, {
    required Set<String> expectedHeads,
    required bool resolveConflict,
  }) => db.transaction(() async {
    await identity();
    final revisions = await _revisions();
    final graph = SyncGraph(revisions);
    final versions = graph.heads[id] ?? [];
    final actual = versions.map((r) => r.id).toSet();
    if (actual.length != expectedHeads.length ||
        !actual.containsAll(expectedHeads)) {
      throw StateError('Entity changed; reload.');
    }
    _checkEdit(id, graph, revisions, resolveConflict: resolveConflict);
    await _capture(() async {
      await _applyPayload(
        SyncPayload.typeOf(id),
        SyncPayload.idOf(id),
        payload,
      );
    }, resolving: resolveConflict ? id : null);
  });

  Future<void> _applyPayload(String type, String id, String? payload) async {
    if (payload != null && SyncPayload.payloadId(type, payload) != id) {
      throw const FormatException('Wrong entity ID.');
    }
    if (type == 'task') {
      if (payload == null) {
        await (db.delete(db.tasks)..where((r) => r.id.equals(id))).go();
      } else {
        final task = TaskSyncCodec.decode(payload);
        await db.into(db.tasks).insertOnConflictUpdate(task.toDrift());
        await (db.delete(
          db.taskTagEntries,
        )..where((e) => e.taskId.equals(id))).go();
        for (final tag in task.tags) {
          final row = await (db.select(
            db.tags,
          )..where((t) => t.syncId.equals(tag.syncId!))).getSingle();
          await db
              .into(db.taskTagEntries)
              .insert(
                TaskTagEntriesCompanion.insert(taskId: id, tagId: row.id),
              );
        }
      }
    } else if (type == 'workLog') {
      if (payload == null) {
        await (db.delete(db.workLogs)..where((r) => r.id.equals(id))).go();
      } else {
        await db
            .into(db.workLogs)
            .insertOnConflictUpdate(
              WorkLogSyncCodec.decode(payload).toCompanion(),
            );
      }
    } else if (type == 'project') {
      if (payload == null) {
        await (db.delete(db.projects)..where((r) => r.id.equals(id))).go();
      } else {
        await db
            .into(db.projects)
            .insertOnConflictUpdate(
              HierarchySyncCodec.decodeProject(payload).toDrift(),
            );
      }
    } else if (type == 'goal') {
      if (payload == null) {
        await (db.delete(db.goals)..where((r) => r.id.equals(id))).go();
      } else {
        final goal = HierarchySyncCodec.decodeGoal(payload);
        await db
            .into(db.goals)
            .insertOnConflictUpdate(
              goal.toDrift().copyWith(
                sphereId: Value(goal.sphereId.isEmpty ? null : goal.sphereId),
              ),
            );
      }
    } else if (type == 'sphere') {
      if (payload == null) {
        await (db.delete(db.spheres)..where((r) => r.id.equals(id))).go();
      } else {
        await db
            .into(db.spheres)
            .insertOnConflictUpdate(
              HierarchySyncCodec.decodeSphere(payload).toDrift(),
            );
      }
    } else if (type == 'tag') {
      if (payload == null) {
        await (db.delete(db.tags)..where((r) => r.syncId.equals(id))).go();
      } else {
        final tag = HierarchySyncCodec.decodeTag(payload);
        final existing = await (db.select(
          db.tags,
        )..where((r) => r.syncId.equals(id))).getSingleOrNull();
        if (existing == null) {
          await db
              .into(db.tags)
              .insert(
                TagsCompanion.insert(
                  name: tag.name,
                  colorHex: tag.colorHex,
                  syncId: Value(id),
                ),
              );
        } else {
          await (db.update(
            db.tags,
          )..where((r) => r.id.equals(existing.id))).write(
            TagsCompanion(name: Value(tag.name), colorHex: Value(tag.colorHex)),
          );
        }
      }
    } else {
      throw const FormatException('Unknown entity type.');
    }
  }

  Future<void> _materialize(SyncGraph graph) async {
    final live = <String, SyncRevision>{
      for (final key in graph.heads.keys)
        if (!graph.winner(key)!.deleted) key: graph.winner(key)!,
    };
    for (final type in [
      'sphere',
      'goal',
      'project',
      'tag',
      'task',
      'workLog',
    ]) {
      for (final revision in live.values.where((r) => r.entityType == type)) {
        await _applyPayload(type, revision.entityId, revision.payload);
      }
    }
    // The snapshot contains local integer tag IDs only while building portable keys.
    final local = await _snapshot();
    for (final type in [
      'workLog',
      'task',
      'project',
      'goal',
      'sphere',
      'tag',
    ]) {
      for (final key in local.keys.where(
        (k) => SyncPayload.typeOf(k) == type && !live.containsKey(k),
      )) {
        await _applyPayload(type, SyncPayload.idOf(key), null);
      }
    }
  }

  @override
  Future<SyncBatch> readFeed({int after = 0, int limit = 100}) =>
      db.transaction(() async {
        if (after < 0 || limit < 1 || limit > 100) {
          throw ArgumentError('Invalid feed range.');
        }
        final local = await identity();
        _assertSnapshot(await _snapshot(), await state());
        final rows =
            await (db.select(db.syncRevisions)
                  ..where((r) => r.sequence.isBiggerThanValue(after))
                  ..orderBy([(r) => OrderingTerm.asc(r.sequence)])
                  ..limit(limit))
                .get();
        final entries = <SyncEntry>[];
        var bytes = 0;
        for (final row in rows) {
          bytes += utf8.encode(row.body).length;
          if (bytes > 4 * 1024 * 1024) break;
          entries.add(SyncEntry(row.sequence, SyncRevision.decode(row.body)));
        }
        return SyncBatch(local, after, entries);
      });
  @override
  Future<int> receivedCursor(String deviceId) async =>
      (await (db.select(
            db.syncCursors,
          )..where((r) => r.deviceId.equals(deviceId))).getSingleOrNull())
          ?.cursor ??
      0;
  @override
  Future<void> receive(SyncBatch batch) => db.transaction(() async {
    final local = await identity();
    if (local.datasetId != batch.source.datasetId ||
        local.deviceId == batch.source.deviceId ||
        batch.source.deviceId.isEmpty ||
        batch.source.deviceId.length > 128) {
      throw StateError('Wrong dataset or device identity.');
    }
    if (batch.after < 0 || batch.entries.length > 100) {
      throw const FormatException('Invalid batch.');
    }
    final cursor = await receivedCursor(batch.source.deviceId);
    if (batch.after > cursor) throw StateError('Missing feed range.');
    final old = await _revisions();
    final byId = {for (final r in old) r.id: r};
    final added = <SyncRevision>[];
    var sequence = batch.after;
    var bytes = 0;
    for (final entry in batch.entries) {
      if (entry.sequence != ++sequence) {
        throw const FormatException('Noncontiguous feed.');
      }
      final r = entry.revision;
      r.validate();
      bytes += utf8.encode(r.encode()).length;
      if (bytes > 4 * 1024 * 1024) {
        throw const FormatException('Batch too large.');
      }
      final existing = byId[r.id];
      if (existing != null) {
        if (existing.encode() != r.encode()) {
          throw const FormatException('Revision ID collision.');
        }
      } else {
        if (entry.sequence <= cursor) {
          throw const FormatException('Changed acknowledged feed.');
        }
        byId[r.id] = r;
        added.add(r);
      }
    }
    final before = SyncGraph(old);
    final after = SyncGraph(byId.values);
    _assertSnapshot(await _snapshot(), before);
    for (final r in added) {
      await _insert(r);
    }
    // Rebuild only when the projection changed; pending deliveries do not touch data.
    if (jsonEncode({
          for (final k in before.heads.keys) k: before.winner(k)?.payload,
        }) !=
        jsonEncode({
          for (final k in after.heads.keys) k: after.winner(k)?.payload,
        })) {
      await _materialize(after);
    }
    if (added.isNotEmpty) {
      await _saveProjection(after, byId.values);
    }
    await db
        .into(db.syncCursors)
        .insertOnConflictUpdate(
          SyncCursorsCompanion.insert(
            deviceId: batch.source.deviceId,
            cursor: batch.cursor > cursor ? batch.cursor : cursor,
          ),
        );
  });
}
