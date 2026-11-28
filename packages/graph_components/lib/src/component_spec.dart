import 'package:flutter/widgets.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';

typedef GraphAttributesBuilder =
    Widget Function(
      BuildContext context,
      Map<String, Object?> attributes,
      ValueChanged<Map<String, Object?>> onChanged,
    );

class GraphNodeComponentSpec {
  const GraphNodeComponentSpec({
    required this.kind,
    required this.label,
    required this.icon,
    required this.size,
    required this.editTitle,
    required this.createTitle,
    this.round = false,
    this.editColor = true,
    this.descriptionForEdit,
    this.createColor = true,
    this.createDescription = true,
    this.editFields,
    this.validateEdit,
    this.createFields,
    this.badge,
    this.details,
    this.leading,
  });
  final String kind;
  final String label;
  final IconData icon;
  final Size size;
  final String editTitle;
  final String createTitle;
  final bool round;
  final bool editColor;
  final String? Function(GraphNodeData)? descriptionForEdit;
  final bool createColor;
  final bool createDescription;
  final GraphAttributesBuilder? editFields;
  final String? Function(GraphNodeData original, GraphNodeData updated)?
  validateEdit;
  final GraphAttributesBuilder? createFields;
  final Widget? Function(BuildContext, GraphNodeData)? badge;
  final Widget? Function(BuildContext, GraphNodeData, GraphNodeInteraction)?
  details;
  final Widget Function(BuildContext, GraphNodeData, GraphNodeInteraction)?
  leading;
}
