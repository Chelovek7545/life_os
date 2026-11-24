import 'canvas_placement_sync_codec.dart';
import 'canvas_board_sync_codec.dart';
import 'hierarchy_sync_codec.dart';
import 'habit_sync_codec.dart';
import 'markdown_sync_codec.dart';
import 'sticker_sync_codec.dart';
import 'task_sync_codec.dart';
import 'work_log_sync_codec.dart';

class SyncPayload {
  static const types = [
    'task',
    'workLog',
    'project',
    'goal',
    'sphere',
    'tag',
    'habit',
    'habitEntry',
    'note',
    'sticker',
    'canvasNode',
    'canvasBoard',
  ];
  static const schema5Types = {'habit', 'habitEntry', 'note'};
  static const externalNotes = {'note', 'sticker'};
  static const externalEntities = {
    ...externalNotes,
    'canvasNode',
    'canvasBoard',
  };
  static const canvasTypes = {'canvasNode', 'canvasBoard'};
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
    'habit' => HabitSyncCodec.decodeHabit(text).id,
    'habitEntry' => HabitSyncCodec.decodeEntry(text).id,
    'note' => MarkdownSyncNote.decode(text).id,
    'sticker' => SyncSticker.decode(text).id,
    'canvasNode' => SyncCanvasPlacement.decode(text).id,
    'canvasBoard' => SyncCanvasBoard.decode(text).id,
    _ => throw const FormatException('Unsupported entity type.'),
  };
  static List<String> dependencies(String type, String text) {
    if (type == 'habitEntry') {
      return [key('habit', HabitSyncCodec.decodeEntry(text).habitId)];
    }
    if (type == 'task') {
      final t = TaskSyncCodec.decode(text);
      if (t.parentTaskId != null && typeOf(t.parentTaskId!) != 'task') {
        throw const FormatException('Task parent must be a task ID.');
      }
      if (t.predecessorTaskId != null &&
          typeOf(t.predecessorTaskId!) != 'task') {
        throw const FormatException('Task predecessor must be a task ID.');
      }
      return [
        if (t.parentTaskId != null) t.parentTaskId!,
        if (t.predecessorTaskId != null) t.predecessorTaskId!,
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
