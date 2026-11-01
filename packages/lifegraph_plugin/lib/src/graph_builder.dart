import 'package:graph_api/graph_api.dart';
import 'package:rxdart/rxdart.dart';
import 'package:plugin_runtime/owned_streams.dart';

class GraphBuilder {
  GraphBuilder({required this.registry, required this.rootKind});
  final GraphContributorRegistry registry;
  final String rootKind;
  final _streams = OwnedStreams();
  Future<void> dispose() => _streams.close();

  Stream<List<GraphNodeData>> watchGraph(String rootId) =>
      _streams.watch(() => _watchGraph(rootId));

  Stream<List<GraphNodeData>> _watchGraph(String rootId) {
    final scope = GraphScope(rootId: rootId, rootKind: rootKind);
    return registry.watch().switchMap((contributors) {
      if (contributors.isEmpty) return Stream.value(const <GraphNodeData>[]);
      return Rx.combineLatestList(
        contributors.map((contributor) => contributor.watch(scope)),
      ).map((snapshots) => _project(scope, snapshots));
    });
  }

  List<GraphNodeData> _project(
    GraphScope scope,
    List<List<GraphNodeData>> snapshots,
  ) {
    final byId = <String, GraphNodeData>{};
    for (final nodes in snapshots) {
      for (final node in nodes) {
        if (byId.containsKey(node.id)) {
          throw StateError('Duplicate graph node ID: ${node.id}');
        }
        byId[node.id] = node;
      }
    }
    final root = byId[scope.rootId];
    if (root == null || root.kind != scope.rootKind) return const [];
    if (root.parentId != null) {
      throw StateError('Graph root cannot have a parent.');
    }
    final children = <String, List<GraphNodeData>>{};
    for (final node in byId.values) {
      if (node.parentId != null) (children[node.parentId!] ??= []).add(node);
    }
    final result = <GraphNodeData>[root];
    final visited = <String>{root.id};
    for (var index = 0; index < result.length; index++) {
      final parent = result[index];
      for (final child in children[parent.id] ?? const <GraphNodeData>[]) {
        if (!visited.add(child.id)) continue;
        result.add(
          child.inheritParentColor ? child.withColor(parent.color) : child,
        );
      }
    }
    return List.unmodifiable(result);
  }
}
