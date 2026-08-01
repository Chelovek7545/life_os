import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Tip: for extra character, add `google_fonts` and swap the wordmark/labels
// to something like 'Space Grotesk' + 'IBM Plex Sans'.

void main() => runApp(const NodeFieldApp());

class NodeFieldApp extends StatelessWidget {
  const NodeFieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nodefield',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: Palette.canvasDeep,
      ),
      home: const GraphScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Palette & layout constants
// ─────────────────────────────────────────────────────────────────────────────

class Palette {
  static const canvasDeep = Color(0xFF0B1E24);
  static const surface = Color(0xFF152E36);
  static const surfaceLight = Color(0xFF1D3B45);
  static const line = Color(0xFF2A4854);
  static const ink = Color(0xFFEAF4F4);
  static const inkDim = Color(0xFF8FA9AD);

  /// Depth ramp — a node's accent color is derived from its depth.
  static const ramp = [
    Color(0xFFFFB454), // amber   (roots)
    Color(0xFFFF6B5E), // coral
    Color(0xFF34D3A6), // mint
    Color(0xFF58A6FF), // sky
  ];
}

const double kNodeW = 176;
const double kNodeH = 68;
const Size kWorld = Size(4200, 4200);

Color accentFor(int depth) => Palette.ramp[depth % Palette.ramp.length];

// ─────────────────────────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────────────────────────

class GraphNode {
  final String id;
  final String label;
  final int index;
  final int depth;
  final String? parentId;
  final bool seeded;
  Offset position; // top-left, in world/scene coordinates

  GraphNode({
    required this.id,
    required this.label,
    required this.index,
    required this.depth,
    required this.parentId,
    required this.position,
    this.seeded = false,
  });
}

class GraphModel extends ChangeNotifier {
  final Map<String, GraphNode> nodes = {};
  String? selectedId;

  int _ids = 0;
  int _labels = 0;

  int get linkCount => nodes.values.where((n) => n.parentId != null).length;

  GraphNode addRoot(Offset at, {bool seeded = false}) {
    final n = GraphNode(
      id: 'n${_ids++}',
      label: _labels == 0 ? 'Origin' : 'Node $_labels',
      index: _labels++,
      depth: 0,
      parentId: null,
      position: _clamp(at),
      seeded: seeded,
    );
    nodes[n.id] = n;
    notifyListeners();
    return n;
  }

  GraphNode addChild(String parentId, {bool seeded = false}) {
    final p = nodes[parentId]!;
    final siblings = nodes.values.where((n) => n.parentId == parentId).length;
    // Fan children out above/below the parent's axis: 0, +112, -112, +224, …
    final band = (siblings + 1) ~/ 2;
    final dy = siblings == 0 ? 0.0 : band * 112.0 * (siblings.isOdd ? 1 : -1);

    final n = GraphNode(
      id: 'n${_ids++}',
      label: 'Node ${_labels++}',
      index: _labels - 1,
      depth: p.depth + 1,
      parentId: parentId,
      position: _clamp(Offset(p.position.dx + kNodeW + 236, p.position.dy + dy)),
      seeded: seeded,
    );
    nodes[n.id] = n;
    notifyListeners();
    return n;
  }

  void moveNode(String id, Offset to) {
    final n = nodes[id];
    if (n == null) return;
    n.position = _clamp(to);
    notifyListeners();
  }

  void select(String? id) {
    if (selectedId == id) return;
    selectedId = id;
    notifyListeners();
  }

  /// Removes a node and its entire subtree.
  void removeSubtree(String id) {
    final doomed = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in nodes.values) {
        if (n.parentId != null && doomed.contains(n.parentId!) && doomed.add(n.id)) {
          grew = true;
        }
      }
    }
    doomed.forEach(nodes.remove);
    if (doomed.contains(selectedId)) selectedId = null;
    notifyListeners();
  }

  Offset _clamp(Offset p) => Offset(
        p.dx.clamp(24, kWorld.width - kNodeW - 24),
        p.dy.clamp(24, kWorld.height - kNodeH - 24),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen: canvas, camera, HUD
// ─────────────────────────────────────────────────────────────────────────────

class GraphScreen extends StatefulWidget {
  const GraphScreen({super.key});

  @override
  State<GraphScreen> createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> with TickerProviderStateMixin {
  late final GraphModel _model;
  final TransformationController _ctrl = TransformationController();
  final GlobalKey _viewerKey = GlobalKey();

  late final AnimationController _revealCtrl;
  late final CurvedAnimation _revealCurved;
  final Map<String, double> _reveals = {}; // 'parent>child' -> draw progress

  late final AnimationController _flyCtrl;
  Animation<Matrix4>? _flyAnim;

  Offset _dragGrab = Offset.zero;

  @override
  void initState() {
    super.initState();
    _model = GraphModel();
    _seed();

    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 750));
    _revealCurved = CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOutCubic);
    _revealCtrl.addListener(_onRevealTick);

    _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitView(animate: false);
      // Let the nodes pop in first, then draw the edges.
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _revealCtrl.forward();
      });
    });
  }

  void _seed() {
    final root = _model.addRoot(
      Offset(kWorld.width / 2 - 640, kWorld.height / 2 - kNodeH / 2),
      seeded: true,
    );
    final a = _model.addChild(root.id, seeded: true);
    _model.addChild(root.id, seeded: true);
    _model.addChild(a.id, seeded: true);
    for (final n in _model.nodes.values) {
      if (n.parentId != null) _reveals['${n.parentId}>${n.id}'] = 0;
    }
    _model.select(null);
  }

  @override
  void dispose() {
    _revealCtrl.dispose();
    _flyCtrl.dispose();
    _ctrl.dispose();
    _model.dispose();
    super.dispose();
  }

  // ── Camera helpers ─────────────────────────────────────────────────────────

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

  void _fitView({bool animate = true}) {
    final all = _model.nodes.values.toList();
    final box = _viewerBox;
    if (all.isEmpty || box == null) return;

    var rect = Rect.fromLTWH(all.first.position.dx, all.first.position.dy, kNodeW, kNodeH);
    for (final n in all) {
      rect = rect.expandToInclude(
        Rect.fromLTWH(n.position.dx, n.position.dy, kNodeW, kNodeH),
      );
    }
    rect = rect.inflate(150);

    final vp = box.size;
    final s = math.min(vp.width / rect.width, vp.height / rect.height).clamp(0.25, 1.1);
    final m = Matrix4.identity()
      ..scale(s, s)
      ..translate(
        (vp.width / 2 - s * rect.center.dx) / s,
        (vp.height / 2 - s * rect.center.dy) / s,
      );
    animate ? _flyTo(m) : _ctrl.value = m;
  }

  void _zoomBy(double f) {
    final box = _viewerBox;
    if (box == null) return;
    final s0 = _ctrl.value.getMaxScaleOnAxis();
    final s1 = (s0 * f).clamp(0.25, 2.5);
    f = s1 / s0;

    final c = _ctrl.toScene(box.size.center(Offset.zero));
    final around = Matrix4.identity()
      ..translate(c.dx, c.dy)
      ..scale(f, f)
      ..translate(-c.dx, -c.dy);
    _flyTo(_ctrl.value.clone()..multiply(around));
  }

  /// Nudges the camera (animated) if a world point sits outside the viewport.
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

  // ── Graph actions ──────────────────────────────────────────────────────────

  void _spawnChild(String parentId) {
    HapticFeedback.selectionClick();
    final child = _model.addChild(parentId);
    _reveals['$parentId>${child.id}'] = 0;
    _revealCtrl.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureVisible(child.position + const Offset(kNodeW / 2, kNodeH / 2));
    });
  }

  void _spawnRootAt(Offset scene) {
    HapticFeedback.selectionClick();
    final n = _model.addRoot(scene - Offset(kNodeW / 2, kNodeH / 2));
    _model.select(n.id);
  }

  void _prune(GraphNode n) {
    HapticFeedback.mediumImpact();
    _model.removeSubtree(n.id);
  }

  void _dragStart(GraphNode n, DragStartDetails d) {
    _dragGrab = n.position - _sceneFromGlobal(d.globalPosition);
    _model.select(n.id);
  }

  void _dragUpdate(GraphNode n, DragUpdateDetails d) {
    _model.moveNode(n.id, _sceneFromGlobal(d.globalPosition) + _dragGrab);
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

  // ── Build ──────────────────────────────────────────────────────────────────

  List<_EdgeSpec> _buildEdges() {
    final out = <_EdgeSpec>[];
    for (final n in _model.nodes.values) {
      if (n.parentId == null) continue;
      final p = _model.nodes[n.parentId!];
      if (p == null) continue;
      out.add(_EdgeSpec(p, n, accentFor(p.depth), accentFor(n.depth),
          _reveals['${p.id}>${n.id}'] ?? 1));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.canvasDeep,
      body: Stack(
        children: [
          // Ambient, layered backdrop (fixed while the world pans — soft parallax).
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.25, -0.35),
                  radius: 1.5,
                  colors: [
                    Palette.canvasDeep.withBlue(64).withGreen(46),
                    Palette.canvasDeep,
                    const Color(0xFF07141A),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -160, top: -180, width: 560, height: 560,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x12FFB454), Colors.transparent]),
                ),
              ),
            ),
          ),
          Positioned(
            right: -180, bottom: -220, width: 640, height: 640,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [Color(0x1034D3A6), Colors.transparent]),
                ),
              ),
            ),
          ),

          // The world.
          ListenableBuilder(
            listenable: _model,
            builder: (context, _) {
              return InteractiveViewer(
                key: _viewerKey,
                transformationController: _ctrl,
                constrained: false,
                minScale: 0.25,
                maxScale: 2.5,
                child: SizedBox(
                  width: kWorld.width,
                  height: kWorld.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _model.select(null),
                          onDoubleTapDown: (d) => _spawnRootAt(d.localPosition),
                          child: const CustomPaint(painter: GridPainter()),
                        ),
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(painter: EdgesPainter(_buildEdges())),
                        ),
                      ),
                      for (final n in _model.nodes.values)
                        Positioned(
                          key: ValueKey(n.id),
                          left: n.position.dx,
                          top: n.position.dy,
                          width: kNodeW,
                          height: kNodeH,
                          child: NodeCard(
                            node: n,
                            accent: accentFor(n.depth),
                            selected: _model.selectedId == n.id,
                            delayMs: n.seeded ? n.index * 120 : 0,
                            onSelect: () => _model.select(n.id),
                            onAddChild: () => _spawnChild(n.id),
                            onDelete: () => _prune(n),
                            onDragStart: (d) => _dragStart(n, d),
                            onDragUpdate: (d) => _dragUpdate(n, d),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),

          _buildHud(),
        ],
      ),
    );
  }

  Widget _buildHud() {
    final count = _model.nodes.length;
    return Stack(
      children: [
        // Wordmark + live counts.
        Positioned(
          top: 18,
          left: 18,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            decoration: BoxDecoration(
              color: Palette.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Palette.line),
              boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFFFFB454)),
                    const SizedBox(width: 8),
                    Text.rich(
                      TextSpan(
                        children: const [
                          TextSpan(text: 'NODE', style: TextStyle(color: Palette.ink)),
                          TextSpan(text: 'FIELD', style: TextStyle(color: Color(0xFFFFB454))),
                        ],
                        style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: 3.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '$count ${count == 1 ? 'node' : 'nodes'} · ${_model.linkCount} links',
                  style: const TextStyle(fontSize: 11, color: Palette.inkDim, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),

        // Hint chip.
        Positioned(
          left: 18,
          bottom: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: Palette.surface.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Palette.line),
            ),
            child: const Text(
              'double-tap canvas → new root    ·    drag node → move    ·    long-press → prune branch',
              style: TextStyle(fontSize: 10.5, color: Palette.inkDim, letterSpacing: 0.4),
            ),
          ),
        ),

        // Zoom cluster.
        Positioned(
          right: 18,
          bottom: 18,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder<Matrix4>(
                valueListenable: _ctrl,
                builder: (context, m, _) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Palette.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Palette.line),
                  ),
                  child: Text(
                    '${(m.getMaxScaleOnAxis() * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: Palette.inkDim, letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              _HudButton(icon: Icons.add, onTap: () => _zoomBy(1.25), tooltip: 'Zoom in'),
              const SizedBox(height: 8),
              _HudButton(icon: Icons.remove, onTap: () => _zoomBy(0.8), tooltip: 'Zoom out'),
              const SizedBox(height: 8),
              _HudButton(icon: Icons.fit_screen, onTap: () => _fitView(), tooltip: 'Fit graph'),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Node card
// ─────────────────────────────────────────────────────────────────────────────

class NodeCard extends StatefulWidget {
  final GraphNode node;
  final Color accent;
  final bool selected;
  final int delayMs;
  final VoidCallback onSelect;
  final VoidCallback onAddChild;
  final VoidCallback onDelete;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;

  const NodeCard({
    super.key,
    required this.node,
    required this.accent,
    required this.selected,
    required this.delayMs,
    required this.onSelect,
    required this.onAddChild,
    required this.onDelete,
    required this.onDragStart,
    required this.onDragUpdate,
  });

  @override
  State<NodeCard> createState() => _NodeCardState();
}

class _NodeCardState extends State<NodeCard> with SingleTickerProviderStateMixin {
  late final AnimationController _pop;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  bool _hovered = false;
  bool _plusHovered = false;
  bool _plusPressed = false;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scale = CurvedAnimation(parent: _pop, curve: Curves.elasticOut);
    _fade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pop, curve: const Interval(0, 0.25)),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _pop.forward();
    });
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        alignment: Alignment.centerLeft, // grow out of the parent's plus button
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Card body — tap to select, drag to move, long-press to prune.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onSelect,
                onLongPress: widget.onDelete,
                onPanStart: widget.onDragStart,
                onPanUpdate: widget.onDragUpdate,
                child: AnimatedScale(
                  scale: _hovered ? 1.03 : 1,
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: kNodeW,
                    height: kNodeH,
                    decoration: BoxDecoration(
                      color: _hovered ? Palette.surfaceLight : Palette.surface,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: widget.selected ? widget.accent : Palette.line,
                        width: widget.selected ? 1.6 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.selected
                              ? widget.accent.withOpacity(0.30)
                              : const Color(0x59000000),
                          blurRadius: widget.selected ? 22 : 10,
                          spreadRadius: widget.selected ? 1 : 0,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 5,
                          decoration: BoxDecoration(
                            color: widget.accent,
                            borderRadius: BorderRadius.only(
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
                                  style: const TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4, color: Palette.inkDim,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  n.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700,
                                    color: Palette.ink, height: 1.1,
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

              // Prune button — revealed on hover (long-press works on touch).
              Positioned(
                top: -9,
                right: -9,
                child: IgnorePointer(
                  ignoring: !_hovered,
                  child: AnimatedOpacity(
                    opacity: _hovered ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: GestureDetector(
                      onTap: widget.onDelete,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Palette.surfaceLight,
                            border: Border.all(color: Palette.line),
                          ),
                          child: const Icon(Icons.close, size: 11, color: Palette.inkDim),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // The plus button — grows a child from this node.
              Positioned(
                right: -15,
                top: kNodeH / 2 - 16,
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
                                ? Color.lerp(widget.accent, Colors.white, 0.18)!
                                : widget.accent,
                            border: Border.all(color: Palette.canvasDeep, width: 3),
                            boxShadow: [
                              const BoxShadow(
                                color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 3),
                              ),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Painters: dot grid + bezier edges
// ─────────────────────────────────────────────────────────────────────────────

class GridPainter extends CustomPainter {
  const GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const fine = 42.0;
    final fineDots = <Offset>[];
    for (var x = fine; x < size.width; x += fine) {
      for (var y = fine; y < size.height; y += fine) {
        fineDots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      fineDots,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.7
        ..color = const Color(0xFF1C313A),
    );

    final coarseDots = <Offset>[];
    const coarse = fine * 4;
    for (var x = coarse; x < size.width; x += coarse) {
      for (var y = coarse; y < size.height; y += coarse) {
        coarseDots.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      coarseDots,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3
        ..color = const Color(0xFF24404B),
    );
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => false;
}

class _EdgeSpec {
  final GraphNode from;
  final GraphNode to;
  final Color cFrom;
  final Color cTo;
  final double reveal; // 0..1 draw-in progress

  const _EdgeSpec(this.from, this.to, this.cFrom, this.cTo, this.reveal);
}

class EdgesPainter extends CustomPainter {
  final List<_EdgeSpec> edges;

  const EdgesPainter(this.edges);

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      // Emerge just past the parent's plus button; land at the child's left edge.
      final a = Offset(e.from.position.dx + kNodeW + 18, e.from.position.dy + kNodeH / 2);
      final b = Offset(e.to.position.dx - 8, e.to.position.dy + kNodeH / 2);

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

      // Soft under-glow.
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 8
          ..color = e.cTo.withOpacity(0.10),
      );

      // Gradient stroke, parent hue → child hue.
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.4
          ..shader = ui.Gradient.linear(a, b, [e.cFrom.withOpacity(0.55), e.cTo]),
      );

      // Spark at the drawing tip.
      if (e.reveal < 1 && pm != null) {
        final tip = pm.getTangentForOffset(pm.length * e.reveal)?.position ?? b;
        canvas.drawCircle(tip, 7, Paint()..color = Colors.white.withOpacity(0.18));
        canvas.drawCircle(tip, 3.2, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(covariant EdgesPainter oldDelegate) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD button
// ─────────────────────────────────────────────────────────────────────────────

class _HudButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _HudButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  State<_HudButton> createState() => _HudButtonState();
}

class _HudButtonState extends State<_HudButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
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
                color: _hovered ? Palette.surfaceLight : Palette.surface.withOpacity(0.85),
                border: Border.all(color: Palette.line),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 10, offset: Offset(0, 3))],
              ),
              child: Icon(widget.icon, size: 17, color: _hovered ? Palette.ink : Palette.inkDim),
            ),
          ),
        ),
      ),
    );
  }
}