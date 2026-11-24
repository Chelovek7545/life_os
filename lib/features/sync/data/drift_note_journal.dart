part of 'drift_sync_store.dart';

typedef ExternalNoteSnapshot = ({
  String scope,
  String? idPrefix,
  Map<String, String> payloads,
  bool captureDeletes,
});

extension DriftNoteJournal on DriftSyncStore {
  Future<List<({String scope, SyncRevision target})>> stageExternalNotes(
    String type,
    List<ExternalNoteSnapshot> snapshots, {
    Set<String> adoptUntrackedBoards = const {},
  }) => db.transaction(() async {
    if (snapshots.isEmpty) return [];
    final local = await identity();
    final revisions = await _revisions();
    final graph = SyncGraph(revisions);
    final notes = {
      for (final revision in revisions)
        if (revision.entityType == type) revision.id: revision,
    };
    final checkpoints = <String, Map<String, String>>{};
    final rows = await (db.select(
      db.syncNoteCheckpoints,
    )..where((row) => row.scope.isIn(snapshots.map((s) => s.scope)))).get();
    for (final row in rows) {
      checkpoints.putIfAbsent(row.scope, () => {})[row.noteId] = row.revisionId;
    }
    final headIds = [
      for (final key in graph.heads.keys)
        if (SyncPayload.typeOf(key) == type) SyncPayload.idOf(key),
    ];
    final idsByScope = {
      for (final snapshot in snapshots)
        snapshot.scope: {
          ...snapshot.payloads.keys,
          ...headIds.where(
            (id) =>
                snapshot.idPrefix == null || id.startsWith(snapshot.idPrefix!),
          ),
        },
    };
    final additions = <SyncRevision>[];
    final uncheckedBoards = <String, Set<String>>{};
    for (final snapshot in snapshots) {
      for (final id in idsByScope[snapshot.scope]!) {
        final current = snapshot.payloads[id];
        final heads = graph.heads[SyncPayload.key(type, id)] ?? const [];
        final baseline = notes[checkpoints[snapshot.scope]?[id]];
        final matching = heads.where(
          (head) => _matchesNote(type, current, head.payload),
        );
        if (matching.isNotEmpty) {
          if (baseline == null || !matching.contains(baseline)) {
            if (type == 'canvasBoard') {
              // The file may already be written after an interrupted import.
              // Retry refreshing the catalog before advancing its checkpoint.
              uncheckedBoards.putIfAbsent(snapshot.scope, () => {}).add(id);
            } else {
              await checkpointNote(snapshot.scope, matching.first);
            }
          }
        } else if (!(baseline == null &&
                heads.isNotEmpty &&
                adoptUntrackedBoards.contains(snapshot.scope)) &&
            (current != null || snapshot.captureDeletes && baseline != null) &&
            !_matchesNote(type, current, baseline?.payload)) {
          final revision = SyncRevision(
            id: const Uuid().v4(),
            deviceId: local.deviceId,
            entityId: id,
            entityType: type,
            parents: [
              ?baseline?.id,
              if (SyncPayload.canvasTypes.contains(type) && baseline != null)
                ...heads
                    .where(
                      (head) =>
                          head.id != baseline.id &&
                          head.payload == baseline.payload,
                    )
                    .take(63)
                    .map((head) => head.id),
            ],
            payload: current,
            schemaVersion: DriftSyncStore._version(type, current),
          );
          additions.add(revision);
          await checkpointNote(snapshot.scope, revision);
        }
      }
    }

    final after = additions.isEmpty
        ? graph
        : await _appendNotes(revisions, additions);
    final pendingKeys = {
      for (final revision in notes.values)
        if (after.pending.contains(revision.id)) revision.key,
    };
    return [
      for (final snapshot in snapshots)
        for (final id in idsByScope[snapshot.scope]!)
          if ((SyncPayload.canvasTypes.contains(type)
                  ? after.winner(SyncPayload.key(type, id))
                  : after.heads[SyncPayload.key(type, id)]?.singleOrNull)
              case final target?
              when !pendingKeys.contains(target.key) &&
                  (uncheckedBoards[snapshot.scope]?.contains(id) == true ||
                      !_matchesNote(
                        type,
                        snapshot.payloads[id],
                        target.payload,
                      )))
            (scope: snapshot.scope, target: target),
    ];
  });

  // Path spelling can differ on case-insensitive file systems.
  bool _matchesNote(String type, String? current, String? payload) {
    if (current == payload) return true;
    if (current == null || payload == null) return false;
    if (type == 'note') {
      return MarkdownSyncNote.decode(current).text ==
          MarkdownSyncNote.decode(payload).text;
    }
    if (type != 'sticker') return false;
    final a = SyncSticker.decode(current);
    final b = SyncSticker.decode(payload);
    return a.markdownPath != null &&
        b.markdownPath != null &&
        a.markdownPath!.toLowerCase() == b.markdownPath!.toLowerCase() &&
        (a.x, a.y, a.width, a.height) == (b.x, b.y, b.width, b.height);
  }

  Future<void> checkpointNote(String scope, SyncRevision revision) async {
    await db
        .into(db.syncNoteCheckpoints)
        .insertOnConflictUpdate(
          SyncNoteCheckpoint(
            scope: scope,
            noteId: revision.entityId,
            revisionId: revision.id,
          ),
        );
  }

  Future<SyncGraph> _appendNotes(
    List<SyncRevision> revisions,
    List<SyncRevision> additions,
  ) async {
    final all = [...revisions, ...additions];
    final graph = SyncGraph(all);
    if (additions.any((revision) => !graph.applied.contains(revision.id))) {
      throw StateError('Note revisions are not yet applicable.');
    }
    for (final revision in additions) {
      await _insert(revision);
    }
    await _saveProjection(graph, all);
    return graph;
  }

  Future<void> _resolveNote(SyncRevision chosen, Set<String> expected) =>
      db.transaction(() async {
        final local = await identity();
        final revisions = await _revisions();
        final graph = SyncGraph(revisions);
        final versions = graph.heads[chosen.key] ?? const [];
        final parents = versions.map((revision) => revision.id).toSet();
        if (parents.length != expected.length ||
            !parents.containsAll(expected) ||
            !versions.any((revision) => revision.encode() == chosen.encode())) {
          throw const LocalSyncException(
            'Запись изменилась. Откройте конфликт заново.',
          );
        }
        _checkEdit(chosen.key, graph, revisions, resolveConflict: true);
        await _appendNotes(revisions, [
          SyncRevision(
            id: const Uuid().v4(),
            deviceId: local.deviceId,
            entityId: chosen.entityId,
            entityType: chosen.entityType,
            parents: parents,
            payload: chosen.payload,
            schemaVersion: DriftSyncStore._version(
              chosen.entityType,
              chosen.payload,
            ),
          ),
        ]);
      });
}
