import 'hierarchy_sync_codec.dart';
import 'task_sync_codec.dart';
import 'work_log_sync_codec.dart';

class SyncPayload {
  static const types = ['task', 'workLog', 'project', 'goal', 'sphere', 'tag'];
  static String key(String type, String id) {
    if (!types.contains(type)) {
      throw const FormatException('Unsupported entity type.');
    }
    return type == 'task' ? id : '$type/$id';
  }

  static String typeOf(String key) {
    for (final type in types.skip(1)) {
      if (key.startsWith('$type/')) return type;
    }
    return 'task';
  }

  static String idOf(String key) =>
      typeOf(key) == 'task' ? key : key.substring(key.indexOf('/') + 1);
  static String payloadId(String type, String text) => switch (type) {
    'task' => TaskSyncCodec.decode(text).id,
    'workLog' => WorkLogSyncCodec.decode(text).id,
    'project' => HierarchySyncCodec.decodeProject(text).id,
    'goal' => HierarchySyncCodec.decodeGoal(text).id,
    'sphere' => HierarchySyncCodec.decodeSphere(text).id,
    'tag' => HierarchySyncCodec.decodeTag(text).syncId!,
    _ => throw const FormatException('Unsupported entity type.'),
  };
  static List<String> dependencies(String type, String text) {
    if (type == 'task') {
      final t = TaskSyncCodec.decode(text);
      if (t.parentTaskId != null && typeOf(t.parentTaskId!) != 'task') {
        throw const FormatException('Task parent must be a task ID.');
      }
      return [
        if (t.parentTaskId != null) t.parentTaskId!,
        if (t.projectId != null) 'project/${t.projectId}',
        for (final tag in t.tags) 'tag/${tag.syncId}',
      ];
    }
    if (type == 'workLog') {
      final id = WorkLogSyncCodec.decode(text).taskId;
      if (typeOf(id) != 'task') {
        throw const FormatException('Work log owner must be a task ID.');
      }
      return [id];
    }
    if (type == 'project') {
      final p = HierarchySyncCodec.decodeProject(text);
      return [
        if (p.parentProejectId != null) 'project/${p.parentProejectId}',
        if (p.goalId != null) 'goal/${p.goalId}',
      ];
    }
    if (type == 'goal') {
      final g = HierarchySyncCodec.decodeGoal(text);
      return [if (g.sphereId.isNotEmpty) 'sphere/${g.sphereId}'];
    }
    return [];
  }

  static String? hierarchyParent(String type, String text) {
    if (type == 'task') return TaskSyncCodec.decode(text).parentTaskId;
    if (type == 'project') {
      final parent = HierarchySyncCodec.decodeProject(text).parentProejectId;
      return parent == null ? null : 'project/$parent';
    }
    return null;
  }
}
