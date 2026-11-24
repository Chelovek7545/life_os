import 'dart:convert';
import 'dart:math' show min;
import 'task_sync_codec.dart';
import 'hierarchy_sync_codec.dart';
import 'sync_payload.dart';
import 'sticker_sync_codec.dart';

class SyncRevision {
  static const supportedSchema = 9;
  static const maxPayloadBytes = 1024 * 1024;

  SyncRevision({
    required this.id,
    required this.deviceId,
    required this.entityId,
    required Iterable<String> parents,
    required this.payload,
    this.schemaVersion = 1,
    this.entityType = 'task',
    this.groupId,
    Iterable<String> groupMembers = const [],
  }) : parents = List.unmodifiable(parents.toList()..sort()),
       groupMembers = List.unmodifiable(groupMembers.toList()..sort());
  final String id;
  final String deviceId;
  final String entityId;
  final List<String> parents;
  final String? payload;
  final int schemaVersion;
  final String entityType;
  final String? groupId;
  final List<String> groupMembers;
  String get key => SyncPayload.key(entityType, entityId);
  bool get deleted => payload == null;

  void validate() {
    if (schemaVersion < 1 || schemaVersion > supportedSchema) {
      throw UnsupportedError('Unknown sync schema.');
    }
    if (!SyncPayload.types.contains(entityType) ||
        SyncPayload.types
            .skip(1)
            .any((type) => entityId.startsWith('$type/')) ||
        (schemaVersion < 3 && !['task', 'workLog'].contains(entityType)) ||
        (schemaVersion < 5 && SyncPayload.schema5Types.contains(entityType)) ||
        (schemaVersion < 6 && entityType == 'sticker') ||
        (entityType == 'canvasNode' &&
            (schemaVersion < 8 || payload == null)) ||
        (entityType == 'canvasBoard' &&
            (schemaVersion < 9 || payload == null)) ||
        (schemaVersion == 1 &&
            (entityType != 'task' ||
                groupId != null ||
                groupMembers.isNotEmpty))) {
      throw const FormatException('Invalid revision type.');
    }
    if (groupId == null
        ? groupMembers.isNotEmpty
        : groupId!.isEmpty ||
              groupId!.length > 128 ||
              groupMembers.length < 2 ||
              groupMembers.length > 1000 ||
              !groupMembers.contains(id) ||
              groupMembers.toSet().length != groupMembers.length ||
              groupMembers.any((id) => id.isEmpty || id.length > 128)) {
      throw const FormatException('Invalid transaction group.');
    }
    if ([
          id,
          deviceId,
          entityId,
          ...parents,
        ].any((s) => s.isEmpty || s.length > 128) ||
        parents.length > 64 ||
        parents.toSet().length != parents.length ||
        parents.contains(id)) {
      throw const FormatException('Invalid revision identity or parents.');
    }
    if (payload != null &&
        (utf8.encode(payload!).length > maxPayloadBytes ||
            SyncPayload.payloadId(entityType, payload!) != entityId)) {
      throw const FormatException('Invalid revision payload.');
    }
    if (entityType == 'task' && payload != null) {
      final task = TaskSyncCodec.decode(payload!);
      if (schemaVersion < 4 && task.predecessorTaskId != null) {
        throw const FormatException('Task sequences require schema 4.');
      }
      if (schemaVersion < 3 &&
          (task.projectId != null ||
              task.spaceId != null ||
              task.tags.isNotEmpty)) {
        throw const FormatException('Task dependencies require schema 3.');
      }
      if (schemaVersion == 1 && task.parentTaskId != null) {
        throw const FormatException('Task relationships require schema 2.');
      }
    }
    if (entityType == 'sticker' &&
        payload != null &&
        schemaVersion < 7 &&
        SyncSticker.decode(payload!).markdownPath != null) {
      throw const FormatException('Markdown stickers require schema 7.');
    }
  }

  String encode() => jsonEncode({
    'id': id,
    'deviceId': deviceId,
    'entityId': entityId,
    'parents': parents,
    'payload': payload,
    'schemaVersion': schemaVersion,
    if (schemaVersion >= 2) ...{
      'entityType': entityType,
      'groupId': groupId,
      'groupMembers': groupMembers,
    },
  });
  factory SyncRevision.decode(String text) {
    final map = jsonDecode(text) as Map<String, dynamic>;
    final result = SyncRevision(
      id: map['id'] as String,
      deviceId: map['deviceId'] as String,
      entityId: map['entityId'] as String,
      parents: (map['parents'] as List).cast<String>(),
      payload: map['payload'] as String?,
      schemaVersion: map['schemaVersion'] as int,
      entityType: map['entityType'] as String? ?? 'task',
      groupId: map['groupId'] as String?,
      groupMembers: (map['groupMembers'] as List? ?? []).cast<String>(),
    );
    result.validate();
    if (result.encode() != text) {
      throw const FormatException('Noncanonical revision.');
    }
    return result;
  }
}

// Derived from the durable journal; incomplete groups survive restart.
class SyncGraph {
  SyncGraph(Iterable<SyncRevision> revisions) {
    final all = <String, SyncRevision>{};
    for (final r in revisions) {
      r.validate();
      if (all.containsKey(r.id) && all[r.id]!.encode() != r.encode()) {
        throw const FormatException('Revision ID collision.');
      }
      all[r.id] = r;
    }
    final groups = <String, List<SyncRevision>>{};
    String unit(SyncRevision r) =>
        r.groupId == null ? 'single/${r.id}' : 'group/${r.groupId}';
    for (final r in all.values) {
      groups.putIfAbsent(unit(r), () => []).add(r);
      for (final p in r.parents) {
        final parent = all[p];
        if (parent != null && parent.key != r.key) {
          throw const FormatException('Parent belongs to another entity.');
        }
        if (parent != null &&
            parent.deleted &&
            !r.deleted &&
            !SyncPayload.externalNotes.contains(r.entityType)) {
          throw const FormatException('Deleted IDs cannot be restored.');
        }
      }
      for (final id in r.groupMembers) {
        final member = all[id];
        if (member != null &&
            (member.groupId != r.groupId ||
                member.deviceId != r.deviceId ||
                jsonEncode(member.groupMembers) !=
                    jsonEncode(r.groupMembers))) {
          throw const FormatException('Inconsistent transaction group.');
        }
      }
    }
    for (final members in groups.values) {
      if (members.any(
        (r) =>
            r.deviceId != members.first.deviceId ||
            jsonEncode(r.groupMembers) !=
                jsonEncode(members.first.groupMembers),
      )) {
        throw const FormatException(
          'Reused group ID with a different manifest.',
        );
      }
      if (members.map((r) => r.key).toSet().length != members.length) {
        throw const FormatException(
          'Multiple revisions of one entity in a transaction.',
        );
      }
    }
    final unvisited = Map.of(all);
    final visited = <String>{};
    while (unvisited.isNotEmpty) {
      final ready = unvisited.values
          .where(
            (r) => r.parents.every(
              (p) => !all.containsKey(p) || visited.contains(p),
            ),
          )
          .toList();
      if (ready.isEmpty) throw const FormatException('Revision cycle.');
      for (final r in ready) {
        visited.add(r.id);
        unvisited.remove(r.id);
      }
    }
    final blocked = <String>{};
    while (true) {
      heads.clear();
      applied.clear();
      final remaining = Map.of(groups);
      while (true) {
        final ready = remaining.keys.where((id) {
          final members = remaining[id]!;
          return !blocked.contains(id) &&
              (members.first.groupId == null ||
                  members.length == members.first.groupMembers.length) &&
              members.every((r) => r.parents.every(applied.contains));
        }).toList()..sort();
        if (ready.isEmpty) break;
        for (final id in ready) {
          for (final r in remaining.remove(id)!) {
            applied.add(r.id);
            final versions = heads.putIfAbsent(r.key, () => []);
            versions.removeWhere((h) => r.parents.contains(h.id));
            versions.add(r);
          }
        }
      }
      for (final list in heads.values) {
        list.sort((a, b) => a.id.compareTo(b.id));
      }
      final invalid = <String>{};
      final hierarchy = <String, String?>{};
      final sequence = <String, String?>{};
      final alive = {
        for (final key in heads.keys)
          if (!winner(key)!.deleted) key,
      };
      final tagsByName = <String, List<String>>{};
      for (final key in alive) {
        final r = winner(key)!;
        if (SyncPayload.dependencies(
          r.entityType,
          r.payload!,
        ).any((dep) => !alive.contains(dep))) {
          invalid.add(unit(r));
        }
        if (r.entityType == 'task') {
          final task = TaskSyncCodec.decode(r.payload!);
          hierarchy[key] = task.parentTaskId;
          if (task.predecessorTaskId != null) {
            sequence[key] = task.predecessorTaskId;
          }
        } else if (r.entityType == 'project') {
          hierarchy[key] = SyncPayload.hierarchyParent(
            r.entityType,
            r.payload!,
          );
        }
        if (r.entityType == 'tag') {
          tagsByName
              .putIfAbsent(
                HierarchySyncCodec.decodeTag(r.payload!).name,
                () => [],
              )
              .add(key);
        }
      }
      for (final keys in tagsByName.values) {
        if (keys.length > 1) {
          for (final key in keys) {
            invalid.add(unit(winner(key)!));
          }
        }
      }
      for (final links in [hierarchy, sequence]) {
        final checked = <String>{};
        for (final start in links.keys) {
          if (checked.contains(start)) continue;
          final path = <String>{};
          String? next = start;
          while (next != null && !checked.contains(next) && path.add(next)) {
            next = links[next];
          }
          if (next != null && path.contains(next)) {
            for (final key in path.skipWhile((key) => key != next)) {
              invalid.add(unit(winner(key)!));
            }
          }
          checked.addAll(path);
        }
      }
      final added = invalid.difference(blocked);
      if (added.isEmpty) break;
      blocked.addAll(added);
    }
    pending.addAll(all.keys.where((id) => !applied.contains(id)));
  }
  final Map<String, List<SyncRevision>> heads = {};
  final Set<String> applied = {};
  final Set<String> pending = {};
  SyncRevision? winner(String key) {
    final versions = heads[key] ?? [];
    if (versions.isEmpty) return null;
    if (SyncPayload.canvasTypes.contains(versions.first.entityType)) {
      return versions.reduce(
        (a, b) => a.deviceId.compareTo(b.deviceId) <= 0 ? a : b,
      );
    }
    return versions.firstWhere((r) => r.deleted, orElse: () => versions.first);
  }
}

class SyncIdentity {
  const SyncIdentity(this.datasetId, this.deviceId);
  final String datasetId;
  final String deviceId;
}

class SyncEntry {
  const SyncEntry(this.sequence, this.revision);
  final int sequence;
  final SyncRevision revision;
}

class SyncBatch {
  SyncBatch(this.source, this.after, Iterable<SyncEntry> entries)
    : entries = List.unmodifiable(entries);
  final SyncIdentity source;
  final int after;
  final List<SyncEntry> entries;
  int get cursor => entries.isEmpty ? after : entries.last.sequence;
}

enum SyncSection {
  notes,
  tasks,
  projects,
  graph,
  habits;

  static SyncSection forEntity(String type) => switch (type) {
    'note' => notes,
    'task' || 'workLog' || 'tag' => tasks,
    'project' => projects,
    'goal' || 'sphere' || 'sticker' || 'canvasNode' || 'canvasBoard' => graph,
    'habit' || 'habitEntry' => habits,
    _ => throw const FormatException('Unknown sync section.'),
  };
}

class SyncFeedPlan {
  SyncFeedPlan(this.through, Map<SyncSection, int> counts)
    : counts = Map.unmodifiable(counts);

  final int through;
  final Map<SyncSection, int> counts;
}

class SyncTransferProgress {
  SyncTransferProgress(
    Map<SyncSection, int> planned,
    Map<SyncSection, int> transferred,
    Iterable<SyncSection> active,
  ) : planned = Map.unmodifiable(planned),
      transferred = Map.unmodifiable(transferred),
      active = Set.unmodifiable(active);

  final Map<SyncSection, int> planned;
  final Map<SyncSection, int> transferred;
  final Set<SyncSection> active;
  int get total => planned.values.fold(0, (sum, count) => sum + count);
  int get done => transferred.values.fold(0, (sum, count) => sum + count);
}

abstract interface class SyncStore {
  Future<SyncIdentity> identity();
  Future<SyncFeedPlan> planFeed({required int after});
  Future<SyncBatch> readFeed({int after = 0, int limit = 100});
  Future<int> receivedCursor(String deviceId);
  Future<void> receive(SyncBatch batch);
}

class SyncEngine {
  Future<void> exchange(
    SyncStore a,
    SyncStore b, {
    void Function(SyncTransferProgress)? onProgress,
  }) async {
    final outgoing = await b.receivedCursor((await a.identity()).deviceId);
    final incoming = await a.receivedCursor((await b.identity()).deviceId);
    final local = await a.planFeed(after: outgoing);
    final remote = await b.planFeed(after: incoming);
    for (final (cursor, plan) in [(outgoing, local), (incoming, remote)]) {
      if (plan.through < cursor ||
          plan.counts.values.any((count) => count < 0) ||
          plan.counts.values.fold<int>(0, (sum, count) => sum + count) !=
              plan.through - cursor) {
        throw const FormatException('Invalid sync plan.');
      }
    }

    final planned = {
      for (final section in SyncSection.values)
        section: (local.counts[section] ?? 0) + (remote.counts[section] ?? 0),
    };
    final transferred = <SyncSection, int>{};
    void emit(Iterable<SyncSection> active) =>
        onProgress?.call(SyncTransferProgress(planned, transferred, active));

    Future<void> transfer(
      SyncStore source,
      SyncStore target,
      int cursor,
      SyncFeedPlan plan,
    ) async {
      final remaining = Map.of(plan.counts);
      while (cursor < plan.through) {
        final batch = await source.readFeed(
          after: cursor,
          limit: min(100, plan.through - cursor),
        );
        if (batch.entries.isEmpty || batch.cursor > plan.through) {
          throw const FormatException('Incomplete planned sync feed.');
        }
        final counts = <SyncSection, int>{};
        for (final entry in batch.entries) {
          final section = SyncSection.forEntity(entry.revision.entityType);
          counts.update(section, (count) => count + 1, ifAbsent: () => 1);
        }
        for (final entry in counts.entries) {
          final pending = (remaining[entry.key] ?? 0) - entry.value;
          if (pending < 0) throw const FormatException('Sync plan changed.');
          remaining[entry.key] = pending;
        }
        emit(counts.keys);
        await target.receive(batch);
        for (final entry in counts.entries) {
          transferred.update(
            entry.key,
            (count) => count + entry.value,
            ifAbsent: () => entry.value,
          );
        }
        emit(const []);
        cursor = batch.cursor;
      }
    }

    emit(const []);
    await transfer(a, b, outgoing, local);
    await transfer(b, a, incoming, remote);
  }
}
