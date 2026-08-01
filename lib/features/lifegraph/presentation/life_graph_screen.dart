import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/lifegraph/presentation/v1.dart' as graph;
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_card.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_sizes.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/node_edit_dialog.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';

/// Экран графа жизни: сфера -> цель -> проект -> задача.
///
/// Граф — это проекция данных из БД. [GraphViewController] (из v1.dart)
/// используется как «холст»: структура, рёбра, камера и перетаскивание,
/// а все данные приходят из [LifeGraphViewModel] (позиции накладываются
/// автоматически или из сохранённых). Правка/добавление/удаление нод
/// идут напрямую в репозитории через ViewModel.
class LifeGraphScreen extends StatefulWidget {
  final LifeGraphViewModel viewModel;

  const LifeGraphScreen({super.key, required this.viewModel});

  @override
  State<LifeGraphScreen> createState() => _LifeGraphScreenState();
}

class _LifeGraphScreenState extends State<LifeGraphScreen> {
  late final graph.GraphViewController _controller;

  GraphData _graphData = GraphData.empty();
  String? _syncedSphereId;
  bool _syncScheduled = false;
  GraphData? _pendingData;

  @override
  void initState() {
    super.initState();
    _controller = graph.GraphViewController(
      worldSize: const Size.square(graphWorldSize),
    );
    // Перемещение ноды на канвасе сохраняется в ViewModel (с debounce).
    _controller.onNodeMoved = (n) {
      widget.viewModel.moveNode(n.id, n.position.dx, n.position.dy);
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Синхронизация контроллера с данными из БД ─────────────────────────────

  Map<String, int> _depthsOf(GraphData graph) {
    final depth = <String, int>{};
    for (final n in graph.nodes) {
      if (n.parentId == null) depth[n.id] = 0;
    }
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in graph.nodes) {
        final p = n.parentId;
        if (p != null && depth.containsKey(p) && !depth.containsKey(n.id)) {
          depth[n.id] = depth[p]! + 1;
          grew = true;
        }
      }
    }
    return depth;
  }

  GraphNode? _rootOf(GraphData data) {
    for (final n in data.nodes) {
      if (n.parentId == null) return n;
    }
    return null;
  }

  /// Контроллер не «моргает» во время перетаскивания: позиции существующих
  /// нод сохраняются, новые ноды получают позиции из layout'а ViewModel.
  List<graph.GraphNode> _toViewNodes(GraphData data) {
    final depth = _depthsOf(data);
    final existing = {
      for (final n in _controller.nodes) n.id: n.position,
    };
    final out = <graph.GraphNode>[];
    for (var i = 0; i < data.nodes.length; i++) {
      final n = data.nodes[i];
      out.add(graph.GraphNode(
        id: n.id,
        label: n.title,
        index: i,
        depth: depth[n.id] ?? 0,
        parentId: n.parentId,
        size: Size(graphNodeWidth(n.type), graphNodeHeight(n.type)),
        position: existing[n.id] ?? Offset(n.x, n.y),
      ));
    }
    return out;
  }

  void _scheduleSync(GraphData data) {
    // Всегда используем свежайшие данные: если несколько эмиссий пришли в одном
    // кадре, post-frame колбэк применит последнюю, а не первую (устаревшую).
    _pendingData = data;
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      final latest = _pendingData;
      _pendingData = null;
      if (!mounted || latest == null) return;
      _syncGraph(latest);
    });
  }

  void _syncGraph(GraphData data) {
    final sphereId = widget.viewModel.currentSphereId;
    if (sphereId == null) {
      if (_syncedSphereId != null) {
        _syncedSphereId = null;
        _controller.clear();
      }
      return;
    }

    // Пришла ли эмиссия для текущей сферы (или это устаревшие данные прошлого стрима).
    final root = _rootOf(data);
    final ready = root != null && root.id == sphereId;
    final switched = _syncedSphereId != sphereId;

    if (!ready) {
      // Данные для сферы ещё не пришли — не сбрасываем признак загрузки,
      // чтобы устаревшая эмиссия старого стрима не вернула спиннер.
      if (switched) _controller.clear();
      return;
    }

    _syncedSphereId = sphereId;
    _controller.setGraph(_toViewNodes(data));

    if (switched) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.fitView();
      });
    }
  }

  GraphNode _domainOf(String id) {
    for (final n in _graphData.nodes) {
      if (n.id == id) return n;
    }
    return GraphNode(
      id: id,
      type: GraphNodeType.task,
      title: '',
      subtitle: '',
      color: '#9E9E9E',
      parentId: null,
      x: 0,
      y: 0,
    );
  }

  Widget _nodeBuilder(BuildContext context, graph.NodeState state) {
    final node = _domainOf(state.node.id);
    return GraphNodeCard(
      state: state,
      node: node,
      onTap: () => _showEditDialog(context, node),
      onAddChild: () => _showAddChildDialog(node),
      onDelete: () => _showDeleteDialog(node),
    );
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
          _SphereDropdown(viewModel: widget.viewModel),
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            tooltip: 'Новая сфера',
            onPressed: _showCreateSphereDialog,
          ),
        ],
      ),
      body: !widget.viewModel.initialized
          ? const _GraphSplash()
          : StreamBuilder<GraphData>(
              stream: widget.viewModel.graphStream,
              builder: (context, snapshot) {
                final data = snapshot.data ?? GraphData.empty();
                _graphData = data;
                _scheduleSync(data);

                final sphereId = widget.viewModel.currentSphereId;
                if (sphereId == null) {
                  return _EmptyState(
                    onCreate: () => _showCreateSphereDialog(),
                  );
                }

                final stale = _syncedSphereId != sphereId;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: graph.GraphView(
                        controller: _controller,
                        theme: AppGraphThemes.dark,
                        nodeBuilder: _nodeBuilder,
                        doubleTapCreatesRoot: false,
                        longPressDeletes: false,
                      ),
                    ),
                    Positioned(
                      left: 18,
                      bottom: 18,
                      child: _StatsChip(graph: data),
                    ),
                    Positioned(
                      right: 18,
                      bottom: 18,
                      child: _SaveBadge(viewModel: widget.viewModel),
                    ),
                  ],
                );
              },
            ),
    );
  }

  // ── Диалоги ────────────────────────────────────────────────────────────────

  Future<void> _showCreateSphereDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Новая сфера жизни'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Название (например: Работа, Семья, Здоровье)',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                widget.viewModel.createSphere(name: name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _showAddChildDialog(GraphNode parent) async {
    if (parent.isLeaf) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AddChildDialog(
        parentNode: parent,
        onSave: ({required title, required description, color}) {
          return widget.viewModel.addChild(
            parentId: parent.id,
            title: title,
            description: description,
            color: color,
          );
        },
      ),
    );
  }

  void _showEditDialog(BuildContext context, GraphNode node) {
    showDialog<void>(
      context: context,
      builder: (ctx) => NodeEditDialog(
        node: node,
        onSave: (updated) => widget.viewModel.updateNode(updated),
        onDelete: (keepChildren) =>
            widget.viewModel.deleteNode(node.id, keepChildren: keepChildren),
      ),
    );
  }

  Future<void> _showDeleteDialog(GraphNode node) async {
    final keepChildren = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Удалить ноду?'),
        content: Text('Нода "${node.title}" будет удалена. '
            'Что сделать с дочерними элементами?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Удалить всё поддерево'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить детей (скрыть)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
    if (keepChildren != null) {
      await widget.viewModel.deleteNode(node.id, keepChildren: keepChildren);
    }
  }
}

// ── Вспомогательные виджеты ─────────────────────────────────────────────────

class _SphereDropdown extends StatelessWidget {
  final LifeGraphViewModel viewModel;

  const _SphereDropdown({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sphere>>(
      stream: viewModel.spheresStream,
      builder: (context, snapshot) {
        final spheres = snapshot.data ?? [];
        if (spheres.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 12),
          child: DropdownButton<String>(
            value: viewModel.currentSphereId,
            dropdownColor: AppColors.surfaceContainerHigh,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
            items: spheres
                .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                .toList(),
            onChanged: (id) {
              if (id != null) viewModel.switchSphere(id);
            },
          ),
        );
      },
    );
  }
}

class _StatsChip extends StatelessWidget {
  final GraphData graph;

  const _StatsChip({required this.graph});

  @override
  Widget build(BuildContext context) {
    final nodes = graph.nodes.length;
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
      child: Text(
        '$nodes ${_plural(nodes, 'нода', 'ноды', 'нод')} · '
        //'$links ${_plural(links, 'связь', 'связи', 'связей')} · '
        'тап — изменить, «+» — добавить',
        style: const TextStyle(
          fontSize: 10.5,
          color: AppColors.onSurfaceVariant,
          letterSpacing: 0.3,
        ),
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
          const Icon(Icons.account_tree_rounded, size: 64, color: Colors.white38),
          const SizedBox(height: 16),
          const Text(
            'Канвас пуст',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создайте первую сферу жизни',
            style: TextStyle(color: Colors.white38),
          ),
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

/// Сплэш восстановления: пульсирующий мини-граф, пока грузятся сохранённые данные.
class _GraphSplash extends StatefulWidget {
  const _GraphSplash();

  @override
  State<_GraphSplash> createState() => _GraphSplashState();
}

class _GraphSplashState extends State<_GraphSplash> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, _) => CustomPaint(painter: _SplashGraph(_ctrl.value)),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Восстанавливаем граф…',
            style: TextStyle(fontSize: 12, letterSpacing: 0.5, color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _SplashGraph extends CustomPainter {
  final double t;

  const _SplashGraph(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 26.0;
    final pts = [
      for (var i = 0; i < 3; i++)
        Offset(
          c.dx + r * math.cos(-math.pi / 2 + i * 2 * math.pi / 3),
          c.dy + r * math.sin(-math.pi / 2 + i * 2 * math.pi / 3),
        ),
    ];

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = AppColors.borderGlass;
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(pts[i], pts[(i + 1) % 3], line);
    }
    for (var i = 0; i < 3; i++) {
      final pulse = 0.5 + 0.5 * math.sin((t + i / 3) * 2 * math.pi);
      canvas.drawCircle(
        pts[i],
        9 + 3 * pulse,
        Paint()..color = AppColors.primary.withValues(alpha: 0.14),
      );
      canvas.drawCircle(pts[i], 4.5 + 1.8 * pulse, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(covariant _SplashGraph old) => true;
}

/// Бейдж автосохранения позиций: черновик / сохраняем… / сохранено.
class _SaveBadge extends StatelessWidget {
  final LifeGraphViewModel viewModel;

  const _SaveBadge({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<GraphSaveStatus>(
      valueListenable: viewModel.saveStatus,
      builder: (context, status, _) {
        final color = switch (status) {
          GraphSaveStatus.draft => AppColors.onSurfaceVariant,
          GraphSaveStatus.saving => AppColors.primary,
          GraphSaveStatus.saved => const Color(0xFF4CAF50),
        };
        final label = switch (status) {
          GraphSaveStatus.draft => 'черновик',
          GraphSaveStatus.saving => 'сохраняем…',
          GraphSaveStatus.saved => 'сохранено',
        };
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
