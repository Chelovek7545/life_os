import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

enum NodeType { project, task, subtask, folder, note }

class HierarchyNode {
  final String id;
  final String title;
  final NodeType type;
  final IconData? icon;
  final Color? dotColor;
  final List<HierarchyNode> children;
  final bool isExpanded;
  final Object? data;

  HierarchyNode({
    required this.id,
    required this.title,
    required this.type,
    this.icon,
    this.dotColor,
    this.children = const [],
    this.isExpanded = false,
    this.data,
  });
}

/// Оптимизированное дерево иерархии.
/// Преобразует иерархию в плоский список видимых узлов, устраняя 
/// глубокую вложенность Widget Tree и избыточные вызовы rebuild.
class HierarchyColumn extends StatefulWidget {
  final List<HierarchyNode> nodes;
  final double indent;
  final double height;
  final Widget Function(HierarchyNode node, Widget child)? draggableBuilder;
  final void Function(HierarchyNode node)? onNodeTap;
  final Widget Function(HierarchyNode node)? trailingBuilder;
  final String emptyText;

  const HierarchyColumn({
    super.key,
    required this.nodes,
    this.indent = 16,
    this.draggableBuilder,
    this.onNodeTap,
    this.trailingBuilder,
    this.emptyText = 'Нет проектов', 
    required this.height,
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
      if (node.children.isNotEmpty) {
        _collectInitiallyExpanded(node.children);
      }
    }
  }

  @override
  void didUpdateWidget(HierarchyColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nodes != widget.nodes) {
      _collectInitiallyExpanded(widget.nodes);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (!_expandedIds.remove(id)) {
        _expandedIds.add(id);
      }
    });
  }

  // Обход дерева с плоским выходом только раскрытых элементов
  List<_FlatItem> _buildFlatList(List<HierarchyNode> nodes, int level) {
    final List<_FlatItem> items = [];
    for (final node in nodes) {
      final bool hasChildren = node.children.isNotEmpty;
      final bool isExpanded = _expandedIds.contains(node.id);

      items.add(_FlatItem(
        node: node,
        level: level,
        hasChildren: hasChildren,
        isExpanded: isExpanded,
      ));

      if (hasChildren && isExpanded) {
        items.addAll(_buildFlatList(node.children, level + 1));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            widget.emptyText,
            style: const TextStyle(color: Colors.white38),
          ),
        ),
      );
    }

    final flatItems = _buildFlatList(widget.nodes, 0);

    return Container(
      height: widget.height,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: ListView.builder(
        itemCount: flatItems.length,
        itemBuilder: (context, index) {
          final item = flatItems[index];
          return           
            _NodeTile(
              key: ValueKey(item.node.id),
              item: item,
              indent: widget.indent,
              onToggle: () => _toggle(item.node.id),
              onTap: widget.onNodeTap != null
                  ? () => widget.onNodeTap!(item.node)
                  : null,
              trailing: widget.trailingBuilder?.call(item.node),
              draggableBuilder: widget.draggableBuilder,
            );
        })
    );
  }
}

class _FlatItem {
  final HierarchyNode node;
  final int level;
  final bool hasChildren;
  final bool isExpanded;

  const _FlatItem({
    required this.node,
    required this.level,
    required this.hasChildren,
    required this.isExpanded,
  });
}

class _NodeTile extends StatelessWidget {
  final _FlatItem item;
  final double indent;
  final VoidCallback onToggle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget Function(HierarchyNode node, Widget child)? draggableBuilder;

  const _NodeTile({
    super.key,
    required this.item,
    required this.indent,
    required this.onToggle,
    required this.onTap,
    this.trailing,
    this.draggableBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final node = item.node;
    final level = item.level;

    Widget tile = InkWell(
      onTap: item.hasChildren ? onToggle : onTap,
      borderRadius: BorderRadius.circular(8),
      hoverColor: AppColors.surfaceContainerHigh,
      child: Padding(
        padding: EdgeInsets.only(
          left: 8.0 + (level * indent),
          right: 8.0,
          top: 4.0,
          bottom: 4.0,
        ),
        child: Row(
          children: [
            if (item.hasChildren)
              Icon(
                item.isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                size: 18,
                color: level == 0
                    ? AppColors.primary
                    : AppColors.onSurfaceVariant,
              )
            else
              const SizedBox(width: 18),
            const SizedBox(width: 4),
            _buildNodeIcon(node, item.isExpanded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                node.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: level >= 2 ? 12 : 14,
                  fontFamily: 'JetBrainsMono',
                  fontWeight: (level == 0 || node.type == NodeType.folder)
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: level == 0
                      ? AppColors.onSurface
                      : level == 1
                          ? AppColors.onSurface.withValues(alpha: 0.85)
                          : AppColors.onSurfaceVariant,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );

    if (draggableBuilder != null) {
      tile = draggableBuilder!(node, tile);
    }

    return tile;
  }

  Widget _buildNodeIcon(HierarchyNode node, bool isExpanded) {
    switch (node.type) {
      case NodeType.project:
        return Icon(
          node.icon ?? Icons.folder,
          size: 18,
          color: node.dotColor ?? AppColors.primary,
        );
      case NodeType.folder:
        return Icon(
          node.icon ??
              (isExpanded
                  ? Icons.folder_open_rounded
                  : Icons.folder_rounded),
          size: 18,
          color: node.dotColor ?? Colors.amber.shade600,
        );
      case NodeType.note:
        return Icon(
          node.icon ?? Icons.description_outlined,
          size: 18,
          color: node.dotColor ?? AppColors.primaryContainer,
        );
      case NodeType.task:
        return Icon(
          node.icon ?? Icons.check_box_outline_blank,
          size: 16,
          color: node.dotColor ?? AppColors.onSurfaceVariant,
        );
      case NodeType.subtask:
        return Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: node.dotColor ?? AppColors.primary.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        );
    }
  }
}