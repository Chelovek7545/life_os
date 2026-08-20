import 'package:life_os/features/tasks/domain/task_model.dart';

/// Тип ноды графа жизни: сфера -> цель -> проект -> задача.
enum GraphNodeType { sphere, goal, project, task, subTask }

/// Доменная нода графа. Описывает сущность из БД; позиция/рёбра — забота
/// view-слоя ([GraphView] выводит их сам из [parentId] и layout).
class GraphNode {
  final String id;
  final GraphNodeType type;
  final String title;
  final String subtitle;
  final String color;
  final String? parentId;
  final TaskStatus? taskStatus;

  const GraphNode({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.color,
    this.parentId,
    this.taskStatus,
  });

  /// Задача — лист, детей не имеет.
  bool get isLeaf => type == GraphNodeType.subTask;

  GraphNode copyWith({
    String? id,
    GraphNodeType? type,
    String? title,
    String? subtitle,
    String? color,
    String? parentId,
    TaskStatus? taskStatus,
  }) {
    return GraphNode(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      color: color ?? this.color,
      parentId: parentId ?? this.parentId,
      taskStatus: taskStatus ?? this.taskStatus,
    );
  }
}
