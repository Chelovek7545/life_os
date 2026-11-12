import 'dart:convert';
import 'package:notes_api/notes_api.dart';

class CanvasBoardDocument {
  CanvasBoardDocument(String content) : data = _decode(content);
  final Map<String, dynamic> data;
  List<Map<String, dynamic>> get nodes =>
      (data['nodes'] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get edges =>
      (data['edges'] as List).cast<Map<String, dynamic>>();

  void validateScope(String sphereId) {
    final metadata = data['pulse'];
    if (metadata is! Map) return;
    if (metadata['sphereId'] != null && metadata['sphereId'] != sphereId) {
      throw const FormatException('Canvas принадлежит другой сфере.');
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

  Map<String, Object?> merge(Map<String, Object?> generated) {
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
    final oldEdges = {for (final e in edges) e['id']: e};
    final generatedEdges = (generated['edges'] as List)
        .cast<Map<String, Object?>>();
    return {
      ...data,
      ...generated,
      'nodes': mergedNodes,
      'pulse': {...?(data['pulse'] as Map?), ...?(generated['pulse'] as Map?)},
      'edges': [
        for (final edge in edges)
          if (!(edge['id'] as String).startsWith('pulse-hierarchy:') &&
              !((edge['pulse'] is Map) &&
                  edge['pulse']['kind'] == 'hierarchy') &&
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
