import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/graph_view.dart' as graph;
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_card.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_node_sizes.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/node_edit_dialog.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';

/// Экран графа жизни: сфера -> цель -> проект -> задача.
///
/// Граф — это проекция данных из БД. [graph.GraphView] получает список
/// view-нод стримом из [LifeGraphViewModel] и сам рисует рёбра, анимации,
/// пан/зум и драг; правка/добавление/удаление идут через [graph.GraphAction]
/// и диалоги. Позиции нод авто-сохраняются в репозитории через ViewModel.
class LifeGraphScreen extends StatefulWidget {
  final LifeGraphViewModel viewModel;

  const LifeGraphScreen({super.key, required this.viewModel});

  @override
  State<LifeGraphScreen> createState() => _LifeGraphScreenState();
}

class _LifeGraphScreenState extends State<LifeGraphScreen> {
  final graph.GraphViewCamera _camera = graph.GraphViewCamera();
  String? _syncedSphereId;

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
          : StreamBuilder<List<graph.GraphNode>>(
              stream: widget.viewModel.graphStream,
              builder: (context, snapshot) {
                final nodes = snapshot.data ?? const <graph.GraphNode>[];
                final sphereId = widget.viewModel.currentSphereId;
                if (sphereId == null) {
                  _syncedSphereId = null;
                  return _EmptyState(
                    onCreate: () => _showCreateSphereDialog(),
                  );
                }

                final ready =
                    nodes.any((n) => n.parentId == null && n.id == sphereId);
                if (ready) _maybeFit(sphereId);
                final stale = _syncedSphereId != sphereId;

                return Stack(
                  children: [
                    Positioned.fill(
                      child: graph.GraphView(
                        nodes: widget.viewModel.graphStream,
                        onAction: _onAction,
                        camera: _camera,
                        theme: AppGraphThemes.dark,
                        layout: appGraphLayout(),
                        nodeBuilder: _nodeBuilder,
                        doubleTapCreatesRoot: false,
                        longPressDeletes: false,
                      ),
                    ),
                    if (stale)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        ),
                      ),
                    Positioned(
                      left: 18,
                      bottom: 18,
                      child: _StatsChip(count: nodes.length),
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

  /// Как только пришли данные для текущей сферы — вписываем граф в канвас.
  void _maybeFit(String sphereId) {
    if (_syncedSphereId == sphereId) return;
    _syncedSphereId = sphereId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _camera.fitView(animate: false);
    });
  }

  // ── Обработка намерений GraphView ─────────────────────────────────────────

  void _onAction(graph.GraphAction action) {
    switch (action) {
      case graph.CreateRootAction():
      case graph.CreateChildAction():
        // Создание всегда идёт через диалоги (double-tap и «+» отключены).
        break;
      case graph.MoveAction(:final id, :final to):
        // Live-курсор драга: только память, не сохраняем.
        widget.viewModel.moveNode(id, to.dx, to.dy);
      case graph.MoveEndAction(:final id, :final to):
        // Точка коммита — пишем позицию с debounce.
        widget.viewModel.commitMove(id, to.dx, to.dy);
      case graph.RemoveAction():
        break;
      case graph.SelectAction():
        break;
    }
  }

  // ── Кастомный рендер ноды ─────────────────────────────────────────────────

  Widget _nodeBuilder(BuildContext context, graph.NodeState state) {
    final node = widget.viewModel.nodeById(state.node.id);
    if (node == null) return const SizedBox.shrink();
    return GraphNodeCard(
      state: state,
      node: node,
      onTap: () => _showEditDialog(context, node),
      onAddChild: () => _showAddChildDialog(node),
      onDelete: () => _showDeleteDialog(node),
    );
  }

  // ── Диалоги ────────────────────────────────────────────────────────────────

  Future<void> _showCreateSphereDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => _CreateSphereDialog(viewModel: widget.viewModel),
    );
  }

  Future<void> _showAddChildDialog(GraphNode parent) async {
    if (parent.isLeaf) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AddChildDialog(
        parentNode: parent,
        onSave: ({
          required title,
          required description,
          color,
          dueDate,
          startsAt,
          endsAt,
        }) {
          return widget.viewModel.addChild(
            parentId: parent.id,
            title: title,
            description: description,
            color: color,
            dueDate: dueDate,
            startsAt: startsAt,
            endsAt: endsAt,
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

/// Диалог создания сферы. Владеет собственным [TextEditingController] и
/// освобождает его в [dispose] — после полного удаления роута диалога
/// (когда TextField уже размонтирован), исключая «controller used after disposed».
class _CreateSphereDialog extends StatefulWidget {
  final LifeGraphViewModel viewModel;

  const _CreateSphereDialog({required this.viewModel});

  @override
  State<_CreateSphereDialog> createState() => _CreateSphereDialogState();
}

class _CreateSphereDialogState extends State<_CreateSphereDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      title: const Text('Новая сфера жизни'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Название (например: Работа, Семья, Здоровье)',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(
          onPressed: () {
            final name = _controller.text.trim();
            if (name.isNotEmpty) {
              widget.viewModel.createSphere(name: name);
              Navigator.pop(context);
            }
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}

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
  final int count;

  const _StatsChip({required this.count});

  @override
  Widget build(BuildContext context) {
    final nodes = count;
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
