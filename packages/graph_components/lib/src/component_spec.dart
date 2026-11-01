import 'package:flutter/widgets.dart';
import 'package:graph_api/graph_api.dart';

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
    this.createColor = true,
    this.createDescription = true,
    this.editFields,
    this.createFields,
    this.badge,
  });
  final String kind;
  final String label;
  final IconData icon;
  final Size size;
  final String editTitle;
  final String createTitle;
  final bool round;
  final bool editColor;
  final bool createColor;
  final bool createDescription;
  final GraphAttributesBuilder? editFields;
  final GraphAttributesBuilder? createFields;
  final Widget? Function(BuildContext, GraphNodeData)? badge;
}
