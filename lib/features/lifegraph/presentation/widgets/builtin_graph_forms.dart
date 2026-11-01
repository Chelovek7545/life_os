import 'package:flutter/widgets.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'legacy_graph_component_spec.dart';

// Compatibility entry points. Module adapters use graph_components directly.
GraphNodePresentation builtinGraphPresentation(GraphNodeType type) =>
    graphNodePresentation(legacyGraphComponentSpec(type));
GraphNodeEditor builtinGraphEditor(GraphNodeType type) =>
    graphNodeEditor(legacyGraphComponentSpec(type));
Widget builtinGraphChildForm(
  GraphNodeType type,
  GraphNodeActionContext actions,
) => graphChildForm(legacyGraphComponentSpec(type), actions);
