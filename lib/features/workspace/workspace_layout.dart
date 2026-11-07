import 'dart:convert';

enum WorkspaceAxis { horizontal, vertical }

sealed class WorkspaceNode {
  const WorkspaceNode(this.id);
  final String id;
  Iterable<WorkspacePane> get panes;
  Map<String, Object> toJson();

  WorkspaceNode? find(String target) {
    if (id == target) return this;
    if (this is WorkspaceSplit) {
      final split = this as WorkspaceSplit;
      return split.first.find(target) ?? split.second.find(target);
    }
    return null;
  }

  WorkspaceNode replace(String target, WorkspaceNode replacement) {
    if (id == target) return replacement;
    if (this is WorkspaceSplit) {
      final split = this as WorkspaceSplit;
      return WorkspaceSplit(
        id,
        split.axis,
        split.ratio,
        split.first.replace(target, replacement),
        split.second.replace(target, replacement),
      );
    }
    return this;
  }

  WorkspaceNode? remove(String target) {
    if (id == target) return null;
    if (this is WorkspaceSplit) {
      final split = this as WorkspaceSplit;
      final first = split.first.remove(target);
      final second = split.second.remove(target);
      if (first == null) return second;
      if (second == null) return first;
      return WorkspaceSplit(id, split.axis, split.ratio, first, second);
    }
    return this;
  }
}

class WorkspacePane extends WorkspaceNode {
  const WorkspacePane(super.id, this.editorId);
  final String editorId;
  @override
  Iterable<WorkspacePane> get panes => [this];
  @override
  Map<String, Object> toJson() => {'id': id, 'editor': editorId};
}

class WorkspaceSplit extends WorkspaceNode {
  const WorkspaceSplit(
    super.id,
    this.axis,
    this.ratio,
    this.first,
    this.second,
  );
  final WorkspaceAxis axis;
  final double ratio;
  final WorkspaceNode first;
  final WorkspaceNode second;
  @override
  Iterable<WorkspacePane> get panes => [...first.panes, ...second.panes];
  @override
  Map<String, Object> toJson() => {
    'id': id,
    'axis': axis.name,
    'ratio': ratio,
    'first': first.toJson(),
    'second': second.toJson(),
  };
}

class WorkspaceLayout {
  const WorkspaceLayout(this.root);
  static const maxPanes = 12;
  static const initial = WorkspaceLayout(
    WorkspaceSplit(
      'initial-split',
      WorkspaceAxis.horizontal,
      .4,
      WorkspacePane('initial-tasks', 'tasks'),
      WorkspacePane('initial-calendar', 'calendar'),
    ),
  );
  final WorkspaceNode root;
  String encode() => jsonEncode({'version': 1, 'root': root.toJson()});

  /// Rejects damaged or unsupported layouts without touching user data.
  static WorkspaceLayout? decode(String value, Set<String> editorIds) {
    try {
      final json = jsonDecode(value);
      if (json is! Map || json['version'] != 1) return null;
      final ids = <String>{};
      var count = 0;
      WorkspaceNode read(Object? value, int depth) {
        if (value is! Map || depth > maxPanes || ++count > maxPanes * 2 - 1) {
          throw const FormatException('Invalid workspace tree');
        }
        final id = value['id'];
        if (id is! String || id.isEmpty || id.length > 100 || !ids.add(id)) {
          throw const FormatException('Invalid workspace identity');
        }
        if (value.containsKey('editor')) {
          final editor = value['editor'];
          if (editor is! String || !editorIds.contains(editor)) {
            throw const FormatException('Unknown workspace editor');
          }
          return WorkspacePane(id, editor);
        }
        final axis = value['axis'];
        final ratio = value['ratio'];
        if ((axis != 'horizontal' && axis != 'vertical') ||
            ratio is! num ||
            !ratio.isFinite ||
            ratio <= 0 ||
            ratio >= 1) {
          throw const FormatException('Invalid workspace split');
        }
        return WorkspaceSplit(
          id,
          axis == 'horizontal'
              ? WorkspaceAxis.horizontal
              : WorkspaceAxis.vertical,
          ratio.toDouble(),
          read(value['first'], depth + 1),
          read(value['second'], depth + 1),
        );
      }

      return WorkspaceLayout(read(json['root'], 0));
    } on FormatException {
      return null;
    }
  }
}
