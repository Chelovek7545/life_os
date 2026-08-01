import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

class GraphNodeWidget extends StatelessWidget {
  final GraphNode node;
  final VoidCallback? onAddChild;

  const GraphNodeWidget({
    super.key,
    required this.node,
    this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(node.color.replaceFirst('#', '0xFF')));
    final isSphere = node.type == GraphNodeType.sphere;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Основная карточка ноды
        Container(
          width: _width,
          height: _height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(isSphere ? 70 : 16),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Заголовок
              Row(
                children: [
                  Icon(_icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.title,
                      style: TextStyle(
                        color: AppColors.onSurface,
                        fontSize: isSphere ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (node.subtitle.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  node.subtitle,
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              // Статус задачи
              if (node.type == GraphNodeType.task && node.taskStatus != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(node.taskStatus!).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _statusLabel(node.taskStatus!),
                    style: TextStyle(
                      color: _statusColor(node.taskStatus!),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // Кнопка добавления ребёнка
        if (onAddChild != null)
          Positioned(
            right: -12,
            top: _height / 2 - 12,
            child: GestureDetector(
              onTap: onAddChild,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, size: 14, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }

  double get _width {
    switch (node.type) {
      case GraphNodeType.sphere:
        return 140;
      case GraphNodeType.goal:
        return 180;
      case GraphNodeType.project:
        return 180;
      case GraphNodeType.task:
        return 160;
    }
  }

  double get _height {
    switch (node.type) {
      case GraphNodeType.sphere:
        return 140;
      case GraphNodeType.goal:
        return 100;
      case GraphNodeType.project:
        return 100;
      case GraphNodeType.task:
        return 80;
    }
  }

  IconData get _icon {
    switch (node.type) {
      case GraphNodeType.sphere:
        return Icons.public_rounded;
      case GraphNodeType.goal:
        return Icons.flag_rounded;
      case GraphNodeType.project:
        return Icons.folder_rounded;
      case GraphNodeType.task:
        return Icons.task_alt_rounded;
    }
  }

  Color _statusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.done:
        return Colors.green;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.notStarted:
        return Colors.orange;
      case TaskStatus.open:
        return Colors.grey;
    }
  }

  String _statusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.done:
        return 'Выполнено';
      case TaskStatus.inProgress:
        return 'В процессе';
      case TaskStatus.notStarted:
        return 'Не начато';
      case TaskStatus.open:
        return 'Открыто';
    }
  }
}