import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;

abstract interface class GraphDeletion {
  Future<Set<String>> delete(
    GraphNodeType type,
    String id, {
    required bool keepChildren,
  });
}
