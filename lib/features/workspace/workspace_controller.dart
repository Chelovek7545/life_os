import 'dart:ui' show Size;
import 'package:flutter/foundation.dart';
import 'package:plugin_runtime/debounced_writer.dart';
import 'package:uuid/uuid.dart';
import 'workspace_layout.dart';
import 'workspace_geometry.dart';

class WorkspaceController extends ChangeNotifier {
  WorkspaceController({
    required this.editorIds,
    required Future<void> Function(String) save,
    required void Function(Object, StackTrace) onSaveError,
    WorkspaceLayout initial = WorkspaceLayout.initial,
  }) : _layout = initial,
       _writer = DebouncedWriter(save, onError: onSaveError),
       _selectedId = initial.root.panes.first.id;

  final Set<String> editorIds;
  final DebouncedWriter<String> _writer;
  WorkspaceLayout _layout;
  WorkspaceLayout get layout => _layout;
  String _selectedId;
  String get selectedId => _selectedId;
  String? _maximizedId;
  String? get maximizedId => _maximizedId;
  bool _active = true;
  bool get isActive => _active;
  bool _isEditing = false;
  bool get isEditing => _isEditing;
  Future<void>? _closing;

  void setEditing(bool value) {
    if (!_active || _isEditing == value) return;
    _isEditing = value;
    if (!value) _maximizedId = null;
    notifyListeners();
  }

  void select(String id) {
    if (!_active || !layout.root.panes.any((pane) => pane.id == id)) return;
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  void changeEditor(String id, String editor) {
    if (!_active || !_isEditing || !editorIds.contains(editor)) return;
    if (!layout.root.panes.any((pane) => pane.id == id)) return;
    _commit(layout.root.replace(id, WorkspacePane(id, editor)));
  }

  void split(String id, WorkspaceAxis axis) {
    if (!_active ||
        !_isEditing ||
        layout.root.panes.length >= WorkspaceLayout.maxPanes) {
      return;
    }
    final matches = layout.root.panes.where((pane) => pane.id == id);
    if (matches.isEmpty) return;
    final pane = matches.single;
    final added = WorkspacePane(const Uuid().v4(), pane.editorId);
    _selectedId = added.id;
    _maximizedId = null;
    _commit(
      layout.root.replace(
        id,
        WorkspaceSplit(const Uuid().v4(), axis, .5, pane, added),
      ),
    );
  }

  void closePane(String id) {
    if (!_active || !_isEditing || layout.root.panes.length == 1) return;
    final next = layout.root.remove(id);
    if (next == null) return;
    if (_selectedId == id) _selectedId = next.panes.first.id;
    if (_maximizedId == id) _maximizedId = null;
    _commit(next);
  }

  void resize(WorkspaceSplit split, double ratio) {
    if (!_active || !ratio.isFinite) return;
    final current = layout.root.find(split.id);
    if (current is! WorkspaceSplit) return;
    _commit(
      layout.root.replace(
        current.id,
        WorkspaceSplit(
          current.id,
          current.axis,
          ratio.clamp(.1, .9),
          current.first,
          current.second,
        ),
      ),
    );
  }

  void toggleMaximize(String id) {
    if (!_active ||
        !_isEditing ||
        !layout.root.panes.any((pane) => pane.id == id)) {
      return;
    }
    _selectedId = id;
    _maximizedId = _maximizedId == id ? null : id;
    notifyListeners();
  }

  void moveDivider(String id, double delta, Size viewport) {
    if (!_active || !delta.isFinite) return;
    final geometry = WorkspaceGeometry(layout.root, viewport);
    final next = geometry.moveDivider(id, delta);
    if (!identical(next, layout.root)) {
      _commit(next);
    }
  }

  void _commit(WorkspaceNode root) {
    _layout = WorkspaceLayout(root);
    _writer.schedule(_layout.encode());
    notifyListeners();
  }

  Future<void> flush() => _writer.flush();
  Future<void> close() {
    _active = false;
    return _closing ??= _writer.close();
  }
}
