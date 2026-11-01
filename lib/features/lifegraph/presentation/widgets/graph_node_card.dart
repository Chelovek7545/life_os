import 'package:flutter/widgets.dart';
import 'package:graph_components/graph_components.dart' as components;
import 'package:graph_ui/graph_ui.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNode;
import 'legacy_graph_component_spec.dart';

class GraphNodeCard extends StatelessWidget {
  const GraphNodeCard({
    super.key,
    required this.state,
    required this.node,
    required this.onTap,
    required this.onAddChild,
    required this.onDelete,
  });
  final GraphNodeInteraction state;
  final GraphNode node;
  final VoidCallback? onTap;
  final VoidCallback? onAddChild;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => components.GraphNodeCard(
    state: state,
    node: node.toData(),
    spec: legacyGraphComponentSpec(node.type),
    onTap: onTap,
    onAddChild: onAddChild,
    onDelete: onDelete,
  );
}
