import 'dart:convert';
import 'package:notes_api/notes_api.dart';

typedef CanvasNodeGeometry = ({
  double x,
  double y,
  double width,
  double height,
});

num _canvasNumber(double value) =>
    value == value.roundToDouble() ? value.round() : value;

Map<String, num> _encodeGeometry(CanvasNodeGeometry value) => {
  'x': _canvasNumber(value.x),
  'y': _canvasNumber(value.y),
  'width': _canvasNumber(value.width),
  'height': _canvasNumber(value.height),
};

CanvasNodeGeometry? _decodeGeometry(Object? value) {
  if (value is! Map ||
      value['x'] is! num ||
      value['y'] is! num ||
      value['width'] is! num ||
      value['height'] is! num)
    return null;
  final x = (value['x'] as num).toDouble();
  final y = (value['y'] as num).toDouble();
  final width = (value['width'] as num).toDouble();
  final height = (value['height'] as num).toDouble();
  if (![x, y, width, height].every((n) => n.isFinite) ||
      width <= 0 ||
      height <= 0) {
    return null;
  }
  return (x: x, y: y, width: width, height: height);
}

class CanvasBoardDocument {
  CanvasBoardDocument(String content) : data = _decode(content);
  final Map<String, dynamic> data;
  List<Map<String, dynamic>> get nodes =>
      (data['nodes'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get edges =>
      (data['edges'] as List).cast<Map<String, dynamic>>();

  void validateScope(String boardId) {
    final metadata = data['pulse'];
    if (metadata is! Map) return;
    final declaredId = metadata['canvasId'] ?? metadata['sphereId'];
    if (declaredId != null && declaredId != boardId) {
      throw const FormatException('Неверный ID канваса.');
    }
    if (metadata['version'] != null && metadata['version'] != 1) {
      throw const FormatException(
        'Неизвестная версия расширения Pulse Canvas.',
      );
    }
  }

  static Map<String, dynamic> _decode(String content) {
    final value = jsonDecode(content);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Canvas: object required');
    }
    value.putIfAbsent('nodes', () => <dynamic>[]);
    value.putIfAbsent('edges', () => <dynamic>[]);
    final entities = <String>{};
    for (final key in ['nodes', 'edges']) {
      if (value[key] is! List) {
        throw FormatException('Canvas: invalid $key');
      }
      final ids = <String>{};
      for (final item in value[key]) {
        if (item is! Map<String, dynamic> ||
            item['id'] is! String ||
            !ids.add(item['id'] as String)) {
          throw FormatException('Canvas: invalid or duplicate $key ID');
        }
        if (key == 'nodes') {
          final pulse = item['pulse'];
          final id = item['id'] as String;
          final entity = pulse is Map && pulse['entityId'] is String
              ? pulse['entityId'] as String
              : id.startsWith('pulse:')
              ? id.substring(6)
              : null;
          if (entity != null && !entities.add(entity)) {
            throw const FormatException(
              'Repeated entity placement is not supported yet',
            );
          }
          for (final field in ['x', 'y', 'width', 'height']) {
            final number = item[field];
            if (number is! num ||
                !number.isFinite ||
                ((field == 'width' || field == 'height') && number <= 0)) {
              throw FormatException('Canvas: invalid $field');
            }
          }
        }
      }
    }
    return value;
  }

  String? entityId(Map<String, dynamic> node) {
    final pulse = node['pulse'];
    if (pulse is Map && pulse['entityId'] is String) {
      return pulse['entityId'] as String;
    }
    final id = node['id'] as String;
    return id.startsWith('pulse:') ? id.substring(6) : null;
  }

  Set<String> get standaloneEntityIds => {
    for (final node in nodes)
      if (node['pulse'] case {'standalone': true})
        if (entityId(node) case final id?) id,
  };

  Set<String> get removedTaskIds {
    final metadata = data['pulse'];
    if (metadata is! Map) return const {};
    if (metadata['removedTaskIds'] case final List ids) {
      return ids.whereType<String>().toSet();
    }
    if (metadata['hiddenTasks'] case final Map legacy) {
      return legacy.keys.whereType<String>().toSet();
    }
    return const {};
  }

  Map<String, CanvasNodeGeometry> get _waitingGeometry {
    final metadata = data['pulse'];
    final waiting = metadata is Map ? metadata['nodeGeometry'] : null;
    return {
      if (waiting is Map)
        for (final entry in waiting.entries)
          if (_decodeGeometry(entry.value) case final value?
              when entry.key is String)
            entry.key as String: value,
    };
  }

  Map<String, CanvasNodeGeometry> get entityGeometry => {
    ..._waitingGeometry,
    for (final node in nodes)
      if (entityId(node) case final id?) id: _decodeGeometry(node)!,
  };

  Map<String, Object?> applyNodeGeometry(
    Map<String, CanvasNodeGeometry> updates,
  ) {
    final waiting = {..._waitingGeometry, ...updates};
    for (final node in nodes) {
      waiting.remove(entityId(node));
    }
    final merged = [
      for (final node in nodes)
        if (entityId(node) case final id?)
          {
            ...node,
            if (updates[id] case final geometry?) ..._encodeGeometry(geometry),
          }
        else
          node,
    ];
    final metadata = data['pulse'];
    return {
      ...data,
      'nodes': merged,
      'pulse': {
        if (metadata is Map) ...metadata,
        if (waiting.isNotEmpty)
          'nodeGeometry': waiting.map(
            (id, value) => MapEntry(id, _encodeGeometry(value)),
          ),
      }..removeWhere((key, _) => key == 'nodeGeometry' && waiting.isEmpty),
    };
  }

  List<CanvasNote> notes(String Function(String) resolvePath) => [
    for (var i = 0; i < nodes.length; i++)
      if (entityId(nodes[i]) == null && _isNote(nodes[i]))
        CanvasNote(
          document: NoteDocument(
            id:
                (nodes[i]['pulse'] is Map
                    ? nodes[i]['pulse']['noteId'] as String?
                    : null) ??
                nodes[i]['id'] as String,
            text: nodes[i]['type'] == 'text'
                ? nodes[i]['text'] as String
                : ((nodes[i]['pulse'] as Map?)?['cachedText'] as String? ?? ''),
            source: (nodes[i]['pulse'] as Map?)?['externalPath'] is String
                ? NoteReference(
                    sourceId: 'obsidian',
                    path: nodes[i]['pulse']['externalPath'] as String,
                  )
                : nodes[i]['type'] == 'file'
                ? NoteReference(
                    sourceId: 'obsidian',
                    path: resolvePath(nodes[i]['file'] as String),
                  )
                : null,
          ),
          x: (nodes[i]['x'] as num).toDouble(),
          y: (nodes[i]['y'] as num).toDouble(),
          width: (nodes[i]['width'] as num).toDouble(),
          height: (nodes[i]['height'] as num).toDouble(),
          index: i,
        ),
  ];

  bool _isNote(Map<String, dynamic> node) =>
      (node['type'] == 'text' && node['text'] is String) ||
      (node['type'] == 'file' &&
          node['file'] is String &&
          (node['file'] as String).toLowerCase().endsWith('.md') &&
          node['subpath'] == null);

  bool _isSticker(Map<String, dynamic> node) =>
      entityId(node) == null &&
      node['type'] == 'text' &&
      node['text'] is String &&
      (node['pulse'] is! Map || node['pulse']['externalPath'] is! String);

  String _noteId(Map<String, dynamic> node) =>
      node['pulse'] is Map && node['pulse']['noteId'] is String
      ? node['pulse']['noteId'] as String
      : node['id'] as String;

  List<CanvasNote> get stickers => [
    for (final (index, node) in nodes.indexed)
      if (_isSticker(node))
        CanvasNote(
          document: NoteDocument(
            id: _noteId(node),
            text: node['text'] as String,
          ),
          x: (node['x'] as num).toDouble(),
          y: (node['y'] as num).toDouble(),
          width: (node['width'] as num).toDouble(),
          height: (node['height'] as num).toDouble(),
          index: index,
        ),
  ];

  Map<String, Object?> applyStickers(
    Map<String, CanvasNote?> changes, {
    Set<String> linkedIds = const {},
    String Function(String)? filePath,
  }) {
    final pending = Map.of(changes);
    final kept = <Map<String, dynamic>>[];
    final removed = <String>{};
    final existingIds = nodes.map((node) => node['id'] as String).toSet();
    Map<String, dynamic> stickerNode(
      CanvasNote note,
      String canvasId,
      Map<String, dynamic> previous,
    ) {
      final source = note.document.source;
      final file = source == null ? null : filePath!(source.path);
      return {
          ...previous,
          'id': canvasId,
          'type': file == null ? 'text' : 'file',
          if (file == null) 'text': note.text else 'file': file,
          ..._encodeGeometry((
            x: note.x,
            y: note.y,
            width: note.width,
            height: note.height,
          )),
          'pulse': {
            if (previous['pulse'] case final Map metadata) ...metadata,
            'noteId': note.id,
            if (file != null) 'cachedText': note.text,
          }..remove('externalPath'),
        }
        ..remove(file == null ? 'file' : 'text')
        ..remove('subpath');
    }

    for (final node in nodes) {
      final id = _noteId(node);
      final managed =
          _isSticker(node) ||
          (entityId(node) == null && _isNote(node) && linkedIds.contains(id));
      if (!managed || !pending.containsKey(id)) {
        kept.add(node);
        continue;
      }
      final next = pending.remove(id);
      final canvasId = node['id'] as String;
      if (next == null) {
        removed.add(canvasId);
      } else {
        kept.add(stickerNode(next, canvasId, node));
      }
    }
    final keptNoteIds = kept
        .where((node) => entityId(node) == null && _isNote(node))
        .map(_noteId)
        .toSet();
    for (final note in pending.values.nonNulls) {
      final canvasId = 'note:${note.id}';
      if (!existingIds.add(canvasId) || !keptNoteIds.add(note.id)) {
        throw StateError('ID стикера уже используется другой карточкой.');
      }
      kept.add(stickerNode(note, canvasId, const {}));
    }
    return {
      ...data,
      'nodes': kept,
      'edges': [
        for (final edge in edges)
          if (!removed.contains(edge['fromNode']) &&
              !removed.contains(edge['toNode']))
            edge,
      ],
    };
  }

  Map<String, Object?> merge(Map<String, Object?> generated) {
    final generatedMetadata = generated['pulse'] as Map?;
    final generatedNodes = (generated['nodes'] as List)
        .cast<Map<String, Object?>>();
    final oldEntities = <String, Map<String, dynamic>>{};
    for (final node in nodes) {
      final id = entityId(node);
      if (id != null) {
        if (oldEntities.containsKey(id)) {
          throw const FormatException(
            'Repeated entity placement is not supported yet',
          );
        }
        oldEntities[id] = node;
      }
    }
    final remap = <String, String>{};
    final replacements = <String, Map<String, Object?>>{};
    for (final node in generatedNodes) {
      final id = node['id'] as String;
      final pulse = node['pulse'] as Map?;
      Map<String, dynamic>? old;
      if (pulse?['entityId'] case final String entity) {
        old = oldEntities[entity];
      } else if (id.startsWith('note:')) {
        old = nodes
            .where(
              (n) =>
                  n['id'] == id.substring(5) ||
                  (n['pulse'] is Map &&
                      n['pulse']['noteId'] == id.substring(5)),
            )
            .firstOrNull;
      }
      final target = old?['id'] as String? ?? id;
      remap[id] = target;
      replacements[target] = {
        ...?old,
        ...node,
        'id': target,
        if (old?['pulse'] is Map || node['pulse'] is Map)
          'pulse': {...?(old?['pulse'] as Map?), ...?(node['pulse'] as Map?)},
      };
      if (pulse?['externalPath'] == null) {
        (replacements[target]!['pulse'] as Map?)?.remove('externalPath');
      }
      if (node['type'] == 'file') replacements[target]!.remove('text');
      if (node['type'] == 'text') {
        replacements[target]!.remove('file');
        replacements[target]!.remove('subpath');
      }
    }
    final mergedNodes = <Map<String, Object?>>[];
    final removed = <String>{};
    for (final old in nodes) {
      final id = old['id'] as String;
      final replacement = replacements.remove(id);
      if (replacement != null) {
        mergedNodes.add(replacement);
      } else if (entityId(old) == null && !_isNote(old)) {
        mergedNodes.add(old);
      } else {
        removed.add(id);
      }
    }
    mergedNodes.addAll(replacements.values);
    final waiting = _waitingGeometry;
    if (generatedMetadata?['removedTaskIds'] case final List ids) {
      for (final id in ids) {
        waiting.remove(id);
      }
    }
    for (final id in oldEntities.keys) {
      waiting.remove(id);
    }
    for (final node in generatedNodes) {
      final metadata = node['pulse'];
      if (metadata is Map) waiting.remove(metadata['entityId']);
    }
    final oldEdges = {for (final e in edges) e['id']: e};
    final generatedEdges = (generated['edges'] as List)
        .cast<Map<String, Object?>>();
    return {
      ...data,
      ...generated,
      'nodes': mergedNodes,
      'pulse':
          {
            ...?(data['pulse'] as Map?),
            ...?(generated['pulse'] as Map?),
            if (waiting.isNotEmpty)
              'nodeGeometry': waiting.map(
                (id, value) => MapEntry(id, _encodeGeometry(value)),
              ),
          }..removeWhere(
            (key, _) =>
                (key == 'nodeGeometry' && waiting.isEmpty) ||
                (generatedMetadata != null &&
                    (key == 'hiddenTasks' ||
                        (key == 'removedTaskIds' &&
                            !generatedMetadata.containsKey(key)))),
          ),
      'edges': [
        for (final edge in edges)
          if (!(edge['id'] as String).startsWith('pulse-hierarchy:') &&
              !(edge['id'] as String).startsWith('pulse-sequence:') &&
              !((edge['pulse'] is Map) &&
                  const {
                    'hierarchy',
                    'sequence',
                  }.contains(edge['pulse']['kind'])) &&
              !removed.contains(edge['fromNode']) &&
              !removed.contains(edge['toNode']))
            edge,
        for (final edge in generatedEdges)
          {
            ...?oldEdges[edge['id']],
            ...edge,
            if (edge['pulse'] is Map)
              'pulse': {
                ...?(oldEdges[edge['id']]?['pulse'] as Map?),
                ...edge['pulse'] as Map,
              },
            'fromNode': remap[edge['fromNode']] ?? edge['fromNode'],
            'toNode': remap[edge['toNode']] ?? edge['toNode'],
          },
      ],
    };
  }
}
