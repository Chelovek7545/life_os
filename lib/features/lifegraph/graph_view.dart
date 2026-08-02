/// GraphView — stream-driven graph canvas.
///
/// Data flows in through [GraphView.nodes] (a `Stream<List<GraphNode>>`),
/// user intent flows out through [GraphView.onAction] as [GraphAction]s.
/// The widget never owns your data: it renders snapshots, animates the
/// differences and reports gestures. Requires Dart 3 (sealed classes).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ════════════════════════════════════════════════════════════════════════════
// 1 · Theme & layout
// ════════════════════════════════════════════════════════════════════════════

class GraphViewTheme {
  final List<Color> depthRamp;
  final Color canvas;
  final Color ambientA;
  final Color ambientB;
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

/// Geometry of the graph. Purely structural — colors live in [GraphViewTheme].
class GraphLayout {
  final Size nodeSize;
  final double levelGap;   // horizontal parent → child distance
  final double siblingGap; // vertical band step between siblings
  final Size worldSize;    // pannable canvas extent

  const GraphLayout({
    this.nodeSize = const Size(176, 68),
    this.levelGap = 236,
    this.siblingGap = 112,
    this.worldSize = const Size(4200, 4200),
  });
}

// ════════════════════════════════════════════════════════════════════════════
// 2 · Data & actions
// ════════════════════════════════════════════════════════════════════════════

/// One node of the graph. The host owns instances; emit fresh objects
/// (see [clone]) so the internal diff can see changes.
class GraphNode {
  final String id;
  final String label;
  final int index;    // creation order — drives the boot stagger
  final int depth;    // 0 for roots; drives the accent color
  final String? parentId;
  final Size size;    // physical footprint of the node
  Offset position; // top-left, world coordinates

  GraphNode({
    required this.id,
    required this.label,
    required this.index,
    required this.depth,
    required this.parentId,
    this.size = const Size(176, 68),
    required this.position,
  });

  GraphNode clone() => GraphNode(
        id: id,
        label: label,
        index: index,
        depth: depth,
        parentId: parentId,
        size: size,
        position: position,
      );
}

/// Everything the user can ask the host to do. Sealed, so the host handler
/// is an exhaustive `switch`. The widget fires these; it never applies them.
sealed class GraphAction {
  const GraphAction();

  factory GraphAction.createRoot({Offset? at, String? label}) = CreateRootAction;
  factory GraphAction.createChild({required String parentId, Offset? at, String? label}) =
      CreateChildAction;
  factory GraphAction.move({required String id, required Offset to}) = MoveAction;
  factory GraphAction.moveEnd({required String id, required Offset to}) = MoveEndAction;
  factory GraphAction.remove({required String id}) = RemoveAction;
  factory GraphAction.select(String? id) = SelectAction;
}

/// Double-tap on empty canvas. [at] is a suggested top-left position.
class CreateRootAction extends GraphAction {
  final Offset? at;
  final String? label;
  const CreateRootAction({this.at, this.label});
}

/// Tap on a node's plus button. [at] is where the widget drew its ghost.
class CreateChildAction extends GraphAction {
  final String parentId;
  final Offset? at;
  final String? label;
  const CreateChildAction({required this.parentId, this.at, this.label});
}

/// Continuous, high-frequency, safe to drop. Do NOT persist per event —
/// treat it as a live cursor and commit on [MoveEndAction].
class MoveAction extends GraphAction {
  final String id;
  final Offset to;
  const MoveAction({required this.id, required this.to});
}

/// Drag finished (or cancelled). This is the commit point.
class MoveEndAction extends GraphAction {
  final String id;
  final Offset to;
  const MoveEndAction({required this.id, required this.to});
}

/// Long-press / ✕ on a node. Subtree semantics are up to the host.
class RemoveAction extends GraphAction {
  final String id;
  const RemoveAction({required this.id});
}

/// Selection is view-local; this is informational (e.g. for a side panel).
class SelectAction extends GraphAction {
  final String? id;
  const SelectAction(this.id);
}

/// What a custom node renderer receives.
class NodeState {
  final GraphNode node;
  final Size size;
  final bool selected;
  final bool canDelete;
  final Color accent;
  final VoidCallback select;
  final VoidCallback addChild;
  final VoidCallback remove;
  final GestureDragStartCallback dragStart;
  final GestureDragUpdateCallback dragUpdate;
  final GestureDragEndCallback dragEnd;

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
    required this.dragEnd,
  });
}

typedef NodeWidgetBuilder = Widget Function(BuildContext context, NodeState state);

// ════════════════════════════════════════════════════════════════════════════
// 3 · Camera — optional imperative handle
// ════════════════════════════════════════════════════════════════════════════

abstract class _CameraDelegate {
  void fitView({required bool animate});
  void zoomBy(double factor);
  void revealNodeById(String id);
}

/// Imperative camera. Safe to call before attach — calls are no-ops.
class GraphViewCamera {
  _CameraDelegate? _delegate;

  bool get isAttached => _delegate != null;

  /// Frames all nodes with padding.
  void fitView({bool animate = true}) => _delegate?.fitView(animate: animate);

  /// Zoom around the viewport center.
  void zoomBy(double factor) => _delegate?.zoomBy(factor);

  /// Pans (animated) so the node is inside the viewport.
  void revealNode(String id) => _delegate?.revealNodeById(id);
}

// ════════════════════════════════════════════════════════════════════════════
// 4 · GraphView
// ════════════════════════════════════════════════════════════════════════════

class GraphView extends StatefulWidget {
  /// Source of truth. Must emit the FULL node list on every event and
  /// deliver the current state on listen (drift `.watch()` and rxdart
  /// `BehaviorSubject` both behave this way).
  final Stream<List<GraphNode>> nodes;

  /// User intent. Wire it to your store/bloc/repository.
  final ValueChanged<GraphAction>? onAction;

  final GraphViewTheme theme;
  final GraphLayout layout;
  final GraphViewCamera? camera;
  final NodeWidgetBuilder? nodeBuilder;
  final bool showControls;
  final bool doubleTapCreatesRoot;
  final bool longPressDeletes;
  final double minScale;
  final double maxScale;

  /// How long an optimistic ghost waits for the real node before fading out.
  final Duration ghostTimeout;

  const GraphView({
    super.key,
    required this.nodes,
    this.onAction,
    this.theme = GraphViewTheme.deep,
    this.layout = const GraphLayout(),
    this.camera,
    this.nodeBuilder,
    this.showControls = true,
    this.doubleTapCreatesRoot = true,
    this.longPressDeletes = true,
    this.minScale = 0.25,
    this.maxScale = 2.5,
    this.ghostTimeout = const Duration(milliseconds: 2500),
  });

  @override
  State<GraphView> createState() => _GraphViewState();
}

class _GraphViewState extends State<GraphView>
    with TickerProviderStateMixin
    implements _CameraDelegate {
  final TransformationController _ctrl = TransformationController();
  final GlobalKey _viewerKey = GlobalKey();

  final Map<String, GraphNode> _nodes = {};
  String? _selectedId;
  String? _draggingId;

  StreamSubscription<List<GraphNode>>? _sub;
  final List<_Ghost> _ghosts = [];
  int _ghostSeq = 0;

  late final AnimationController _revealCtrl;
  late final CurvedAnimation _revealCurved;
  final Map<String, double> _reveals = {};

  late final AnimationController _flyCtrl;
  Animation<Matrix4>? _flyAnim;

  Offset _dragGrab = Offset.zero;
  bool _booted = false;
  bool _firstEmit = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    widget.camera?._delegate = this;   
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _revealCurved = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic);
    _revealCtrl.addListener(_onRevealTick);
    _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _subscribe(widget.nodes);
  }

  @override
  void didUpdateWidget(covariant GraphView old) {
    super.didUpdateWidget(old);
  if (old.camera != widget.camera) {
    old.camera?._delegate = null;           
    widget.camera?._delegate = this;
  }
    if (old.nodes != widget.nodes) {
      _nodes.clear();
      _reveals.clear();
      _ghosts.clear();
      _selectedId = null;
      _firstEmit = false;
      _booted = false;
      _subscribe(widget.nodes);
    }
  }

  @override
  void dispose() {
    widget.camera?._delegate = null;
    _sub?.cancel();
    _revealCtrl.dispose();
    _flyCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _subscribe(Stream<List<GraphNode>> stream) {
    _sub?.cancel();
    _sub = stream.listen(
      _onEmit,
      onError: (Object e) => debugPrint('GraphView: stream error: $e'),
    );
  }

  // ── Diff engine ────────────────────────────────────────────────────────────

  void _onEmit(List<GraphNode> incoming) {
    if (!mounted) return;
    final byId = {for (final n in incoming) n.id: n};
    var changed = false;

    for (final id in _nodes.keys.where((id) => !byId.containsKey(id)).toList()) {
      _nodes.remove(id);
      changed = true;
    }

    for (final fresh in byId.values) {
      final existing = _nodes[fresh.id];
      if (existing == null) {
        _nodes[fresh.id] = fresh;
        changed = true;
      } else if (existing.label != fresh.label ||
          existing.parentId != fresh.parentId ||
          existing.depth != fresh.depth ||
          existing.index != fresh.index) {
        _nodes[fresh.id] = fresh;
        if (fresh.id == _draggingId) fresh.position = existing.position;
        changed = true;
      } else if (existing.position != fresh.position && fresh.id != _draggingId) {
        existing.position = fresh.position;
        changed = true;
      }
    }

    if (_selectedId != null && !_nodes.containsKey(_selectedId)) _selectedId = null;
    _retireGhosts(byId.values);
    _syncReveals();

    if (!_firstEmit) {
      _firstEmit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _nodes.isNotEmpty) fitView(animate: false);
        Future.delayed(const Duration(milliseconds: 450), () {
          if (!mounted) return;
          _revealCtrl.forward();
          setState(() => _booted = true);
        });
      });
    }

    if (changed) setState(() {});
  }

  void _syncReveals() {
    final keys = <String>{};
    for (final n in _nodes.values) {
      if (n.parentId != null) keys.add('${n.parentId}>${n.id}');
    }
    final fresh = keys.difference(_reveals.keys.toSet());
    if (fresh.isNotEmpty) {
      for (final k in fresh) {
        _reveals[k] = 0;
      }
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

  // ── Ghosts — optimistic placeholders while the host round-trips ────────────

  void _spawnGhost({required String? parentId, required Offset at, required Color accent}) {
    _ghosts.add(_Ghost(
      id: 'g${_ghostSeq++}',
      parentId: parentId,
      position: _clamp(at),
      accent: accent,
    ));
    setState(() {});
  }

  void _retireGhosts(Iterable<GraphNode> incoming) {
    if (_ghosts.isEmpty) return;
    final matched = <_Ghost>{};
    for (final g in _ghosts) {
      for (final n in incoming) {
        if (n.parentId == g.parentId && (n.position - g.position).distance < 48) {
          matched.add(g);
          break;
        }
      }
    }
    if (matched.isNotEmpty) {
      _ghosts.removeWhere(matched.contains);
      setState(() {});
    }
  }

  void _ghostGone(_Ghost g) {
    if (_ghosts.remove(g)) setState(() {});
  }

  // ── Actions out ────────────────────────────────────────────────────────────

  void _act(GraphAction a) => widget.onAction?.call(a);

  void _requestChild(GraphNode parent) {
    HapticFeedback.selectionClick();
    final pos = _childSpot(parent);
    _spawnGhost(
      parentId: parent.id,
      at: pos,
      accent: widget.theme.accentFor(parent.depth + 1),
    );
    _act(GraphAction.createChild(parentId: parent.id, at: pos));
  }

  void _requestRoot(Offset scenePoint) {
    HapticFeedback.selectionClick();
    final ns = widget.layout.nodeSize;
    final at = scenePoint - Offset(ns.width / 2, ns.height / 2);
    _spawnGhost(parentId: null, at: at, accent: widget.theme.accentFor(0));
    _act(GraphAction.createRoot(at: at));
  }

  Offset _childSpot(GraphNode parent) {
    final l = widget.layout;
    final siblings = _nodes.values.where((n) => n.parentId == parent.id).length;
    final band = (siblings + 1) ~/ 2;
    final dy = siblings == 0 ? 0.0 : band * l.siblingGap * (siblings.isOdd ? 1 : -1);
    return _clamp(
        Offset(parent.position.dx + parent.size.width + l.levelGap, parent.position.dy + dy));
  }

  // ── Dragging: optimistic locally, committed via MoveEndAction ──────────────

  void _dragStart(GraphNode n, DragStartDetails d) {
    _dragGrab = n.position - _sceneFromGlobal(d.globalPosition);
    _draggingId = n.id;
    if (_selectedId != n.id) {
      _selectedId = n.id;
      _act(GraphAction.select(n.id));
    }
    setState(() {});
  }

  void _dragUpdate(GraphNode n, DragUpdateDetails d) {
    n.position = _clamp(_sceneFromGlobal(d.globalPosition) + _dragGrab, n.size);
    _act(GraphAction.move(id: n.id, to: n.position));
    setState(() {});
  }

  void _dragEnd(GraphNode n) {
    if (_draggingId == n.id) _draggingId = null;
    _act(GraphAction.moveEnd(id: n.id, to: n.position));
  }

  Offset _clamp(Offset pos, [Size? size]) {
    final w = widget.layout.worldSize;
    final ns = size ?? widget.layout.nodeSize;
    return Offset(
      pos.dx.clamp(24, w.width - ns.width - 24),
      pos.dy.clamp(24, w.height - ns.height - 24),
    );
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
    final all = _nodes.values.toList();
    final box = _viewerBox;
    if (all.isEmpty || box == null) return;

    var rect = Rect.fromLTWH(
        all.first.position.dx, all.first.position.dy, all.first.size.width, all.first.size.height);
    for (final n in all) {
      rect = rect.expandToInclude(
          Rect.fromLTWH(n.position.dx, n.position.dy, n.size.width, n.size.height));
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

  void _ensureVisible(Offset scenePoint) {
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

  @override
  void revealNodeById(String id) {
    final n = _nodes[id];
    if (n == null) return;
    _ensureVisible(n.position + Offset(n.size.width / 2, n.size.height / 2));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  List<_EdgeSpec> _buildEdges(GraphViewTheme theme) {
    final out = <_EdgeSpec>[];
    for (final n in _nodes.values) {
      if (n.parentId == null) continue;
      final from = _nodes[n.parentId!];
      if (from == null) continue;
      out.add(_EdgeSpec(
        from,
        n,
        theme.accentFor(from.depth),
        theme.accentFor(n.depth),
        _reveals['${from.id}>${n.id}'] ?? 1,
      ));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final l = widget.layout;
    final ns = l.nodeSize;

    return ClipRect(
      child: Stack(
        children: [
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

          InteractiveViewer(
            key: _viewerKey,
            transformationController: _ctrl,
            constrained: false,
            minScale: widget.minScale,
            maxScale: widget.maxScale,
            child: SizedBox(
              width: l.worldSize.width,
              height: l.worldSize.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (_selectedId != null) {
                          _selectedId = null;
                          _act(GraphAction.select(null));
                          setState(() {});
                        }
                      },
                      onDoubleTapDown: widget.doubleTapCreatesRoot
                          ? (d) => _requestRoot(d.localPosition)
                          : null,
                      child: CustomPaint(painter: _GridPainter(theme)),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _EdgesPainter(_buildEdges(theme), theme)),
                    ),
                  ),

                  // Ghosts sit under real nodes.
                  for (final g in _ghosts)
                    Positioned(
                      key: ValueKey(g.id),
                      left: g.position.dx,
                      top: g.position.dy,
                      width: ns.width,
                      height: ns.height,
                      child: _GhostNode(
                        ghost: g,
                        size: ns,
                        theme: theme,
                        timeout: widget.ghostTimeout,
                        onGone: () => _ghostGone(g),
                      ),
                    ),

                  for (final n in _nodes.values)
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
                            selected: _selectedId == n.id,
                            canDelete: widget.longPressDeletes,
                            accent: theme.accentFor(n.depth),
                            select: () {
                              _selectedId = n.id;
                              _act(GraphAction.select(n.id));
                              setState(() {});
                            },
                            addChild: () => _requestChild(n),
                            remove: () {
                              HapticFeedback.mediumImpact();
                              _act(GraphAction.remove(id: n.id));
                            },
                            dragStart: (d) => _dragStart(n, d),
                            dragUpdate: (d) => _dragUpdate(n, d),
                            dragEnd: (_) => _dragEnd(n),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
// 5 · Default node card
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
            onPanEnd: s.dragEnd,
            onPanCancel: () => s.dragEnd(DragEndDetails()),
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
      child: ScaleTransition(scale: _scale, alignment: Alignment.centerLeft, child: widget.child),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// 6 · Ghost — optimistic placeholder
// ════════════════════════════════════════════════════════════════════════════

class _Ghost {
  final String id;
  final String? parentId;
  final Offset position;
  final Color accent;

  const _Ghost({
    required this.id,
    required this.parentId,
    required this.position,
    required this.accent,
  });
}

class _GhostNode extends StatefulWidget {
  final _Ghost ghost;
  final Size size;
  final GraphViewTheme theme;
  final Duration timeout;
  final VoidCallback onGone;

  const _GhostNode({
    required this.ghost,
    required this.size,
    required this.theme,
    required this.timeout,
    required this.onGone,
  });

  @override
  State<_GhostNode> createState() => _GhostNodeState();
}

class _GhostNodeState extends State<_GhostNode> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Timer _expiry;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _expiry = Timer(widget.timeout, () {
      if (!mounted) return;
      setState(() => _leaving = true);
      Future.delayed(const Duration(milliseconds: 240), widget.onGone);
    });
  }

  @override
  void dispose() {
    _expiry.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.ghost;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _leaving ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, __) {
            return Opacity(
              opacity: 0.55 + 0.4 * _pulse.value,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _DashedBorder(color: g.accent, radius: 13)),
                  Center(
                    child: Icon(Icons.add, size: 16, color: g.accent),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  final Color color;
  final double radius;

  const _DashedBorder({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final pm in path.computeMetrics()) {
      var dist = 0.0;
      const dash = 7.0, gap = 5.5;
      while (dist < pm.length) {
        final end = math.min(dist + dash, pm.length);
        canvas.drawPath(pm.extractPath(dist, end), paint);
        dist = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder old) => old.color != color;
}

// ════════════════════════════════════════════════════════════════════════════
// 7 · Painters
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
  final Color cFrom;
  final Color cTo;
  final double reveal;

  const _EdgeSpec(this.from, this.to, this.cFrom, this.cTo, this.reveal);
}

class _EdgesPainter extends CustomPainter {
  final List<_EdgeSpec> edges;
  final GraphViewTheme theme;

  const _EdgesPainter(this.edges, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      final a = Offset(
        e.from.position.dx + e.from.size.width + 18,
        e.from.position.dy + e.from.size.height / 2,
      );
      final b = Offset(e.to.position.dx - 8, e.to.position.dy + e.to.size.height / 2);

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

      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 8
          ..color = e.cTo.withOpacity(0.12),
      );
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4
          ..shader = ui.Gradient.linear(a, b, [e.cFrom.withOpacity(0.55), e.cTo]),
      );

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
// 8 · Built-in zoom controls
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