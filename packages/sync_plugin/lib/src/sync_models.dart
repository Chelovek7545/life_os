import 'dart:convert';
import 'task_sync_codec.dart';
import 'hierarchy_sync_codec.dart';
import 'sync_payload.dart';

class SyncRevision {
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
    if (schemaVersion < 1 || schemaVersion > 4) {
      throw UnsupportedError('Unknown sync schema.');
    }
    if (!SyncPayload.types.contains(entityType) ||
        SyncPayload.types
            .skip(1)
            .any((type) => entityId.startsWith('$type/')) ||
        (schemaVersion < 3 && !['task', 'workLog'].contains(entityType)) ||
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
        (utf8.encode(payload!).length > 1024 * 1024 ||
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
        if (parent != null && parent.deleted && !r.deleted) {
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

abstract interface class SyncStore {
  Future<SyncIdentity> identity();
  Future<SyncBatch> readFeed({int after = 0, int limit = 100});
  Future<int> receivedCursor(String deviceId);
  Future<void> receive(SyncBatch batch);
}

class SyncEngine {
  // A transport-independent session. Network authentication belongs to stage 3.
  Future<void> exchange(SyncStore a, SyncStore b) async {
    await _transfer(a, b);
    await _transfer(b, a);
  }

  Future<void> _transfer(SyncStore source, SyncStore target) async {
    var cursor = await target.receivedCursor(
      (await source.identity()).deviceId,
    );
    while (true) {
      final batch = await source.readFeed(after: cursor);
      if (batch.entries.isEmpty) return;
      await target.receive(batch);
      cursor = batch.cursor;
    }
  }
}
