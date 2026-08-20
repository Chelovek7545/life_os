import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/core/ui/graph/graph_view.dart' as graph;
import 'package:life_os/features/tasks/domain/task_model.dart';

/// Карточка ноды в стиле приложения для кастомного nodeBuilder GraphView.
/// Сфера — круглая нода с иконкой; цель/проект/задача — карточки с акцентной
/// полосой, иконкой типа, названием, описанием и статусом (для задач).
/// Кнопка «+» открывает диалог создания следующего уровня иерархии.
class GraphNodeCard extends StatefulWidget {
  final graph.NodeState state;
  final GraphNode node;
  final VoidCallback onTap;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;

  const GraphNodeCard({
    super.key,
    required this.state,
    required this.node,
    required this.onTap,
    required this.onAddChild,
    required this.onDelete,
  });

  @override
  State<GraphNodeCard> createState() => _GraphNodeCardState();
}

class _GraphNodeCardState extends State<GraphNodeCard> {
  bool _hovered = false;
  bool _plusHovered = false;
  bool _plusPressed = false;

  Color get _accent => parseHexColor(widget.node.color);

  bool get _isSphere => widget.node.type == GraphNodeType.sphere;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final size = widget.state.size;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.state.select();
              widget.onTap();
            },
            onPanStart: widget.state.dragStart,
            onPanUpdate: widget.state.dragUpdate,
            onPanEnd: widget.state.dragEnd,
            onPanCancel: () => widget.state.dragEnd(DragEndDetails()),
            child: AnimatedScale(
              scale: _hovered ? 1.03 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  color: _hovered ? AppColors.surfaceBright : AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(_isSphere ? size.width / 2 : 13),
                  border: Border.all(
                    color: widget.state.selected ? Colors.white : _accent.withValues(alpha: 0.55),
                    width: widget.state.selected ? 1.6 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.state.selected
                          ? _accent.withValues(alpha: 0.45)
                          : _accent.withValues(alpha: 0.18),
                      blurRadius: widget.state.selected ? 20 : 14,
                      spreadRadius: widget.state.selected ? 1 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isSphere ? _buildSphereContent(n) : _buildRectContent(n),
              ),
            ),
          ),

          if (_hovered)
            Positioned(
              top: -9,
              right: -9,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceBright,
                      border: Border.all(color: AppColors.borderGlass),
                    ),
                    child: const Icon(Icons.close, size: 12, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ),
            ),

          if (!n.isLeaf)
            Positioned(
              right: -15,
              top: size.height / 2 - 16,
              child: Tooltip(
                message: 'Добавить ${_childName(n.type)}',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => setState(() => _plusHovered = true),
                  onExit: (_) => setState(() {
                    _plusHovered = false;
                    _plusPressed = false;
                  }),
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _plusPressed = true),
                    onTapCancel: () => setState(() => _plusPressed = false),
                    onTapUp: (_) {
                      setState(() => _plusPressed = false);
                      widget.onAddChild();
                    },
                    child: AnimatedScale(
                      scale: _plusPressed ? 0.85 : (_plusHovered ? 1.14 : 1),
                      duration: const Duration(milliseconds: 140),
                      curve: Curves.easeOutBack,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _plusHovered
                              ? Color.lerp(_accent, Colors.white, 0.18)!
                              : _accent,
                          border: Border.all(color: AppColors.surfaceDim, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3)),
                          ],
                        ),
                        child: const Icon(Icons.add, size: 17, color: Color(0xFF08161B)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSphereContent(GraphNode n) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.18),
              border: Border.all(color: _accent.withValues(alpha: 0.6), width: 1.5),
            ),
            child: Icon(_iconOf(n.type), color: _accent, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            n.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRectContent(GraphNode n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 5,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 22, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _typeLabel(n.type),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: _accent.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(_iconOf(n.type), color: _accent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (n.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    n.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.onSurfaceVariant, fontSize: 10.5),
                  ),
                ],
                if (n.type == GraphNodeType.task && n.taskStatus != null) ...[
                  const SizedBox(height: 5),
                  _StatusChip(status: n.taskStatus!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _childName(GraphNodeType type) {
    switch (type) {
      case GraphNodeType.sphere:
        return 'цель';
      case GraphNodeType.goal:
        return 'проект';
      case GraphNodeType.project:
        return 'задачу';
      case GraphNodeType.task:
        return 'подзадачу';
      case GraphNodeType.subTask:
        return '';
    }
  }

  String _typeLabel(GraphNodeType type) {
    switch (type) {
      case GraphNodeType.sphere:
        return 'СФЕРА';
      case GraphNodeType.goal:
        return 'ЦЕЛЬ';
      case GraphNodeType.project:
        return 'ПРОЕКТ';
      case GraphNodeType.task:
        return 'ЗАДАЧА';
      case GraphNodeType.subTask:
        return 'ПОДЗАДАЧА';
    }
  }

  IconData _iconOf(GraphNodeType type) {
    switch (type) {
      case GraphNodeType.sphere:
        return Icons.public_rounded;
      case GraphNodeType.goal:
        return Icons.flag_rounded;
      case GraphNodeType.project:
        return Icons.folder_rounded;
      case GraphNodeType.task:
        return Icons.task_alt_rounded;
      case GraphNodeType.subTask:
        return Icons.task_alt_rounded;
    }
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _statusColor(status).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(color: _statusColor(status), fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  Color _statusColor(TaskStatus status) {
    return status.color;
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
