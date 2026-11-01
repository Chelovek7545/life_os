import 'package:flutter/widgets.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import '../../domain/graph_node.dart';
import 'node_edit_dialog.dart';
import 'graph_node_card.dart';
import 'graph_node_sizes.dart';

GraphNodePresentation builtinGraphPresentation(GraphNodeType type) =>
    GraphNodePresentation(
      kind: type.name,
      size: graphNodeSizeOf(type),
      builder: (_, node, interaction) => GraphNodeCard(
        state: interaction,
        node: GraphNode.fromData(node),
        onTap: interaction.edit,
        onAddChild: interaction.addChild,
        onDelete: interaction.remove,
      ),
    );

GraphNodeEditor builtinGraphEditor(GraphNodeType type) => GraphNodeEditor(
  kind: type.name,
  builder: (_, actions) => NodeEditDialog(
    node: GraphNode.fromData(actions.node),
    onSave: (updated) => actions.updateNode(updated.toData()),
    onDelete: actions.deleteNode,
  ),
);

Widget builtinGraphChildForm(
  GraphNodeType type,
  GraphNodeActionContext actions,
) => AddChildDialog(
  childNodeType: type,
  onSave:
      ({
        required title,
        required description,
        color,
        dueDate,
        startsAt,
        endsAt,
      }) async {
        await actions.createChild(
          GraphNodeDraft(
            kind: type.name,
            title: title,
            subtitle: description,
            color: color,
            attributes: {
              'dueDate': dueDate,
              'startsAt': startsAt,
              'endsAt': endsAt,
            },
          ),
        );
      },
);
