import 'package:graph_api/graph_api.dart';
import 'package:tasks_api/tasks_api.dart';

enum GraphNodeType { sphere, goal, project, task, subTask, external }

class GraphNode {
  const GraphNode({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.color,
    this.parentId,
    this.taskStatus,
    String? kind,
    this.attributes = const {},
  }) : _kind = kind;
  final String id;
  final GraphNodeType type;
  final String title;
  final String subtitle;
  final String color;
  final String? parentId;
  final TaskStatus? taskStatus;
  final String? _kind;
  final Map<String, Object?> attributes;
  String get kind => _kind ?? type.name;
  bool get isLeaf =>
      type == GraphNodeType.subTask || type == GraphNodeType.external;

  factory GraphNode.fromData(GraphNodeData data) {
    final status = data.attributes['taskStatus'];
    return GraphNode(
      id: data.id,
      type: GraphNodeType.values.firstWhere(
        (type) => type != GraphNodeType.external && type.name == data.kind,
        orElse: () => GraphNodeType.external,
      ),
      kind: data.kind,
      title: data.title,
      subtitle: data.subtitle,
      color: data.color,
      parentId: data.parentId,
      taskStatus: status is String ? taskStatusFromStorage(status) : null,
      attributes: data.attributes,
    );
  }

  GraphNodeData toData() => GraphNodeData(
    id: id,
    kind: kind,
    title: title,
    subtitle: subtitle,
    color: color,
    parentId: parentId,
    attributes: {
      ...attributes,
      if (taskStatus != null) 'taskStatus': taskStatus!.name,
    },
  );

  GraphNode copyWith({
    String? id,
    GraphNodeType? type,
    String? title,
    String? subtitle,
    String? color,
    String? parentId,
    TaskStatus? taskStatus,
  }) => GraphNode(
    id: id ?? this.id,
    type: type ?? this.type,
    kind: _kind,
    attributes: attributes,
    title: title ?? this.title,
    subtitle: subtitle ?? this.subtitle,
    color: color ?? this.color,
    parentId: parentId ?? this.parentId,
    taskStatus: taskStatus ?? this.taskStatus,
  );
}
