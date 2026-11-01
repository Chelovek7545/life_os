import 'dart:async';
import 'graph_data.dart';

/// The values supplied when creating a node of an extensible kind.
class GraphNodeDraft {
  GraphNodeDraft({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.color,
    Map<String, Object?> attributes = const {},
  }) : attributes = Map.unmodifiable(attributes);

  final String kind;
  final String title;
  final String subtitle;
  final String? color;
  final Map<String, Object?> attributes;
}

/// A creation request with the parent resolved from the active graph.
class GraphCreateRequest {
  const GraphCreateRequest({
    required this.scope,
    required this.parent,
    required this.draft,
  });
  final GraphScope scope;
  final GraphNodeData parent;
  final GraphNodeDraft draft;
}

/// An edit request with the current node and the desired field values.
class GraphUpdateRequest {
  const GraphUpdateRequest({
    required this.scope,
    required this.current,
    required this.updated,
  });
  final GraphScope scope;
  final GraphNodeData current;
  final GraphNodeData updated;
}

/// A deletion request that preserves children when requested by the caller.
class GraphDeleteRequest {
  const GraphDeleteRequest({
    required this.scope,
    required this.node,
    required this.keepChildren,
  });
  final GraphScope scope;
  final GraphNodeData node;
  final bool keepChildren;
}

/// A request to attach an existing entity below a resolved graph node.
class GraphAttachRequest {
  const GraphAttachRequest({
    required this.scope,
    required this.parent,
    required this.kind,
    required this.id,
  });
  final GraphScope scope;
  final GraphNodeData parent;
  final String kind;
  final String id;
}

typedef GraphCreateHandler =
    Future<String> Function(GraphCreateRequest request);
typedef GraphUpdateHandler = Future<void> Function(GraphUpdateRequest request);

/// A handler returning the IDs actually removed by its transaction.
typedef GraphDeleteHandler =
    Future<Set<String>> Function(GraphDeleteRequest request);

/// A handler returning the attached ID, or `null` when no change was made.
typedef GraphAttachHandler =
    Future<String?> Function(GraphAttachRequest request);

/// The optional mutations owned by a module for one node kind.
class GraphNodeCommands {
  GraphNodeCommands({
    required this.kind,
    Set<String> parentKinds = const {},
    this.create,
    this.update,
    this.delete,
    this.attach,
  }) : parentKinds = Set.unmodifiable(parentKinds);

  final String kind;
  final Set<String> parentKinds;
  final GraphCreateHandler? create;
  final GraphUpdateHandler? update;
  final GraphDeleteHandler? delete;
  final GraphAttachHandler? attach;
}

/// Routes mutations to their owners and drains accepted work on removal.
///
/// Owners are removed before waiting, so new requests cannot enter a stopping
/// module. Errors remain with command callers and do not fail the drain itself.
class GraphCommandRegistry {
  final Map<String, _CommandOwner> _owners = {};
  final Map<String, Future<void>> _stopping = {};
  final Set<String> _reservedKinds = {};
  bool _disposed = false;
  Future<void>? _closing;

  bool canUpdate(String kind) => _find(kind)?.commands.update != null;
  bool canDelete(String kind) => _find(kind)?.commands.delete != null;

  /// Captures the current command owner for validating a delayed UI action.
  bool Function() guardFor(String kind) {
    final owner = _find(kind)?.owner;
    return () => owner != null && identical(_find(kind)?.owner, owner);
  }

  bool canCreate(String kind, String parentKind) {
    final command = _find(kind)?.commands;
    return command?.create != null && command!.parentKinds.contains(parentKind);
  }

  bool canAttach(String kind, String parentKind) {
    final command = _find(kind)?.commands;
    return command?.attach != null && command!.parentKinds.contains(parentKind);
  }

  /// Registers all commands atomically, rejecting duplicate kinds or owners.
  void register(String owner, Iterable<GraphNodeCommands> values) {
    if (_disposed) throw StateError('Graph commands are disposed.');
    if (_owners.containsKey(owner) || _stopping.containsKey(owner)) {
      throw ArgumentError('Graph command owner already registered: $owner');
    }
    final snapshot = List<GraphNodeCommands>.unmodifiable(values);
    final kinds = {..._reservedKinds};
    for (final command in snapshot) {
      if (!kinds.add(command.kind)) {
        throw ArgumentError('Duplicate graph commands: ${command.kind}');
      }
    }
    _owners[owner] = _CommandOwner(snapshot);
    _reservedKinds.addAll(snapshot.map((command) => command.kind));
  }

  /// Stops accepting the owner's commands and awaits its accepted work.
  Future<void> unregister(String owner) {
    final stopping = _stopping[owner];
    if (stopping != null) return stopping;
    final removed = _owners.remove(owner);
    if (removed == null) return Future.value();
    final draining = Future.wait(removed.pending.toList()).then<void>((_) {});
    _stopping[owner] = draining;
    unawaited(
      draining.then((_) {
        _stopping.remove(owner);
        _reservedKinds.removeAll(
          removed.commands.map((command) => command.kind),
        );
      }),
    );
    return draining;
  }

  Future<String> create(GraphCreateRequest request) async {
    final entry = _require(request.draft.kind);
    final handler = entry.commands.create;
    if (handler == null ||
        !entry.commands.parentKinds.contains(request.parent.kind)) {
      throw UnsupportedError(
        'Cannot create ${request.draft.kind} under ${request.parent.kind}.',
      );
    }
    return _run(entry.owner, () => handler(request));
  }

  Future<void> update(GraphUpdateRequest request) async {
    if (request.current.id != request.updated.id ||
        request.current.kind != request.updated.kind ||
        request.current.parentId != request.updated.parentId) {
      throw ArgumentError(
        'An edit cannot change node identity, kind or parent.',
      );
    }
    final entry = _require(request.current.kind);
    final handler = entry.commands.update;
    if (handler == null) {
      throw UnsupportedError('Cannot edit ${request.current.kind}.');
    }
    await _run(entry.owner, () => handler(request));
  }

  Future<Set<String>> delete(GraphDeleteRequest request) async {
    final entry = _require(request.node.kind);
    final handler = entry.commands.delete;
    if (handler == null) {
      throw UnsupportedError('Cannot delete ${request.node.kind}.');
    }
    return Set.unmodifiable(await _run(entry.owner, () => handler(request)));
  }

  Future<String?> attach(GraphAttachRequest request) async {
    final entry = _require(request.kind);
    final handler = entry.commands.attach;
    if (handler == null ||
        !entry.commands.parentKinds.contains(request.parent.kind)) {
      throw UnsupportedError(
        'Cannot attach ${request.kind} under ${request.parent.kind}.',
      );
    }
    return _run(entry.owner, () => handler(request));
  }

  Future<T> _run<T>(_CommandOwner owner, Future<T> Function() action) {
    final drained = Completer<void>();
    owner.pending.add(drained.future);
    void done() {
      owner.pending.remove(drained.future);
      drained.complete();
    }

    final result = Future<T>.sync(action);
    unawaited(
      result.then<void>(
        (_) => done(),
        onError: (Object _, StackTrace _) => done(),
      ),
    );
    return result;
  }

  ({_CommandOwner owner, GraphNodeCommands commands})? _find(String kind) {
    for (final owner in _owners.values) {
      for (final command in owner.commands) {
        if (command.kind == kind) return (owner: owner, commands: command);
      }
    }
    return null;
  }

  ({_CommandOwner owner, GraphNodeCommands commands}) _require(String kind) =>
      _find(kind) ??
      (throw UnsupportedError('No graph commands registered for $kind.'));

  Future<void> dispose() => _closing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    final owners = _owners.keys.toList();
    await Future.wait([...owners.map(unregister), ..._stopping.values]);
  }
}

class _CommandOwner {
  _CommandOwner(this.commands);
  final List<GraphNodeCommands> commands;
  final Set<Future<void>> pending = {};
}
