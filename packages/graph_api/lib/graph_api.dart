export 'src/graph_positions.dart';
import 'dart:async';
import 'src/graph_data.dart';
export 'src/graph_data.dart';
export 'src/commands.dart';

abstract interface class GraphContributor {
  String get id;
  Stream<List<GraphNodeData>> watch(GraphScope scope);
}

class GraphContributorRegistry {
  final Map<String, List<_TrackedContributor>> _owners = {};
  final _changes = StreamController<List<GraphContributor>>.broadcast();
  bool _disposed = false;
  Future<void>? _disposal;
  List<GraphContributor> get contributors =>
      List.unmodifiable(_owners.values.expand((items) => items));
  void register(String owner, Iterable<GraphContributor> values) {
    if (_disposed) throw StateError('Graph registry is disposed.');
    if (_owners.containsKey(owner)) {
      throw ArgumentError('Graph owner already registered: $owner');
    }
    final snapshot = List<GraphContributor>.unmodifiable(values);
    final ids = contributors.map((item) => item.id).toSet();
    for (final contributor in snapshot) {
      if (!ids.add(contributor.id)) {
        throw ArgumentError('Duplicate graph contributor: ${contributor.id}');
      }
    }
    _owners[owner] = [for (final value in snapshot) _TrackedContributor(value)];
    _changes.add(contributors);
  }

  Future<void> unregister(String owner) async {
    final removed = _owners.remove(owner);
    if (removed == null) return;
    try {
      await Future.wait(removed.map((contributor) => contributor.stop()));
    } finally {
      if (!_disposed) _changes.add(contributors);
    }
  }

  Stream<List<GraphContributor>> watch() => Stream.multi((listener) {
    listener.add(contributors);
    final subscription = _changes.stream.listen(
      listener.add,
      onError: listener.addError,
      onDone: listener.close,
    );
    listener.onCancel = subscription.cancel;
  }, isBroadcast: true);
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    final removed = _owners.values.expand((items) => items).toList();
    _owners.clear();
    try {
      await Future.wait(removed.map((contributor) => contributor.stop()));
    } finally {
      _changes.add(const []);
      await _changes.close();
    }
  }
}

class _TrackedContributor implements GraphContributor {
  _TrackedContributor(this.delegate);
  final GraphContributor delegate;
  final Set<Future<void> Function()> _leases = {};
  bool _stopped = false;
  @override
  String get id => delegate.id;

  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      Stream.multi((listener) {
        if (_stopped) {
          listener.add(const []);
          listener.close();
          return;
        }
        StreamSubscription<List<GraphNodeData>>? subscription;
        Future<void>? closing;
        late final Future<void> Function() cancel;
        cancel = () => closing ??= () async {
          try {
            await subscription?.cancel();
          } catch (error, stack) {
            listener.addError(error, stack);
            rethrow;
          } finally {
            _leases.remove(cancel);
            // Closing must not invoke the same failed cancellation again.
            listener.onCancel = null;
            listener.close();
          }
        }();
        _leases.add(cancel);
        listener.onCancel = cancel;
        try {
          subscription = delegate
              .watch(scope)
              .listen(
                listener.add,
                onError: listener.addError,
                onDone: () =>
                    unawaited(cancel().catchError((Object _, StackTrace _) {})),
              );
        } catch (error, stack) {
          listener.addError(error, stack);
          unawaited(cancel().catchError((Object _, StackTrace _) {}));
        }
      }, isBroadcast: true);

  Future<void> stop() async {
    _stopped = true;
    await Future.wait(_leases.toList().map((cancel) => cancel()));
  }
}
