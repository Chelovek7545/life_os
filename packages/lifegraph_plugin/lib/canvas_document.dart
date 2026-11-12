import 'package:graph_api/graph_api.dart';
import 'package:notes_api/notes_api.dart';

class CanvasEntity {
  const CanvasEntity({
    required this.node,
    required this.position,
    required this.width,
    required this.height,
  });

  final GraphNodeData node;
  final GraphPoint position;
  final double width;
  final double height;
}

Map<String, Object?> createSphereCanvas({
  required String sphereId,
  required List<CanvasEntity> entities,
  required List<CanvasNote> notes,
  required String Function(String) filePath,
}) {
  final ids = <String>{};
  final nodes = <Map<String, Object?>>[];
  Map<String, Object?> geometry(
    String id,
    double x,
    double y,
    double width,
    double height,
  ) {
    if (!ids.add(id)) throw ArgumentError('Duplicate canvas card: $id');
    if (![x, y, width, height].every((value) => value.isFinite) ||
        width.round() <= 0 ||
        height.round() <= 0) {
      throw ArgumentError('Invalid canvas geometry: $id');
    }
    return {
      'id': id,
      'x': x.round(),
      'y': y.round(),
      'width': width.round(),
      'height': height.round(),
    };
  }

  for (final entity in entities) {
    final node = entity.node;
    nodes.add({
      ...geometry(
        'pulse:${node.id}',
        entity.position.x,
        entity.position.y,
        entity.width,
        entity.height,
      ),
      'type': 'text',
      'text': [
        '## ${node.title}',
        if (node.subtitle.isNotEmpty) node.subtitle,
        if (node.attributes['taskStatus'] case final String status)
          'Статус: $status',
      ].join('\n\n'),
      'color': node.color,
      'pulse': {'kind': node.kind, 'entityId': node.id},
    });
  }
  for (final note in notes) {
    final source = note.document.source;
    if (source != null && source.sourceId != 'obsidian') {
      throw UnsupportedError('Unsupported note source: ${source.sourceId}');
    }
    String? relative;
    if (source != null) {
      try {
        relative = filePath(source.path);
      } on ArgumentError {
        // A note in another root stays linked in Pulse; Canvas shows its text.
      }
    }
    nodes.add({
      ...geometry('note:${note.id}', note.x, note.y, note.width, note.height),
      'type': relative == null ? 'text' : 'file',
      if (relative == null) 'text': note.text else 'file': relative,
      'pulse': {
        'noteId': note.id,
        if (source != null) 'cachedText': note.text,
        if (source != null && relative == null) 'externalPath': source.path,
      },
    });
  }
  return {
    'nodes': nodes,
    'edges': [
      for (final entity in entities)
        if (entity.node.parentId case final String parentId)
          if (ids.contains('pulse:$parentId'))
            {
              'id': 'pulse-hierarchy:$parentId:${entity.node.id}',
              'fromNode': 'pulse:$parentId',
              'toNode': 'pulse:${entity.node.id}',
              'fromSide': 'right',
              'toSide': 'left',
              'toEnd': 'arrow',
              'pulse': {'kind': 'hierarchy'},
            },
    ],
    'pulse': {'version': 1, 'sphereId': sphereId},
  };
}
