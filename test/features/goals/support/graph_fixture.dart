import 'package:graph_api/graph_api.dart';

const scope = GraphScope(rootId: 'sphere', rootKind: 'sphere');
GraphNodeData node(
  String id,
  String kind, {
  String? parent,
  String title = 'Edited',
}) => GraphNodeData(
  id: id,
  kind: kind,
  title: title,
  subtitle: 'Description',
  color: '#123456',
  parentId: parent,
);
