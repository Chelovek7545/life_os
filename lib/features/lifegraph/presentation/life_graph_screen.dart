import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_edges_painter.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_grid_painter.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_hud_button.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_node_card.dart';
import 'package:life_os/features/lifegraph/presentation/components/graph_node_sizes.dart';
import 'package:life_os/features/lifegraph/presentation/components/node_edit_dialog.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';

class LifeGraphScreen extends StatefulWidget {
  final LifeGraphViewModel viewModel;
  const LifeGraphScreen({super.key, required this.viewModel});

  @override
  State<LifeGraphScreen> createState() => _LifeGraphScreenState();
}

class _LifeGraphScreenState extends State<LifeGraphScreen>
    with TickerProviderStateMixin {
  late final TransformationController _transformationController;
  final GlobalKey _viewerKey = GlobalKey();

  late final AnimationController _revealCtrl;
  late final CurvedAnimation _revealCurved;
  Map<String, double> _reveals = {};
  final Set<String> _seenIds = {};

  late final AnimationController _flyCtrl;
  Animation<Matrix4>? _flyAnim;

  String? _centeredSphereId;
  String? _dragNodeId;
  final ValueNotifier<Offset> _dragDelta = ValueNotifier(Offset.zero);
  final Map<String, Offset> _dragTargets = {};

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _revealCurved = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic);
    _revealCtrl.addListener(_onRevealTick);
    _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _flyCtrl.dispose();
    _dragDelta.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  // ── Камера ─────────────────────────────────────────────────────────────────

  RenderBox? get _viewerBox =>
      _viewerKey.currentContext?.findRenderObject() as RenderBox?;

  void _flyTo(Matrix4 target) {
    _flyAnim?.removeListener(_applyFly);
    _flyAnim = Matrix4Tween(begin: _transformationController.value.clone(), end: target).animate(
      CurvedAnimation(parent: _flyCtrl, curve: Curves.easeInOutCubic),
    )..addListener(_applyFly);
    _flyCtrl.forward(from: 0);
  }

  void _applyFly() => _transformationController.value = _flyAnim!.value;

  void _fitView({bool animate = true}) {
    final nodes = widget.viewModel.graph.nodes;
    final box = _viewerBox;
    if (nodes.isEmpty || box == null) return;

    var rect = Rect.fromLTWH(
      nodes.first.x,
      nodes.first.y,
      graphNodeWidth(nodes.first.type),
      graphNodeHeight(nodes.first.type),
    );
    for (final n in nodes) {
      rect = rect.expandToInclude(
        Rect.fromLTWH(n.x, n.y, graphNodeWidth(n.type), graphNodeHeight(n.type)),
      );
    }
    rect = rect.inflate(150);

    final vp = box.size;
    final s = math.min(vp.width / rect.width, vp.height / rect.height).clamp(0.25, 1.2);
    final m = Matrix4.translationValues(
      vp.width / 2 - s * rect.center.dx,
      vp.height / 2 - s * rect.center.dy,
      0,
    )..multiply(Matrix4.diagonal3Values(s, s, 1));
    animate ? _flyTo(m) : _transformationController.value = m;
  }

  void _zoomBy(double f) {
    final box = _viewerBox;
    if (box == null) return;
    final s0 = _transformationController.value.getMaxScaleOnAxis();
    final s1 = (s0 * f).clamp(0.25, 3.0);
    f = s1 / s0;

    final c = _transformationController.toScene(box.size.center(Offset.zero));
    final around = Matrix4.translationValues(c.dx, c.dy, 0)
      ..multiply(Matrix4.diagonal3Values(f, f, 1))
      ..multiply(Matrix4.translationValues(-c.dx, -c.dy, 0));
    _flyTo(_transformationController.value.clone()..multiply(around));
  }

  // ── Reveal-анимация рёбер ──────────────────────────────────────────────────

  void _syncReveals(GraphData graph) {
    final currentIds = <String>{for (final n in graph.nodes) n.id};
    var needAnim = false;
    for (final n in graph.nodes) {
      if (n.parentId != null && !_seenIds.contains(n.id)) {
        _reveals['${n.parentId}>${n.id}'] = 0;
        needAnim = true;
      }
    }
    _seenIds
      ..retainAll(currentIds)
      ..addAll(currentIds);
    if (needAnim) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealCtrl.forward(from: 0);
      });
    }
  }

  void _onRevealTick() {
    final v = _revealCurved.value;
    var dirty = false;
    final copy = Map<String, double>.of(_reveals);
    for (final k in copy.keys) {
      if (copy[k]! < 1) {
        copy[k] = v;
        dirty = true;
      }
    }
    if (dirty) {
      _reveals = copy;
      setState(() {});
    }
  }

  Map<String, int> _depthOf(List<GraphNode> nodes) {
    final depth = <String, int>{};
    for (final n in nodes) {
      if (n.parentId == null) depth[n.id] = 0;
    }
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in nodes) {
        final p = n.parentId;
        if (p != null && depth.containsKey(p) && !depth.containsKey(n.id)) {
          depth[n.id] = depth[p]! + 1;
          grew = true;
        }
      }
    }
    return depth;
  }

  // ── Drag нод ───────────────────────────────────────────────────────────────

  void _handleDragStart(GraphNode node) {
    _dragTargets.remove(node.id);
    _dragDelta.value = Offset.zero;
    setState(() {
      _dragNodeId = node.id;
    });
  }

  void _handlePanUpdate(GraphNode node, double dx, double dy) {
    if (_dragNodeId == null) return;
    // Клампим визуальную позицию ноды внутрь мирового канваса, чтобы она
    // не уходила за границы и не становилась «мёртвой» для жестов.
    final maxX = graphWorldSize - graphNodeWidth(node.type) - graphWorldMargin;
    final maxY = graphWorldSize - graphNodeHeight(node.type) - graphWorldMargin;
    final base = Offset(node.x, node.y);
    final current = base + _dragDelta.value;
    final target = Offset(
      (current.dx + dx).clamp(graphWorldMargin, maxX),
      (current.dy + dy).clamp(graphWorldMargin, maxY),
    );
    _dragDelta.value = target - base;
  }

  void _handleDragEnd(GraphNode node) {
    final delta = _dragDelta.value;
    if (delta == Offset.zero) {
      _dragTargets.remove(node.id);
      setState(() {
        _dragNodeId = null;
      });
      return;
    }
    // Не сбрасываем overlay: нода остаётся на месте сброса до тех пор,
    // пока граф не подтвердит сохранённую позицию (см. _resolvePendingDrag).
    final target = Offset(node.x + delta.dx, node.y + delta.dy);
    _dragTargets[node.id] = target;
    widget.viewModel.moveNode(node.id, target.dx, target.dy);
  }

  /// Снимает overlay перетаскивания, когда граф подтвердил сохранённую позицию.
  /// Вызывается в билде, поэтому нода рендерится сразу по данным графа,
  /// без промежуточного кадра со старой позицией.
  void _resolvePendingDrag(GraphData graph) {
    final id = _dragNodeId;
    if (id == null) return;
    final pending = _dragTargets[id];
    if (pending == null) return;
    for (final n in graph.nodes) {
      if (n.id == id) {
        if ((n.x - pending.dx).abs() < 0.5 && (n.y - pending.dy).abs() < 0.5) {
          _dragTargets.remove(id);
          _dragNodeId = null;
        }
        return;
      }
    }
    // Нода исчезла из графа — снимаем overlay.
    _dragTargets.remove(id);
    _dragNodeId = null;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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

          return LayoutBuilder(
            builder: (context, constraints) {
              final sphereId = widget.viewModel.currentSphereId;

              final isNewSphere = sphereId != null && _centeredSphereId != sphereId;
              if (isNewSphere) {
                _centeredSphereId = sphereId;
                _reveals.clear();
                _seenIds.clear();
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  var root = graph.nodes.first;
                  for (final node in graph.nodes) {
                    if (node.parentId == null) {
                      root = node;
                      break;
                    }
                  }
                  final tx = constraints.maxWidth / 2 - root.x;
                  final ty = constraints.maxHeight / 2 - root.y;
                  _transformationController.value = Matrix4.translationValues(tx, ty, 0);
                });
              }

              _resolvePendingDrag(graph);
              _syncReveals(graph);
              final depthMap = _depthOf(graph.nodes);
              final stagger = isNewSphere;

              final count = graph.nodes.length;
              final linkCount = graph.edges.length;

              return Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      key: _viewerKey,
                      transformationController: _transformationController,
                      constrained: false,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      minScale: 0.25,
                      maxScale: 3.0,
                      child: SizedBox(
                        width: graphWorldSize,
                        height: graphWorldSize,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Точечная сетка + двойной тап — новая сфера.
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onDoubleTap: _showCreateSphereDialog,
                                child: const CustomPaint(painter: GraphGridPainter()),
                              ),
                            ),
                            // Рёбра.
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ValueListenableBuilder<Offset>(
                                  valueListenable: _dragDelta,
                                  builder: (context, delta, _) {
                                    final edgeNodes = graph.nodes
                                        .map((n) => n.copyWith(
                                              x: n.x + (n.id == _dragNodeId ? delta.dx : 0),
                                              y: n.y + (n.id == _dragNodeId ? delta.dy : 0),
                                            ))
                                        .toList();
                                    return CustomPaint(
                                      painter: GraphEdgesPainter(
                                        nodes: edgeNodes,
                                        edges: graph.edges,
                                        reveals: _reveals,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            // Ноды.
                            for (final node in graph.nodes)
                              Positioned(
                                key: ValueKey(node.id),
                                left: node.x,
                                top: node.y,
                                width: graphNodeWidth(node.type),
                                height: graphNodeHeight(node.type),
                                child: ValueListenableBuilder<Offset>(
                                  valueListenable: _dragDelta,
                                  builder: (context, delta, child) =>
                                      Transform.translate(
                                    offset: node.id == _dragNodeId ? delta : Offset.zero,
                                    child: child,
                                  ),
                                  child: GraphNodeCard(
                                    node: node,
                                    showAddButton: !node.isLeaf,
                                    delayMs: stagger
                                        ? math.min((depthMap[node.id] ?? 0) * 90, 600)
                                        : 0,
                                    onTap: () => _showEditDialog(context, node),
                                    onAddChild: () => _showAddChildDialog(context, node),
                                    onDelete: () => _showEditDialog(context, node),
                                    onDragStart: (_) => _handleDragStart(node),
                                    onDragUpdate: (d) =>
                                        _handlePanUpdate(node, d.delta.dx, d.delta.dy),
                                    onDragEnd: (_) => _handleDragEnd(node),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Счётчики + подсказка (слева снизу).
                  Positioned(
                    left: 18,
                    bottom: 18,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlassChip(
                          child: Text(
                            '$count ${_plural(count, 'нода', 'ноды', 'нод')} · '
                            '$linkCount ${_plural(linkCount, 'связь', 'связи', 'связей')}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _GlassChip(
                          child: const Text(
                            'тап — редактировать · перетащить — переместить · '
                            '«+» на ноде — добавить ребёнка',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Зум-кластер (справа снизу).
                  Positioned(
                    right: 18,
                    bottom: 18,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValueListenableBuilder<Matrix4>(
                          valueListenable: _transformationController,
                          builder: (context, m, _) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderGlass),
                            ),
                            child: Text(
                              '${(m.getMaxScaleOnAxis() * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.onSurfaceVariant,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),
                        GraphHudButton(
                          icon: Icons.add,
                          onTap: () => _zoomBy(1.25),
                          tooltip: 'Приблизить',
                        ),
                        const SizedBox(height: 8),
                        GraphHudButton(
                          icon: Icons.remove,
                          onTap: () => _zoomBy(0.8),
                          tooltip: 'Отдалить',
                        ),
                        const SizedBox(height: 8),
                        GraphHudButton(
                          icon: Icons.fit_screen,
                          onTap: _fitView,
                          tooltip: 'Показать весь граф',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _plural(int n, String one, String few, String many) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return one;
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
    return many;
  }

  // ── Диалоги ────────────────────────────────────────────────────────────────

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

class _GlassChip extends StatelessWidget {
  final Widget child;
  const _GlassChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderGlass),
        boxShadow: const [
          BoxShadow(color: Color(0x33000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }
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
