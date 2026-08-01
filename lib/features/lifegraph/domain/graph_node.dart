import 'package:life_os/features/tasks/domain/task_model.dart';

enum GraphNodeType { sphere, goal, project, task }

class GraphNode {
  final String id;
  final GraphNodeType type;
  final String title;
  final String subtitle;
  final String color;
  final String? parentId;
  final double x;
  final double y;
  final TaskStatus? taskStatus;

  const GraphNode({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.color,
    this.parentId,
    required this.x,
    required this.y,
    this.taskStatus,
  });

  bool get isLeaf => type == GraphNodeType.task;

  GraphNode copyWith({
    String? id,
    GraphNodeType? type,
    String? title,
    String? subtitle,
    String? color,
    String? parentId,
    double? x,
    double? y,
    TaskStatus? taskStatus,
  }) {
    return GraphNode(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      x: x ?? this.x,
      y: y ?? this.y,
      taskStatus: taskStatus ?? this.taskStatus,
    );
  }
}

class GraphEdge {
  final String fromId;
  final String toId;

  const GraphEdge({required this.fromId, required this.toId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GraphEdge && runtimeType == other.runtimeType && fromId == other.fromId && toId == other.toId;

  @override
  int get hashCode => fromId.hashCode ^ toId.hashCode;
}

class GraphData {
  final List<GraphNode> nodes;
  final List<GraphEdge> edges;

  const GraphData({required this.nodes, required this.edges});

  factory GraphData.empty() => const GraphData(nodes: [], edges: []);
}
