class GraphScope {
  const GraphScope({required this.rootId, required this.rootKind});
  final String rootId;
  final String rootKind;
}

class GraphNodeData {
  GraphNodeData({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle = '',
    required this.color,
    this.parentId,
    this.inheritParentColor = false,
    Map<String, Object?> attributes = const {},
  }) : attributes = Map.unmodifiable(attributes);
  final String id;
  final String kind;
  final String title;
  final String subtitle;
  final String color;
  final String? parentId;
  final bool inheritParentColor;
  final Map<String, Object?> attributes;
  GraphNodeData withColor(String value) => GraphNodeData(
    id: id,
    kind: kind,
    title: title,
    subtitle: subtitle,
    color: value,
    parentId: parentId,
    inheritParentColor: inheritParentColor,
    attributes: attributes,
  );
}
