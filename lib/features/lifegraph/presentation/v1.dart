/// Nodefield — reusable graph canvas.
/// One widget (GraphView) + one controller (GraphViewController) + one theme.
///
/// Drop this file into lib/ (or split by sections into lib/src/) and use:
///
///   final controller = GraphViewController();
///   GraphView(controller: controller, theme: GraphViewTheme.deep);
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════════════
// 1 · Theme — everything visual lives here
// ════════════════════════════════════════════════════════════════════════════

class GraphViewTheme {
  final List<Color> depthRamp; // node accent by depth
  final Color canvas;
  final Color ambientA; // top-left glow
  final Color ambientB; // bottom-right glow
  final Color gridMinor;
  final Color gridMajor;
  final double gridSpacing;
  final Color surface;
  final Color surfaceHover;
  final Color border;
  final Color text;
  final Color textDim;
  final Color shadow;
  final Color controlsBg;

  const GraphViewTheme({
    required this.depthRamp,
    required this.canvas,
    required this.ambientA,
    required this.ambientB,
    required this.gridMinor,
    required this.gridMajor,
    required this.gridSpacing,
    required this.surface,
    required this.surfaceHover,
    required this.border,
    required this.text,
    required this.textDim,
    required this.shadow,
    required this.controlsBg,
  });

  Color accentFor(int depth) => depthRamp[depth % depthRamp.length];

  static const deep = GraphViewTheme(
    depthRamp: [Color(0xFFFFB454), Color(0xFFFF6B5E), Color(0xFF34D3A6), Color(0xFF58A6FF)],
    canvas: Color(0xFF0B1E24),
    ambientA: Color(0x14FFB454),
    ambientB: Color(0x1234D3A6),
    gridMinor: Color(0xFF1C313A),
    gridMajor: Color(0xFF24404B),
    gridSpacing: 42,
    surface: Color(0xFF152E36),
    surfaceHover: Color(0xFF1D3B45),
    border: Color(0xFF2A4854),
    text: Color(0xFFEAF4F4),
    textDim: Color(0xFF8FA9AD),
    shadow: Color(0x59000000),
    controlsBg: Color(0xCC152E36),
  );

  static const paper = GraphViewTheme(
    depthRamp: [Color(0xFFE08A00), Color(0xFFE4573D), Color(0xFF0FA37F), Color(0xFF2E7CD6)],
    canvas: Color(0xFFEEF3F2),
    ambientA: Color(0x1AE08A00),
    ambientB: Color(0x1A0FA37F),
    gridMinor: Color(0xFFD9E3E1),
    gridMajor: Color(0xFFC7D5D2),
    gridSpacing: 42,
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF4F9F8),
    border: Color(0xFFD3DEDB),
    text: Color(0xFF14333C),
    textDim: Color(0xFF6E868C),
    shadow: Color(0x2414333C),
    controlsBg: Color(0xCCFFFFFF),
  );
}

// ════════════════════════════════════════════════════════════════════════════
// 2 · Data
// ════════════════════════════════════════════════════════════════════════════

class GraphNode {
  final String id;
  final String label;

  final int index;
  final int depth;
  final String? parentId;
  final Size size; // per-node size; defaults to the controller's nodeSize
  Offset position; // top-left, world coordinates

  GraphNode({
    required this.id,
    required this.label,
    required this.index,
    required this.depth,
    required this.parentId,
    required this.position,
    Size? size,
  }) : size = size ?? const Size(176, 68);

    Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'index': index,
        'depth': depth,
        'parentId': parentId,
        'x': position.dx,
        'y': position.dy,
        'w': size.width,
        'h': size.height,
      };

  factory GraphNode.fromJson(Map<String, dynamic> j) => GraphNode(
        id: j['id'] as String,
        label: j['label'] as String? ?? '',
        index: (j['index'] as num?)?.toInt() ?? 0,
        depth: (j['depth'] as num?)?.toInt() ?? 0,
        parentId: j['parentId'] as String?,
        position: Offset(
          (j['x'] as num?)?.toDouble() ?? 0,
          (j['y'] as num?)?.toDouble() ?? 0,
        ),
        size: Size(
          (j['w'] as num?)?.toDouble() ?? 176,
          (j['h'] as num?)?.toDouble() ?? 68,
        ),
      );

}

/// Everything a custom node renderer gets from the canvas.
class NodeState {
  final GraphNode node;
  final Size size;
  final bool selected;
  final bool canDelete;
  final Color accent;
  final VoidCallback select;
  final VoidCallback addChild;
  final VoidCallback remove;
  final GestureDragStartCallback dragStart; // feed global drag details
  final GestureDragUpdateCallback dragUpdate;

  const NodeState({
    required this.node,
    required this.size,
    required this.selected,
    required this.canDelete,
    required this.accent,
    required this.select,
    required this.addChild,
    required this.remove,
    required this.dragStart,
    required this.dragUpdate,
  });
}

typedef NodeWidgetBuilder = Widget Function(BuildContext context, NodeState state);

// ════════════════════════════════════════════════════════════════════════════
// 3 · Controller — structure, geometry, imperative camera
// ════════════════════════════════════════════════════════════════════════════

abstract class _GraphCamera {
  void fitView({required bool animate});
  void zoomBy(double factor);
  void ensureVisible(Offset scenePoint);
}

class GraphViewController extends ChangeNotifier {
  GraphViewController({
    this.nodeSize = const Size(176, 68),
    this.levelGap = 236,
    this.siblingGap = 112,
    this.worldSize = const Size(4200, 4200),
  });

  /// Geometry (structure-level, not visual).
  final Size nodeSize;
  final double levelGap;
  final double siblingGap;
  final Size worldSize;

  // Event hooks — assign from the host app.
  ValueChanged<GraphNode>? onNodeCreated;
  ValueChanged<GraphNode?>? onSelectionChanged;
  ValueChanged<GraphNode>? onNodeMoved; // fires continuously while dragging
  ValueChanged<List<GraphNode>>? onSubtreeRemoved;

  Map<String, GraphNode> _nodes = {};
  String? _selectedId;
  int _ids = 0;
  int _labels = 0;
  _GraphCamera? _camera;

  List<GraphNode> get nodes => _nodes.values.toList();
  GraphNode? nodeById(String id) => _nodes[id];
  String? get selectedId => _selectedId;
  int get linkCount => _nodes.values.where((n) => n.parentId != null).length;

  // ── Mutations ──────────────────────────────────────────────────────────────

  GraphNode addRoot({Offset? at, String? label}) {
    final index = _labels++;
    final n = GraphNode(
      id: 'n${_ids++}',
      label: label ?? 'Node $index',
      index: index,
      depth: 0,
      parentId: null,
      size: nodeSize,
      position: _clamp(at ?? _defaultRootSpot(), nodeSize),
    );
    _nodes[n.id] = n;
    onNodeCreated?.call(n);
    notifyListeners();
    _camera?.ensureVisible(n.position + Offset(n.size.width / 2, n.size.height / 2));
    return n;
  }

  GraphNode addChild(String parentId, {Offset? at, String? label}) {
    final p = _nodes[parentId];
    assert(p != null, 'GraphViewController.addChild: unknown parentId "$parentId"');
    if (p == null) throw ArgumentError('Unknown parentId "$parentId"');

    final index = _labels++;
    final siblings = _nodes.values.where((n) => n.parentId == parentId).length;
    final band = (siblings + 1) ~/ 2;
    final dy = siblings == 0 ? 0.0 : band * siblingGap * (siblings.isOdd ? 1 : -1);

    final n = GraphNode(
      id: 'n${_ids++}',
      label: label ?? 'Node $index',
      index: index,
      depth: p.depth + 1,
      parentId: parentId,
      size: nodeSize,
      position: _clamp(at ?? Offset(p.position.dx + nodeSize.width + levelGap, p.position.dy + dy), nodeSize),
    );
    _nodes[n.id] = n;
    onNodeCreated?.call(n);
    notifyListeners();
    _camera?.ensureVisible(n.position + Offset(n.size.width / 2, n.size.height / 2));
    return n;
  }

  void moveNode(String id, Offset to) {
    final n = _nodes[id];
    if (n == null) return;
    n.position = _clamp(to, n.size);
    onNodeMoved?.call(n);
    notifyListeners();
  }

  void select(String? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    onSelectionChanged?.call(id == null ? null : _nodes[id]);
    notifyListeners();
  }

  void removeSubtree(String id) {
    final doomed = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in _nodes.values) {
        if (n.parentId != null && doomed.contains(n.parentId!) && doomed.add(n.id)) grew = true;
      }
    }
    final removed = [for (final d in doomed) if (_nodes[d] != null) _nodes.remove(d)!];
    if (doomed.contains(_selectedId)) _selectedId = null;
    if (removed.isNotEmpty) {
      onSubtreeRemoved?.call(removed);
      notifyListeners();
    }
  }

  void clear() {
    _nodes.clear();
    _selectedId = null;
    notifyListeners();
  }

  /// Заменяет весь набор нод (без анимации камеры и авто-позиционирования).
  /// Используется, когда граф является проекцией внешнего источника данных
  /// (например, БД): позиции и размеры приходят уже вычисленными.
  /// Выделение сохраняется, если нода ещё существует.
  void setGraph(List<GraphNode> nodes) {
    _nodes.clear();
    for (final n in nodes) {
      _nodes[n.id] = n;
    }
    if (_selectedId != null && !_nodes.containsKey(_selectedId)) {
      _selectedId = null;
    }
    notifyListeners();
  }

  // ── Camera (no-ops until the view is attached) ─────────────────────────────

  void fitView({bool animate = true}) => _camera?.fitView(animate: animate);
  void zoomBy(double factor) => _camera?.zoomBy(factor);
  void revealNode(String id) {
    final n = _nodes[id];
    if (n != null) _camera?.ensureVisible(n.position + Offset(n.size.width / 2, n.size.height / 2));
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  Offset _defaultRootSpot() {
    final roots = _nodes.values.where((n) => n.parentId == null).length;
    return Offset(worldSize.width * 0.32 + (roots % 5) * 60, worldSize.height * 0.40 + roots * 130);
  }

  Offset _clamp(Offset p, Size size) => Offset(
        p.dx.clamp(24, worldSize.width - size.width - 24),
        p.dy.clamp(24, worldSize.height - size.height - 24),
      );

  void _attach(_GraphCamera camera) {
    assert(_camera == null, 'A GraphViewController can drive only one GraphView at a time.');
    _camera = camera;
  }

  void _detach(_GraphCamera camera) {
    if (identical(_camera, camera)) _camera = null;
  }

    /// Снимок графа: узлы + счётчики, чтобы новые id/имена не collided.
  Map<String, dynamic> exportGraph() => {
        'v': 1,
        'nextId': _ids,
        'nextLabel': _labels,
        'selectedId': _selectedId,
        'nodes': [for (final n in _nodes.values) n.toJson()],
      };

  /// Заменяет текущий граф снимком из [exportGraph].
  /// Возвращает false, если формат не распознан.
  bool importGraph(Map<String, dynamic> data) {
    if (data['v'] != 1) return false;
    _nodes.clear();
    for (final raw in (data['nodes'] as List? ?? const [])) {
      if (raw is Map<String, dynamic>) {
        final n = GraphNode.fromJson(raw);
        _nodes[n.id] = n..position = _clamp(n.position, n.size);
      }
    }
    _ids = (data['nextId'] as num?)?.toInt() ?? _nodes.length;
    _labels = (data['nextLabel'] as num?)?.toInt() ?? _nodes.length;
    final sel = data['selectedId'] as String?;
    _selectedId = (sel != null && _nodes.containsKey(sel)) ? sel : null;
    notifyListeners();
    return true;
  }

}


/// Контракт персистентности. Реализации: prefs, файл, SQLite, сервер…
abstract class GraphStore {
  Future<Map<String, dynamic>?> load(String slot);
  Future<void> save(String slot, Map<String, dynamic> snapshot);
  Future<List<String>> slots(); // самые свежие — первыми
  Future<void> delete(String slot);
}

// ════════════════════════════════════════════════════════════════════════════
// 4 · GraphView — the one widget you embed
// ════════════════════════════════════════════════════════════════════════════

class GraphView extends StatefulWidget {
  final GraphViewController controller;
  final GraphViewTheme theme;

  /// Custom node renderer. When null, [DefaultNodeCard] is used.
  final NodeWidgetBuilder? nodeBuilder;

  final bool showControls;          // built-in zoom cluster
  final bool doubleTapCreatesRoot;  // double-tap empty canvas
  final bool longPressDeletes;      // long-press a node to prune its subtree
  final double minScale;
  final double maxScale;

  const GraphView({
    super.key,
    required this.controller,
    this.theme = GraphViewTheme.deep,
    this.nodeBuilder,
    this.showControls = true,
    this.doubleTapCreatesRoot = true,
    this.longPressDeletes = true,
    this.minScale = 0.25,
    this.maxScale = 2.5,
  });

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView> with TickerProviderStateMixin implements _GraphCamera {
  final TransformationController _ctrl = TransformationController();
  final GlobalKey _viewerKey = GlobalKey();

  late final AnimationController _revealCtrl;
  late final CurvedAnimation _revealCurved;
  final Map<String, double> _reveals = {}; // 'parent>child' -> draw progress

  late final AnimationController _flyCtrl;
  Animation<Matrix4>? _flyAnim;

  Offset _dragGrab = Offset.zero;
  bool _booted = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    widget.controller.addListener(_onGraphChanged);

    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _revealCurved = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic);
    _revealCtrl.addListener(_onRevealTick);
    _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

    _onGraphChanged(); // register pre-seeded edges at zero reveal

    WidgetsBinding.instance.addPostFrameCallback((_) {
      fitView(animate: false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _revealCtrl.forward();
        if (mounted) setState(() => _booted = true);
      });
    });
  }

  @override
  void didUpdateWidget(covariant GraphView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller._detach(this);
      old.controller.removeListener(_onGraphChanged);
      widget.controller._attach(this);
      widget.controller.addListener(_onGraphChanged);
      _reveals.clear();
      _onGraphChanged();
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    widget.controller.removeListener(_onGraphChanged);
    _revealCtrl.dispose();
    _flyCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  // ── Edge reveal bookkeeping ────────────────────────────────────────────────

  void _onGraphChanged() {
    final keys = <String>{};
    for (final n in widget.controller.nodes) {
      if (n.parentId != null) keys.add('${n.parentId}>${n.id}');
    }
    final fresh = keys.difference(_reveals.keys.toSet());
    if (fresh.isNotEmpty) {
      for (final k in fresh) _reveals[k] = 0;
      if (_booted) _revealCtrl.forward(from: 0);
    }
    _reveals.removeWhere((k, _) => !keys.contains(k));
  }

  void _onRevealTick() {
    final v = _revealCurved.value;
    var dirty = false;
    for (final k in _reveals.keys) {
      if (_reveals[k]! < 1) {
        _reveals[k] = v;
        dirty = true;
      }
    }
    if (dirty) setState(() {});
  }

  // ── Camera math ────────────────────────────────────────────────────────────

  RenderBox? get _viewerBox => _viewerKey.currentContext?.findRenderObject() as RenderBox?;

  Offset _sceneFromGlobal(Offset global) {
    final box = _viewerBox;
    if (box == null) return Offset.zero;
    return _ctrl.toScene(box.globalToLocal(global));
  }

  void _flyTo(Matrix4 target) {
    _flyAnim?.removeListener(_applyFly);
    _flyAnim = Matrix4Tween(begin: _ctrl.value.clone(), end: target).animate(
      CurvedAnimation(parent: _flyCtrl, curve: Curves.easeInOutCubic),
    )..addListener(_applyFly);
    _flyCtrl.forward(from: 0);
  }

  void _applyFly() => _ctrl.value = _flyAnim!.value;

  @override
  void fitView({required bool animate}) {
    final all = widget.controller.nodes;
    final box = _viewerBox;
    if (all.isEmpty || box == null) return;

    var rect = Rect.fromLTWH(all.first.position.dx, all.first.position.dy, all.first.size.width, all.first.size.height);
    for (final n in all) {
      rect = rect.expandToInclude(Rect.fromLTWH(n.position.dx, n.position.dy, n.size.width, n.size.height));
    }
    rect = rect.inflate(150);

    final vp = box.size;
    final s = math.min(vp.width / rect.width, vp.height / rect.height)
        .clamp(widget.minScale, 1.1);
    final m = Matrix4.identity()
      ..scale(s, s)
      ..translate(
        (vp.width / 2 - s * rect.center.dx) / s,
        (vp.height / 2 - s * rect.center.dy) / s,
      );
    animate ? _flyTo(m) : _ctrl.value = m;
  }

  @override
  void zoomBy(double f) {
    final box = _viewerBox;
    if (box == null) return;
    final s0 = _ctrl.value.getMaxScaleOnAxis();
    final s1 = (s0 * f).clamp(widget.minScale, widget.maxScale);
    f = s1 / s0;

    final c = _ctrl.toScene(box.size.center(Offset.zero));
    final around = Matrix4.identity()
      ..translate(c.dx, c.dy)
      ..scale(f, f)
      ..translate(-c.dx, -c.dy);
    _flyTo(_ctrl.value.clone()..multiply(around));
  }

  @override
  void ensureVisible(Offset scenePoint) {
    final box = _viewerBox;
    if (box == null) return;
    final vp = box.size;
    final screen = MatrixUtils.transformPoint(_ctrl.value, scenePoint);
    const m = 110.0;

    double dx = 0, dy = 0;
    if (screen.dx < m) dx = m - screen.dx;
    if (screen.dx > vp.width - m) dx = vp.width - m - screen.dx;
    if (screen.dy < m) dy = m - screen.dy;
    if (screen.dy > vp.height - m) dy = vp.height - m - screen.dy;
    if (dx == 0 && dy == 0) return;

    _flyTo(Matrix4.translationValues(dx, dy, 0)..multiply(_ctrl.value));
  }

  // ── Node interaction plumbing ──────────────────────────────────────────────

  void _dragStart(GraphNode n, DragStartDetails d) {
    _dragGrab = n.position - _sceneFromGlobal(d.globalPosition);
    widget.controller.select(n.id);
  }

  void _dragUpdate(GraphNode n, DragUpdateDetails d) {
    widget.controller.moveNode(n.id, _sceneFromGlobal(d.globalPosition) + _dragGrab);
  }

  List<_EdgeSpec> _buildEdges(GraphViewTheme theme, var ctrl) {
    final out = <_EdgeSpec>[];
    for (final n in widget.controller.nodes) {
      if (n.parentId == null) continue;
      final p = widget.controller.nodeById(n.parentId!);
      if (p == null) continue;
out.add(_EdgeSpec(p, n, p.size, n.size, theme.accentFor(p.depth), theme.accentFor(n.depth),
    _reveals['${p.id}>${n.id}'] ?? 1));
    }
    return out;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final ctrl = widget.controller;
    final ns = ctrl.nodeSize;

    return ClipRect(
      child: Stack(
        children: [
          // Ambient layered backdrop.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.25, -0.35),
                  radius: 1.5,
                  colors: [
                    Color.lerp(theme.canvas, Colors.white, 0.07)!,
                    theme.canvas,
                    Color.lerp(theme.canvas, Colors.black, 0.28)!,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -160, top: -180, width: 560, height: 560,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [theme.ambientA, Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            right: -180, bottom: -220, width: 640, height: 640,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [theme.ambientB, Colors.transparent]),
                ),
              ),
            ),
          ),

          // The world.
          ListenableBuilder(
            listenable: ctrl,
            builder: (context, _) {
              return InteractiveViewer(
                key: _viewerKey,
                transformationController: _ctrl,
                constrained: false,
                minScale: widget.minScale,
                maxScale: widget.maxScale,
                child: SizedBox(
                  width: ctrl.worldSize.width,
                  height: ctrl.worldSize.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => ctrl.select(null),
                          onDoubleTapDown: widget.doubleTapCreatesRoot
                              ? (d) {
                                  HapticFeedback.selectionClick();
                                  ctrl.addRoot(at: d.localPosition - Offset(ns.width / 2, ns.height / 2));
                                }
                              : null,
                          child: CustomPaint(painter: _GridPainter(theme)),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: _EdgesPainter(_buildEdges(theme, ctrl), theme)),
                        ),
                      ),
                      for (final n in ctrl.nodes)
                        Positioned(
                          key: ValueKey(n.id),
                          left: n.position.dx,
                          top: n.position.dy,
                          width: n.size.width,
                          height: n.size.height,
                          child: _PopIn(
                            delayMs: _booted ? 0 : math.min(n.index * 120, 600),
                            child: (widget.nodeBuilder ?? _defaultBuilder)(
                              context,
                              NodeState(
                                node: n,
                                size: n.size,
                                selected: ctrl.selectedId == n.id,
                                canDelete: widget.longPressDeletes,
                                accent: theme.accentFor(n.depth),
                                select: () => ctrl.select(n.id),
                                addChild: () {
                                  HapticFeedback.selectionClick();
                                  ctrl.addChild(n.id);
                                },
                                remove: () {
                                  HapticFeedback.mediumImpact();
                                  ctrl.removeSubtree(n.id);
                                },
                                dragStart: (d) => _dragStart(n, d),
                                dragUpdate: (d) => _dragUpdate(n, d),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          if (widget.showControls)
            Positioned(
              right: 16,
              bottom: 16,
              child: _ZoomControls(
                theme: theme,
                ctrl: _ctrl,
                onZoomIn: () => zoomBy(1.25),
                onZoomOut: () => zoomBy(0.8),
                onFit: () => fitView(animate: true),
              ),
            ),
        ],
      ),
    );
  }

  Widget _defaultBuilder(BuildContext context, NodeState state) =>
      DefaultNodeCard(state: state, theme: widget.theme);
}

// ════════════════════════════════════════════════════════════════════════════
// 5 · Default node renderer (public — reusable from custom builders too)
// ════════════════════════════════════════════════════════════════════════════

class DefaultNodeCard extends StatefulWidget {
  final NodeState state;
  final GraphViewTheme theme;

  const DefaultNodeCard({super.key, required this.state, required this.theme});

  @override
  State<DefaultNodeCard> createState() => _DefaultNodeCardState();
}

class _DefaultNodeCardState extends State<DefaultNodeCard> {
  bool _hovered = false;
  bool _plusHovered = false;
  bool _plusPressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final t = widget.theme;
    final n = s.node;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: s.select,
            onLongPress: s.canDelete ? s.remove : null,
            onPanStart: s.dragStart,
            onPanUpdate: s.dragUpdate,
            child: AnimatedScale(
              scale: _hovered ? 1.03 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: s.size.width,
                height: s.size.height,
                decoration: BoxDecoration(
                  color: _hovered ? t.surfaceHover : t.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: s.selected ? s.accent : t.border,
                    width: s.selected ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: s.selected ? s.accent.withOpacity(0.30) : t.shadow,
                      blurRadius: s.selected ? 22 : 10,
                      spreadRadius: s.selected ? 1 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: s.accent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 24, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'DEPTH ${n.depth} · #${n.index}',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                                color: t.textDim,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              n.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: t.text,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Prune — revealed on hover (long-press covers touch).
          if (s.canDelete)
            Positioned(
              top: -9,
              right: -9,
              child: IgnorePointer(
                ignoring: !_hovered,
                child: AnimatedOpacity(
                  opacity: _hovered ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: GestureDetector(
                    onTap: s.remove,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.surfaceHover,
                          border: Border.all(color: t.border),
                        ),
                        child: Icon(Icons.close, size: 11, color: t.textDim),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // The plus button — grows a child from this node.
          Positioned(
            right: -15,
            top: s.size.height / 2 - 16,
            child: Tooltip(
              message: 'Grow a child node',
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
                    s.addChild();
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
                            ? Color.lerp(s.accent, Colors.white, 0.18)!
                            : s.accent,
                        border: Border.all(color: t.canvas, width: 3),
                        boxShadow: [
                          BoxShadow(color: t.shadow, blurRadius: 8, offset: const Offset(0, 3)),
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
}

/// Elastic pop-in applied to every node, regardless of the builder.
class _PopIn extends StatefulWidget {
  final int delayMs;
  final Widget child;

  const _PopIn({required this.delayMs, required this.child});

  @override
  State<_PopIn> createState() => _PopInState();
}

class _PopInState extends State<_PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.25)),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.centerLeft, // grow out of the parent's plus button
        child: widget.child,
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 6 · Painters
// ════════════════════════════════════════════════════════════════════════════

class _GridPainter extends CustomPainter {
  final GraphViewTheme theme;

  const _GridPainter(this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    final s = theme.gridSpacing;
    final fine = <Offset>[];
    for (var x = s; x < size.width; x += s) {
      for (var y = s; y < size.height; y += s) {
        fine.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      fine,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.7
        ..color = theme.gridMinor,
    );

    final coarse = <Offset>[];
    final cs = s * 4;
    for (var x = cs; x < size.width; x += cs) {
      for (var y = cs; y < size.height; y += cs) {
        coarse.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      coarse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = theme.gridMajor,
    );
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.theme != theme;
}

class _EdgeSpec {
  final GraphNode from;
  final GraphNode to;
  final Size fromSize;
  final Size toSize;
  final Color cFrom;
  final Color cTo;
  final double reveal;

  const _EdgeSpec(this.from, this.to, this.fromSize, this.toSize, this.cFrom, this.cTo, this.reveal);
}

class _EdgesPainter extends CustomPainter {
  final List<_EdgeSpec> edges;
  final GraphViewTheme theme;

  const _EdgesPainter(this.edges, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final a = Offset(
        e.from.position.dx + e.fromSize.width + 18,
        e.from.position.dy + e.fromSize.height / 2,
      );
      final b = Offset(e.to.position.dx - 8, e.to.position.dy + e.toSize.height / 2);

      final dx = math.max(56.0, (b.dx - a.dx) * 0.55);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);

      Path drawn = path;
      ui.PathMetric? pm;
      if (e.reveal < 1) {
        pm = path.computeMetrics().first;
        drawn = pm.extractPath(0, pm.length * e.reveal);
      }

      canvas.drawPath(drawn, Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 8
        ..color = e.cTo.withOpacity(0.12));

      canvas.drawPath(drawn, Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4
        ..shader = ui.Gradient.linear(a, b, [e.cFrom.withOpacity(0.55), e.cTo]));

      if (e.reveal < 1 && pm != null) {
        final tip = pm.getTangentForOffset(pm.length * e.reveal)?.position ?? b;
        canvas.drawCircle(tip, 7, Paint()..color = theme.text.withOpacity(0.18));
        canvas.drawCircle(tip, 3.2, Paint()..color = theme.text);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EdgesPainter old) => true;
}




// ════════════════════════════════════════════════════════════════════════════
// 7 · Built-in zoom controls
// ════════════════════════════════════════════════════════════════════════════

class _ZoomControls extends StatelessWidget {
  final GraphViewTheme theme;
  final TransformationController ctrl;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onFit;

  const _ZoomControls({
    required this.theme,
    required this.ctrl,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<Matrix4>(
          valueListenable: ctrl,
          builder: (context, m, _) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: theme.controlsBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.border),
            ),
            child: Text(
              '${(m.getMaxScaleOnAxis() * 100).round()}%',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: theme.textDim,
              ),
            ),
          ),
        ),
        _ControlButton(theme: theme, icon: Icons.add, tooltip: 'Zoom in', onTap: onZoomIn),
        const SizedBox(height: 8),
        _ControlButton(theme: theme, icon: Icons.remove, tooltip: 'Zoom out', onTap: onZoomOut),
        const SizedBox(height: 8),
        _ControlButton(theme: theme, icon: Icons.fit_screen, tooltip: 'Fit graph', onTap: onFit),
      ],
    );
  }
}

class _ControlButton extends StatefulWidget {
  final GraphViewTheme theme;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ControlButton({
    required this.theme,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<_ControlButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _hovered ? 1.1 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _hovered ? t.surfaceHover : t.controlsBg,
                border: Border.all(color: t.border),
                boxShadow: [BoxShadow(color: t.shadow, blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Icon(widget.icon, size: 17, color: _hovered ? t.text : t.textDim),
            ),
          ),
        ),
      ),
    );
  }
}