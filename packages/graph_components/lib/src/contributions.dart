import 'package:flutter/widgets.dart';
import 'package:graph_ui/graph_ui.dart';
import 'component_spec.dart';
import 'graph_forms.dart';
import 'graph_node_card.dart';

GraphNodePresentation graphNodePresentation(GraphNodeComponentSpec spec) =>
    GraphNodePresentation(
      kind: spec.kind,
      size: spec.size,
      builder: (_, node, interaction) => GraphNodeCard(
        node: node,
        spec: spec,
        state: interaction,
        onTap: interaction.edit,
        onAddChild: interaction.addChild,
        onDelete: interaction.remove,
      ),
    );

GraphNodeEditor graphNodeEditor(GraphNodeComponentSpec spec) => GraphNodeEditor(
  kind: spec.kind,
  builder: (_, actions) => GraphNodeEditDialog(
    node: actions.node,
    spec: spec,
    onSave: actions.updateNode,
    onDelete: actions.deleteNode,
  ),
);

Widget graphChildForm(
  GraphNodeComponentSpec spec,
  GraphNodeActionContext actions,
) => GraphChildCreateDialog(
  spec: spec,
  onSave: (draft) async {
    await actions.createChild(draft);
  },
);
