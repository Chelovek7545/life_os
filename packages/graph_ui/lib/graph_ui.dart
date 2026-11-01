import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'src/editors.dart';
export 'src/editors.dart';

class GraphNodeInteraction {
  const GraphNodeInteraction({
    required this.size,
    required this.selected,
    required this.hasChildren,
    required this.collapsed,
    required this.hiddenCount,
    required this.accent,
    required this.select,
    required this.toggleCollapse,
    required this.dragStart,
    required this.dragUpdate,
    required this.dragEnd,
    this.edit,
    this.addChild,
    this.remove,
    this.createChild,
    this.updateNode,
    this.deleteNode,
  });
  final Size size;
  final bool selected;
  final bool hasChildren;
  final bool collapsed;
  final int hiddenCount;
  final Color accent;
  final VoidCallback select;
  final VoidCallback toggleCollapse;
  final GestureDragStartCallback dragStart;
  final GestureDragUpdateCallback dragUpdate;
  final GestureDragEndCallback dragEnd;
  final VoidCallback? edit;
  final VoidCallback? addChild;
  final VoidCallback? remove;
  final Future<String> Function(GraphNodeDraft draft)? createChild;
  final Future<void> Function(GraphNodeData updated)? updateNode;
  final Future<void> Function(bool keepChildren)? deleteNode;
}

class GraphNodePresentation {
  const GraphNodePresentation({
    required this.kind,
    required this.size,
    required this.builder,
  });
  final String kind;
  final Size size;
  final Widget Function(BuildContext, GraphNodeData, GraphNodeInteraction)
  builder;
}

class GraphNodePresentationRegistry extends ChangeNotifier {
  final Map<String, List<GraphNodePresentation>> _owners = {};
  static const fallbackSize = Size(180, 100);
  bool _disposed = false;
  GraphNodePresentation? lookup(String kind) {
    for (final values in _owners.values) {
      for (final value in values) {
        if (value.kind == kind) return value;
      }
    }
    return null;
  }

  Size sizeFor(String kind) => lookup(kind)?.size ?? fallbackSize;
  void register(String owner, Iterable<GraphNodePresentation> values) {
    if (_disposed) throw StateError('Graph presentations are disposed.');
    if (_owners.containsKey(owner)) {
      throw ArgumentError(
        'Graph presentation owner already registered: $owner',
      );
    }
    final snapshot = List<GraphNodePresentation>.unmodifiable(values);
    final kinds = _owners.values
        .expand((items) => items)
        .map((item) => item.kind)
        .toSet();
    for (final value in snapshot) {
      if (!kinds.add(value.kind)) {
        throw ArgumentError('Duplicate graph presentation: ${value.kind}');
      }
      if (!value.size.width.isFinite ||
          !value.size.height.isFinite ||
          value.size.width <= 0 ||
          value.size.height <= 0) {
        throw ArgumentError('Invalid graph node size: ${value.kind}');
      }
    }
    _owners[owner] = snapshot;
    notifyListeners();
  }

  void unregister(String owner) {
    if (_owners.remove(owner) != null && !_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _owners.clear();
    super.dispose();
  }
}

class GraphModule {
  GraphModule({
    required this.id,
    Set<String> dependencies = const {},
    Iterable<GraphContributor> contributors = const [],
    Iterable<GraphNodePresentation> presentations = const [],
    Iterable<GraphNodeCommands> commands = const [],
    Iterable<GraphNodeEditor> editors = const [],
    Iterable<GraphChildAction> childActions = const [],
  }) : dependencies = Set.unmodifiable(dependencies),
       contributors = List.unmodifiable(contributors),
       presentations = List.unmodifiable(presentations),
       commands = List.unmodifiable(commands),
       editors = List.unmodifiable(editors),
       childActions = List.unmodifiable(childActions);
  final String id;
  final Set<String> dependencies;
  final List<GraphContributor> contributors;
  final List<GraphNodePresentation> presentations;
  final List<GraphNodeCommands> commands;
  final List<GraphNodeEditor> editors;
  final List<GraphChildAction> childActions;
}

class GraphModulePlugin implements AppPlugin {
  GraphModulePlugin({
    required this.module,
    required this.contributors,
    required this.presentations,
    required this.commands,
    required this.editors,
  });
  final GraphModule module;
  final GraphContributorRegistry contributors;
  final GraphNodePresentationRegistry presentations;
  final GraphCommandRegistry commands;
  final GraphEditorRegistry editors;
  bool _registeredPresentations = false;
  bool _registeredContributors = false;
  bool _registeredCommands = false;
  bool _registeredEditors = false;
  @override
  String get id => module.id;
  @override
  Set<String> get dependencies => module.dependencies;
  @override
  Future<void> start() async {
    presentations.register(id, module.presentations);
    _registeredPresentations = true;
    commands.register(id, module.commands);
    _registeredCommands = true;
    editors.register(
      id,
      editors: module.editors,
      childActions: module.childActions,
    );
    _registeredEditors = true;
    contributors.register(id, module.contributors);
    _registeredContributors = true;
  }

  @override
  Future<void> stop() async {
    try {
      if (_registeredEditors) editors.unregister(id);
    } finally {
      _registeredEditors = false;
      try {
        if (_registeredCommands) await commands.unregister(id);
      } finally {
        _registeredCommands = false;
        try {
          if (_registeredContributors) await contributors.unregister(id);
        } finally {
          _registeredContributors = false;
          if (_registeredPresentations) {
            presentations.unregister(id);
            _registeredPresentations = false;
          }
        }
      }
    }
  }
}

class GraphNodeView extends StatelessWidget {
  const GraphNodeView({
    super.key,
    required this.registry,
    required this.node,
    required this.interaction,
  });
  final GraphNodePresentationRegistry registry;
  final GraphNodeData node;
  final GraphNodeInteraction interaction;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: registry,
    builder: (context, _) {
      final presentation = registry.lookup(node.kind);
      if (presentation != null) {
        return presentation.builder(context, node, interaction);
      }
      return GestureDetector(
        onTap: interaction.select,
        onLongPress: interaction.edit,
        onDoubleTap: (interaction.hasChildren || interaction.collapsed)
            ? interaction.toggleCollapse
            : null,
        onPanStart: interaction.dragStart,
        onPanUpdate: interaction.dragUpdate,
        onPanEnd: interaction.dragEnd,
        onPanCancel: () => interaction.dragEnd(DragEndDetails()),
        child: Container(
          width: interaction.size.width,
          height: interaction.size.height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: interaction.accent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      node.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (node.subtitle.isNotEmpty)
                      Text(
                        node.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (interaction.edit != null ||
                  interaction.addChild != null ||
                  interaction.remove != null)
                PopupMenuButton<String>(
                  key: ValueKey('graph-actions:${node.id}'),
                  tooltip: 'Действия с узлом',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  itemBuilder: (_) => [
                    if (interaction.edit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: Text('Изменить'),
                      ),
                    if (interaction.addChild != null)
                      const PopupMenuItem(
                        value: 'add',
                        child: Text('Добавить элемент'),
                      ),
                    if (interaction.remove != null)
                      const PopupMenuItem(
                        value: 'remove',
                        child: Text('Удалить'),
                      ),
                  ],
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        interaction.edit?.call();
                      case 'add':
                        interaction.addChild?.call();
                      case 'remove':
                        interaction.remove?.call();
                    }
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
