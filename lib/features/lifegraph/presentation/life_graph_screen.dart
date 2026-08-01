import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_edges_painter.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_node_widget.dart';
import 'package:life_os/features/lifegraph/presentation/components/node_edit_dialog.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';

class LifeGraphScreen extends StatefulWidget {
  final LifeGraphViewModel viewModel;
  const LifeGraphScreen({super.key, required this.viewModel});

  @override
  State<LifeGraphScreen> createState() => _LifeGraphScreenState();
}

class _LifeGraphScreenState extends State<LifeGraphScreen> {
  late final TransformationController _transformationController;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      appBar: AppBar(
        title: const Text('PULSE'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          StreamBuilder<List<Sphere>>(
            stream: widget.viewModel.spheresStream,
            builder: (context, snapshot) {
              final spheres = snapshot.data ?? [];
              if (spheres.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: DropdownButton<String>(
                  value: widget.viewModel.currentSphereId,
                  dropdownColor: AppColors.surfaceContainer,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  underline: const SizedBox(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                  items: spheres.map<DropdownMenuItem<String>>((s) => DropdownMenuItem(
                    value: s.id,
                    child: Text(s.name),
                  )).toList(),
                  onChanged: (id) {
                    if (id != null) widget.viewModel.switchSphere(id);
                  },
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: _showCreateSphereDialog,
          ),
        ],
      ),
      body: StreamBuilder<GraphData>(
        stream: widget.viewModel.graphStream,
        builder: (context, snapshot) {
          final graph = snapshot.data ?? GraphData.empty();

          if (widget.viewModel.currentSphereId == null) {
            return _EmptyState(onCreate: () => widget.viewModel.createSphere(name: 'Моя жизнь'));
          }

          var maxX = 0.0;
          var maxY = 0.0;
          for (final node in graph.nodes) {
            if (node.x > maxX) maxX = node.x;
            if (node.y > maxY) maxY = node.y;
          }
          final canvasW = math.max(4000.0, maxX + 1200);
          final canvasH = math.max(4000.0, maxY + 1200);

          return InteractiveViewer(
            transformationController: _transformationController,
            constrained: false,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: 0.3,
            maxScale: 3.0,
            child: Container(
              color: Colors.amber,
              width: canvasW,
              height: canvasH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Рёбра
                  CustomPaint(
                    painter: GraphEdgesPainter(
                      nodes: graph.nodes,
                      edges: graph.edges,
                      transformation: _transformationController.value,
                    ),
                    size: Size(canvasW, canvasH),
                  ),
                  // Ноды
                  ...graph.nodes.map((node) => _NodeWrapper(
                    node: node,
                    viewModel: widget.viewModel,
                    onTap: () => _showEditDialog(context, node),
                    onDragEnd: (dx, dy) => widget.viewModel.moveNode(node.id, dx, dy),
                    onAddChild: () => _showAddChildDialog(context, node),
                  )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateSphereDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Новая сфера жизни'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название (например: Работа, Семья, Здоровье)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.viewModel.createSphere(name: controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context, GraphNode node) {
    showDialog(
      context: context,
      builder: (ctx) => NodeEditDialog(
        node: node,
        onSave: (updated) => widget.viewModel.updateNode(updated),
        onDelete: (keepChildren) => widget.viewModel.deleteNode(node.id, keepChildren: keepChildren),
      ),
    );
  }

  void _showAddChildDialog(BuildContext context, GraphNode parentNode) {
    final controller = TextEditingController();
    String description = '';
    String? color;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: Text('Добавить ${_childTypeName(parentNode.type)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Название',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Описание',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (v) => description = v,
            ),
            const SizedBox(height: 12),
            const Text('Цвет:', style: TextStyle(color: AppColors.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((c) => _ColorChip(
                color: c,
                selected: color == c,
                onTap: () => setState(() => color = c),
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                widget.viewModel.addChild(
                  parentId: parentNode.id,
                  title: controller.text.trim(),
                  description: description,
                  color: color,
                );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
  }

  String _childTypeName(GraphNodeType type) {
    switch (type) {
      case GraphNodeType.sphere:
        return 'цель';
      case GraphNodeType.goal:
        return 'проект';
      case GraphNodeType.project:
        return 'задачу';
      case GraphNodeType.task:
        return '';
    }
  }

  static const List<String> _colors = [
    '#4A90D9', '#E8A838', '#4CAF50', '#E91E63', '#9C27B0',
    '#00BCD4', '#FF9800', '#795548', '#607D8B', '#F44336',
  ];
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.account_tree_rounded, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          const Text('Канвас пуст', style: TextStyle(color: Colors.white70, fontSize: 18)),
          const SizedBox(height: 8),
          const Text('Создайте первую сферу жизни', style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Создать сферу'),
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _NodeWrapper extends StatelessWidget {
  final GraphNode node;
  final LifeGraphViewModel viewModel;
  final VoidCallback onTap;
  final Function(double, double) onDragEnd;
  final VoidCallback onAddChild;

  const _NodeWrapper({
    required this.node,
    required this.viewModel,
    required this.onTap,
    required this.onDragEnd,
    required this.onAddChild,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: node.x,
      top: node.y,
      child: GestureDetector(
        onTap: onTap,
        onPanEnd: (details) => onDragEnd(node.x + details.localPosition.dx, node.y + details.localPosition.dy),
        child: GraphNodeWidget(
          node: node,
          onAddChild: node.isLeaf ? null : onAddChild,
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChip({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse(color.replaceFirst('#', '0xFF')));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: c.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ] : [],
        ),
      ),
    );
  }
}