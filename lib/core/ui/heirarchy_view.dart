import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

enum NodeType { project, task, subtask }

class HierarchyNode {
  final String id;
  final String title;
  final NodeType type;
  final IconData? icon;
  final Color? dotColor;
  final List<HierarchyNode> children;
  final bool isExpanded;

  HierarchyNode({
    required this.id,
    required this.title,
    required this.type,
    this.icon,
    this.dotColor,
    this.children = const [],
    this.isExpanded = false,
  });
}

/// Древовидный список иерархии: проект -> задача -> subtask.
/// Состояние раскрытия хранится внутри и переживает пересборки с новыми
/// данными (не сбрасывается при каждом стриме).
///
/// Рендерится обычной Column (не ListView), чтобы безопасно встраиваться
/// в любой контекст (внешний ListView на mobile, SingleChildScrollView
/// в панели split-вида). Скролл обеспечивает обёртка в панели.
class HierarchyColumn extends StatefulWidget {
  final List<HierarchyNode> nodes;
  final double indent;

  const HierarchyColumn({
    super.key,
    required this.nodes,
    this.indent = 18,
  });

  @override
  State<HierarchyColumn> createState() => _HierarchyColumnState();
}

class _HierarchyColumnState extends State<HierarchyColumn> {
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    _collectInitiallyExpanded(widget.nodes);
  }

  void _collectInitiallyExpanded(List<HierarchyNode> nodes) {
    for (final node in nodes) {
      if (node.isExpanded) _expandedIds.add(node.id);
      _collectInitiallyExpanded(node.children);
    }
  }

  bool _isExpanded(HierarchyNode node) => _expandedIds.contains(node.id);

  void _toggle(HierarchyNode node) {
    setState(() {
      if (!_expandedIds.add(node.id)) {
        _expandedIds.remove(node.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Нет проектов',
            style: TextStyle(color: Colors.white38),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final node in widget.nodes)
            _buildNodeTile(node, level: 0),
        ],
      ),
    );
  }

  Widget _buildNodeTile(HierarchyNode node, {required int level}) {
    final bool hasChildren = node.children.isNotEmpty;
    final bool expanded = _isExpanded(node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: hasChildren ? () => _toggle(node) : null,
          borderRadius: BorderRadius.circular(8),
          hoverColor: AppColors.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              children: [
                if (hasChildren)
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_right,
                    size: 18,
                    color: level == 0 ? AppColors.primary : AppColors.onSurfaceVariant,
                  )
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 4),

                if (node.type == NodeType.project)
                  Icon(
                    node.icon ?? Icons.folder,
                    size: 18,
                    color: node.dotColor ?? AppColors.primary,
                  )
                else if (node.type == NodeType.subtask)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: node.dotColor ?? AppColors.primary.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    node.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: level == 2 ? 12 : 14,
                      fontFamily: 'JetBrainsMono',
                      fontWeight: level == 0 ? FontWeight.w600 : FontWeight.w400,
                      color: level == 0
                          ? AppColors.onSurface
                          : level == 1
                              ? AppColors.onSurface.withValues(alpha: 0.8)
                              : AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (hasChildren && expanded)
          Padding(
            padding: EdgeInsets.only(left: widget.indent),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.borderGlass, width: 1),
                ),
              ),
              child: Column(
                children: node.children
                    .map((child) => _buildNodeTile(child, level: level + 1))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}
