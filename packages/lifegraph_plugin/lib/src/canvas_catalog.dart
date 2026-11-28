import 'package:graph_api/graph_api.dart';
import 'package:notes_api/notes_api.dart';

import '../canvas_board.dart';

abstract interface class CanvasCatalogStore {
  Future<List<String>> listCanvasIds();
  Future<CanvasBoardSession> openCatalogCanvas(String id);
}

class CanvasSummary {
  const CanvasSummary({
    required this.id,
    required this.title,
    required this.cardCount,
    required this.updatedAt,
    required this.preview,
    this.sourceId,
    this.sourceKind,
  });

  final String id;
  final String title;
  final int cardCount;
  final DateTime? updatedAt;
  final CanvasBoardDocument preview;
  final String? sourceId;
  final String? sourceKind;

  static CanvasSummary? read(String id, String raw, {String? legacyTitle}) {
    final document = CanvasBoardDocument(raw)..validateScope(id);
    final metadata = document.data['pulse'];
    final meta = metadata is Map ? metadata : const {};
    final legacy =
        meta['canvasId'] == null &&
        (meta['sphereId'] == id || legacyTitle != null);
    if (!legacy && meta['canvasId'] != id) return null;
    final title = meta['title'];
    final date = meta['updatedAt'];
    final sourceId = meta['sourceId'];
    final sourceKind = meta['sourceKind'];
    return CanvasSummary(
      id: id,
      title: title is String && title.trim().isNotEmpty
          ? title
          : legacyTitle ??
                (legacy
                    ? CanvasCards.fromDocument(document).snapshots[id]?.title
                    : null) ??
                'Канвас',
      cardCount: document.nodes.length,
      updatedAt: date is String ? DateTime.tryParse(date) : null,
      preview: document,
      sourceId: sourceId is String ? sourceId : (legacy ? id : null),
      sourceKind: sourceKind is String
          ? sourceKind
          : (legacy ? 'sphere' : null),
    );
  }
}

class CanvasStructure {
  CanvasStructure(List<GraphNodeData> catalog, String sourceId)
    : root = catalog.where((node) => node.id == sourceId).firstOrNull {
    final root = this.root;
    if (root == null) return;
    final byParent = <String, List<GraphNodeData>>{};
    for (final item in catalog) {
      if (item.parentId case final parent?) (byParent[parent] ??= []).add(item);
    }
    final visited = {root.id};
    nodes.add(root);
    for (var i = 0; i < nodes.length; i++) {
      final parent = nodes[i].id;
      final children = (byParent[parent] ?? const [])
          .where((item) => visited.add(item.id))
          .toList();
      _children[parent] = children;
      nodes.addAll(children);
    }
  }

  final GraphNodeData? root;
  final nodes = <GraphNodeData>[];
  final _children = <String, List<GraphNodeData>>{};

  List<GraphNodeData> childrenOf(String id) => _children[id] ?? const [];

  List<GraphNodeData> selected(Set<String> ids) => [
    for (final node in nodes)
      if (ids.contains(node.id))
        CanvasCards.onBoard(
          node,
          parentId: node.id != root?.id && ids.contains(node.parentId)
              ? node.parentId
              : null,
          predecessors: graphPredecessorIds(
            node.attributes,
          ).where(ids.contains),
        ),
  ];
}

/// The board owns membership and links. Titles and statuses use live entities.
class CanvasCards {
  CanvasCards.fromDocument(CanvasBoardDocument document) {
    final entityIds = <String, String>{};
    final removed = document.removedTaskIds;
    for (final card in document.nodes) {
      final id = document.entityId(card);
      if (id == null || removed.contains(id)) continue;
      entityIds[card['id'] as String] = id;
      final meta = card['pulse'];
      final kind = meta is Map ? meta['kind'] : null;
      final text = card['text'];
      final lines = text is String ? text.split('\n\n') : const <String>[];
      snapshots[id] = GraphNodeData(
        id: id,
        kind: kind is String ? kind : 'entity',
        title: lines.firstOrNull?.replaceFirst(RegExp(r'^#+\s*'), '') ?? id,
        subtitle: lines.skip(1).join('\n\n'),
        color: card['color'] is String ? card['color'] as String : '#E5E2E1',
      );
    }
    for (final edge in document.edges) {
      final from = entityIds[edge['fromNode']];
      final to = entityIds[edge['toNode']];
      if (from == null || to == null || from == to) continue;
      final meta = edge['pulse'];
      final kind = meta is Map ? meta['kind'] : null;
      final edgeId = edge['id'] as String;
      if (kind == 'hierarchy' || edgeId.startsWith('pulse-hierarchy:')) {
        if (canConnect(from, to)) parents[to] = from;
      } else if (kind == 'sequence' || edgeId.startsWith('pulse-sequence:')) {
        (predecessors[to] ??= {}).add(from);
      }
    }
  }

  final snapshots = <String, GraphNodeData>{};
  final parents = <String, String>{};
  final predecessors = <String, Set<String>>{};

  bool canConnect(String from, String to) {
    if (from == to ||
        parents[to] == from ||
        !snapshots.containsKey(from) ||
        !snapshots.containsKey(to)) {
      return false;
    }
    for (String? parent = from; parent != null; parent = parents[parent]) {
      if (parent == to) return false;
    }
    return true;
  }

  List<GraphNodeData> project(Map<String, GraphNodeData> live) {
    final children = <String, List<String>>{};
    for (final entry in parents.entries) {
      (children[entry.value] ??= []).add(entry.key);
    }
    final ids = snapshots.keys.where((id) => !parents.containsKey(id)).toList();
    for (var i = 0; i < ids.length; i++) {
      ids.addAll(children[ids[i]] ?? const []);
    }
    return [
      for (final id in ids)
        onBoard(
          live[id] ?? snapshots[id]!,
          parentId: parents[id],
          predecessors: predecessors[id] ?? const {},
        ),
    ];
  }

  static GraphNodeData onBoard(
    GraphNodeData node, {
    String? parentId,
    Iterable<String> predecessors = const [],
  }) => GraphNodeData(
    id: node.id,
    kind: node.kind,
    title: node.title,
    subtitle: node.subtitle,
    color: node.color,
    parentId: parentId,
    attributes: {
      ...node.attributes,
      'predecessorTaskIds': predecessors.toList(),
    },
  );

  void remove(String id) {
    snapshots.remove(id);
    parents.removeWhere((child, parent) => child == id || parent == id);
    predecessors.remove(id);
    for (final values in predecessors.values) {
      values.remove(id);
    }
  }
}
