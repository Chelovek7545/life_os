import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';

/// The node and mutations bound to the graph that opened a form.
///
/// Host callbacks receive an availability check. They must recheck it when
/// queued work starts, before dispatching the mutation. An accepted write is
/// allowed to finish once its handler has started.
class GraphNodeActionContext {
  factory GraphNodeActionContext({
    required GraphScope scope,
    required GraphNodeData node,
    required Future<String> Function(GraphNodeDraft, bool Function())
    createChild,
    required Future<void> Function(GraphNodeData, bool Function()) updateNode,
    required Future<void> Function(bool, bool Function()) deleteNode,
    required Future<void> Function(String, String, bool Function()) attachNode,
    bool Function()? isAvailable,
  }) => GraphNodeActionContext._(
    scope,
    node,
    createChild,
    updateNode,
    deleteNode,
    attachNode,
    isAvailable ?? (() => true),
  );
  GraphNodeActionContext._(
    this.scope,
    this.node,
    this._createChild,
    this._updateNode,
    this._deleteNode,
    this._attachNode,
    this._isAvailable,
  );
  final GraphScope scope;
  final GraphNodeData node;
  final Future<String> Function(GraphNodeDraft, bool Function()) _createChild;
  final Future<void> Function(GraphNodeData, bool Function()) _updateNode;
  final Future<void> Function(bool, bool Function()) _deleteNode;
  final Future<void> Function(String, String, bool Function()) _attachNode;
  final bool Function() _isAvailable;

  Future<T> _invoke<T>(Future<T> Function() action) async {
    if (!_isAvailable()) {
      throw StateError('The graph form owner is no longer active.');
    }
    return action();
  }

  Future<String> createChild(GraphNodeDraft draft) =>
      _invoke(() => _createChild(draft, _isAvailable));
  Future<void> updateNode(GraphNodeData node) =>
      _invoke(() => _updateNode(node, _isAvailable));
  Future<void> deleteNode(bool keepChildren) =>
      _invoke(() => _deleteNode(keepChildren, _isAvailable));
  Future<void> attachNode(String kind, String id) =>
      _invoke(() => _attachNode(kind, id, _isAvailable));

  GraphNodeActionContext _guarded(bool Function() active) {
    return GraphNodeActionContext(
      scope: scope,
      node: node,
      createChild: _createChild,
      updateNode: _updateNode,
      deleteNode: _deleteNode,
      attachNode: _attachNode,
      isAvailable: () => _isAvailable() && active(),
    );
  }
}

typedef GraphFormBuilder =
    Widget Function(BuildContext context, GraphNodeActionContext actions);

/// A module-owned editor for one node kind.
class GraphNodeEditor {
  const GraphNodeEditor({required this.kind, required this.builder});
  final String kind;
  final GraphFormBuilder builder;
}

enum GraphChildOperation { create, attach }

/// A form offered below a parent when its command is available.
class GraphChildAction {
  GraphChildAction({
    required this.id,
    required this.label,
    required this.childKind,
    required Set<String> parentKinds,
    required this.builder,
    this.operation = GraphChildOperation.create,
    this.order = 0,
  }) : parentKinds = Set.unmodifiable(parentKinds);
  final String id;
  final String label;
  final String childKind;
  final Set<String> parentKinds;
  final GraphChildOperation operation;
  final int order;
  final GraphFormBuilder builder;
}

/// Owns editor and child-action registrations and their open-form leases.
class GraphEditorRegistry extends ChangeNotifier {
  final Map<String, _EditorOwner> _owners = {};
  bool _disposed = false;

  bool hasEditor(String kind) => _editor(kind) != null;
  List<GraphChildAction> childActions(String parentKind) {
    final actions = [
      for (final owner in _owners.values)
        ...owner.actions.where(
          (action) => action.parentKinds.contains(parentKind),
        ),
    ];
    // Preserve registration order for actions with the same priority.
    final indexed = actions.asMap().entries.toList()
      ..sort((a, b) {
        final byOrder = a.value.order.compareTo(b.value.order);
        return byOrder != 0 ? byOrder : a.key.compareTo(b.key);
      });
    return List.unmodifiable(indexed.map((entry) => entry.value));
  }

  /// Registers the owner's forms atomically and rejects conflicting IDs.
  void register(
    String owner, {
    Iterable<GraphNodeEditor> editors = const [],
    Iterable<GraphChildAction> childActions = const [],
  }) {
    if (_disposed) throw StateError('Graph editors are disposed.');
    if (_owners.containsKey(owner)) {
      throw ArgumentError('Graph editor owner already registered: $owner');
    }
    final entry = _EditorOwner(
      List.unmodifiable(editors),
      List.unmodifiable(childActions),
    );
    final kinds = _owners.values
        .expand((entry) => entry.editors)
        .map((editor) => editor.kind)
        .toSet();
    final ids = _owners.values
        .expand((entry) => entry.actions)
        .map((action) => action.id)
        .toSet();
    for (final editor in entry.editors) {
      if (!kinds.add(editor.kind)) {
        throw ArgumentError('Duplicate graph editor: ${editor.kind}');
      }
    }
    for (final action in entry.actions) {
      if (!ids.add(action.id)) {
        throw ArgumentError('Duplicate graph child action: ${action.id}');
      }
    }
    _owners[owner] = entry;
    notifyListeners();
  }

  void unregister(String owner) {
    if (_owners.remove(owner) != null && !_disposed) notifyListeners();
  }

  ({_EditorOwner owner, GraphNodeEditor editor})? _editor(String kind) {
    for (final owner in _owners.values) {
      for (final editor in owner.editors) {
        if (editor.kind == kind) return (owner: owner, editor: editor);
      }
    }
    return null;
  }

  ({_EditorOwner owner, GraphChildAction action})? _action(String id) {
    for (final owner in _owners.values) {
      for (final action in owner.actions) {
        if (action.id == id) return (owner: owner, action: action);
      }
    }
    return null;
  }

  bool _active(_EditorOwner owner) =>
      !_disposed && _owners.values.contains(owner);

  @override
  void dispose() {
    _disposed = true;
    _owners.clear();
    notifyListeners();
    super.dispose();
  }
}

class _EditorOwner {
  _EditorOwner(this.editors, this.actions);
  final List<GraphNodeEditor> editors;
  final List<GraphChildAction> actions;
}

/// Opens registered forms without depending on application entity types.
class GraphNodeDialogs {
  const GraphNodeDialogs({required this.registry, required this.commands});
  final GraphEditorRegistry registry;
  final GraphCommandRegistry commands;

  bool canEdit(String kind) =>
      registry.hasEditor(kind) && commands.canUpdate(kind);
  bool canAddChild(String parentKind) => _actions(parentKind).isNotEmpty;
  List<GraphChildAction> _actions(String parentKind) => registry
      .childActions(parentKind)
      .where(
        (action) => switch (action.operation) {
          GraphChildOperation.create => commands.canCreate(
            action.childKind,
            parentKind,
          ),
          GraphChildOperation.attach => commands.canAttach(
            action.childKind,
            parentKind,
          ),
        },
      )
      .toList();

  Future<void> edit(
    BuildContext context,
    GraphNodeActionContext actions,
  ) async {
    final entry = registry._editor(actions.node.kind);
    if (entry == null || !canEdit(actions.node.kind)) return;
    await _show(
      context,
      entry.owner,
      entry.editor.builder,
      actions,
      commands.guardFor(actions.node.kind),
    );
  }

  Future<void> addChild(
    BuildContext context,
    GraphNodeActionContext actions,
  ) async {
    final available = _actions(actions.node.kind);
    if (available.isEmpty) return;
    String? selected;
    if (available.length == 1) {
      selected = available.single.id;
    } else {
      selected = await showDialog<String>(
        context: context,
        builder: (context) => ListenableBuilder(
          listenable: registry,
          builder: (context, _) => AlertDialog(
            title: const Text('Добавить элемент'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final action in _actions(actions.node.kind))
                    ListTile(
                      title: Text(action.label),
                      onTap: () => Navigator.pop(context, action.id),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
            ],
          ),
        ),
      );
    }
    if (selected == null || !context.mounted) return;
    final entry = registry._action(selected);
    if (entry == null || !_actions(actions.node.kind).contains(entry.action)) {
      return;
    }
    await _show(
      context,
      entry.owner,
      entry.action.builder,
      actions,
      commands.guardFor(entry.action.childKind),
    );
  }

  Future<void> _show(
    BuildContext context,
    _EditorOwner owner,
    GraphFormBuilder builder,
    GraphNodeActionContext actions,
    bool Function() commandActive,
  ) => showDialog<void>(
    context: context,
    builder: (context) => ListenableBuilder(
      listenable: registry,
      builder: (context, _) => registry._active(owner) && commandActive()
          ? builder(
              context,
              actions._guarded(
                () => registry._active(owner) && commandActive(),
              ),
            )
          : AlertDialog(
              title: const Text('Действие больше недоступно'),
              content: const Text(
                'Модуль был отключён. Закройте форму и выберите доступное действие.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'),
                ),
              ],
            ),
    ),
  );

  Future<void> remove(
    BuildContext context,
    GraphNodeActionContext actions,
  ) async {
    if (!commands.canDelete(actions.node.kind)) return;
    final guarded = actions._guarded(commands.guardFor(actions.node.kind));
    await showDialog<void>(
      context: context,
      builder: (_) => GraphDeleteDialog(
        title: actions.node.title,
        onDelete: guarded.deleteNode,
      ),
    );
  }
}

/// Confirms a deletion and keeps failures visible for retry.
class GraphDeleteDialog extends StatefulWidget {
  const GraphDeleteDialog({
    super.key,
    required this.title,
    required this.onDelete,
  });
  final String title;
  final Future<void> Function(bool keepChildren) onDelete;
  @override
  State<GraphDeleteDialog> createState() => _GraphDeleteDialogState();
}

class _GraphDeleteDialogState extends State<GraphDeleteDialog> {
  bool _saving = false;
  bool _failed = false;
  Future<void> _delete(bool keepChildren) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await widget.onDelete(keepChildren);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Удалить узел?'),
    content: Text(
      _failed
          ? 'Не удалось удалить узел. Повторите попытку.'
          : 'Узел «${widget.title}» будет удалён. Что сделать с дочерними элементами?',
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => _delete(false),
        child: const Text('Удалить всё поддерево'),
      ),
      FilledButton(
        onPressed: _saving ? null : () => _delete(true),
        child: const Text('Сохранить детей (скрыть)'),
      ),
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
    ],
  );
}
