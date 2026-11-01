import 'package:flutter/widgets.dart';
import 'package:graph_components/graph_components.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart'
    show GraphNode, GraphNodeType;
import 'legacy_graph_component_spec.dart';

class NodeEditDialog extends StatelessWidget {
  const NodeEditDialog({
    super.key,
    required this.node,
    required this.onSave,
    required this.onDelete,
  });
  final GraphNode node;
  final Future<void> Function(GraphNode) onSave;
  final Future<void> Function(bool) onDelete;
  @override
  Widget build(BuildContext context) => GraphNodeEditDialog(
    node: node.toData(),
    spec: legacyGraphComponentSpec(node.type),
    onSave: (updated) => onSave(GraphNode.fromData(updated)),
    onDelete: onDelete,
  );
}

class AddChildDialog extends StatelessWidget {
  const AddChildDialog({
    super.key,
    required this.childNodeType,
    required this.onSave,
  });
  final GraphNodeType childNodeType;
  final Future<void> Function({
    required String title,
    required String description,
    String? color,
    DateTime? dueDate,
    DateTime? startsAt,
    DateTime? endsAt,
  })
  onSave;
  @override
  Widget build(BuildContext context) => GraphChildCreateDialog(
    spec: legacyGraphComponentSpec(childNodeType),
    onSave: (draft) => onSave(
      title: draft.title,
      description: draft.subtitle,
      color: draft.color,
      dueDate: draft.attributes['dueDate'] as DateTime?,
      startsAt: draft.attributes['startsAt'] as DateTime?,
      endsAt: draft.attributes['endsAt'] as DateTime?,
    ),
  );
}
