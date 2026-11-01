import 'graph_node.dart';

abstract interface class GraphDeletion {
  Future<Set<String>> delete(
    GraphNodeType type,
    String id, {
    required bool keepChildren,
  });
}
