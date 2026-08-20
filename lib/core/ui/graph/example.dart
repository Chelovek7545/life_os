import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide SelectAction;

import 'graph_view.dart';

void main() => runApp(const StreamGraphApp());

class StreamGraphApp extends StatelessWidget {
  const StreamGraphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GraphView · stream playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const PlaygroundScreen(),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// In-memory store: applies GraphActions, emits full snapshots.
// Swap this for drift / bloc / websocket — the contract stays identical.
// ════════════════════════════════════════════════════════════════════════════

class GraphNodeStore {
  GraphNodeStore({this.layout = const GraphLayout(), this.latency = Duration.zero});

  final GraphLayout layout;
  Duration latency; // simulated round-trip; watch the ghosts bridge it

  final List<GraphNode> _nodes = [];
  int _ids = 0;
  int _labels = 0;
  final _rnd = math.Random();

  final _ctrl = StreamController<List<GraphNode>>.broadcast(sync: true);

  /// Full snapshot on every event; fresh objects every time.
  Stream<List<GraphNode>> get nodes => _ctrl.stream;

  void _emit() => _ctrl.add([for (final n in _nodes) n.clone()]);

  Future<void> apply(GraphAction action) async {
    // MoveAction is a live cursor — never delay or persist it per-event.
    if (action is! MoveAction && latency > Duration.zero) {
      await Future.delayed(latency);
    }
    switch (action) {
      case CreateRootAction(:final at, :final label):
        _addRoot(at, label);
      case CreateChildAction(:final parentId, :final at, :final label):
        _addChild(parentId, at, label);
      case MoveAction(:final id, :final to):
        _move(id, to);
      case MoveEndAction(:final id, :final to):
        _move(id, to);
      case RemoveAction(:final id):
        _removeSubtree(id);
      case SelectAction():
        return; // selection lives in the view; nothing to store
    }
    _emit();
  }

  // ── External mutations — prove the stream is the source of truth ───────────

  String injectRandom() {
    final GraphNode n;
    if (_nodes.isEmpty || _rnd.nextBool()) {
      n = _addRoot(null, null);
    } else {
      final parent = _nodes[_rnd.nextInt(_nodes.length)];
      n = _addChild(parent.id, null, null);
    }
    _emit();
    return n.label;
  }

  String? nudgeRandom() {
    if (_nodes.isEmpty) return null;
    final n = _nodes[_rnd.nextInt(_nodes.length)];
    final i = _nodes.indexOf(n);
    _nodes[i] = GraphNode(
      id: n.id,
      label: n.label,
      index: n.index,
      depth: n.depth,
      parentId: n.parentId,
      position: _clamp(n.position +
          Offset(
            (_rnd.nextDouble() * 2 - 1) * 180,
            (_rnd.nextDouble() * 2 - 1) * 140,
          )),
    );
    _emit();
    return n.id;
  }

  void clearAll() {
    _nodes.clear();
    _emit();
  }

  void seed() {
    final root = _addRoot(null, 'Origin');
    final a = _addChild(root.id, null, null);
    _addChild(root.id, null, null);
    _addChild(a.id, null, null);
    _emit();
  }

  void dispose() => _ctrl.close();

  // ── Internals ──────────────────────────────────────────────────────────────

  GraphNode _addRoot(Offset? at, String? label) {
    final index = _labels++;
    final roots = _nodes.where((n) => n.parentId == null).length;
    final n = GraphNode(
      id: 'n${_ids++}',
      label: label ?? 'Node $index',
      index: index,
      depth: 0,
      parentId: null,
      position: _clamp(at ??
          Offset(
            layout.worldSize.width * 0.32 + (roots % 5) * 60,
            layout.worldSize.height * 0.40 + roots * 130,
          )),
    );
    _nodes.add(n);
    return n;
  }

  GraphNode _addChild(String parentId, Offset? at, String? label) {
    final parent = _nodes.firstWhere((n) => n.id == parentId);
    final index = _labels++;
    final siblings = _nodes.where((n) => n.parentId == parentId).length;
    final band = (siblings + 1) ~/ 2;
    final dy = siblings == 0 ? 0.0 : band * layout.siblingGap * (siblings.isOdd ? 1 : -1);
    final n = GraphNode(
      id: 'n${_ids++}',
      label: label ?? 'Node $index',
      index: index,
      depth: parent.depth + 1,
      parentId: parentId,
      position: _clamp(at ??
          Offset(
            parent.position.dx + layout.nodeSize.width + layout.levelGap,
            parent.position.dy + dy,
          )),
    );
    _nodes.add(n);
    return n;
  }

  void _move(String id, Offset to) {
    final i = _nodes.indexWhere((n) => n.id == id);
    if (i == -1) return;
    final n = _nodes[i];
    _nodes[i] = GraphNode(
      id: n.id,
      label: n.label,
      index: n.index,
      depth: n.depth,
      parentId: n.parentId,
      position: _clamp(to),
    );
  }

  void _removeSubtree(String id) {
    final doomed = <String>{id};
    var grew = true;
    while (grew) {
      grew = false;
      for (final n in _nodes) {
        if (n.parentId != null && doomed.contains(n.parentId!) && doomed.add(n.id)) grew = true;
      }
    }
    _nodes.removeWhere((n) => doomed.contains(n.id));
  }

  Offset _clamp(Offset pos) => Offset(
        pos.dx.clamp(24, layout.worldSize.width - layout.nodeSize.width - 24),
        pos.dy.clamp(24, layout.worldSize.height - layout.nodeSize.height - 24),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Playground screen
// ════════════════════════════════════════════════════════════════════════════

enum _Kind { action, emit, info }

class _Entry {
  final int seq;
  final String time;
  final _Kind kind;
  final String text;

  const _Entry(this.seq, this.time, this.kind, this.text);
}

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  static const _layout = GraphLayout();

  late final GraphNodeStore _store;
  final _camera = GraphViewCamera();
  StreamSubscription<List<GraphNode>>? _consoleSub;

  final List<_Entry> _entries = [];
  int _seq = 0;
  int? _prevCount;
  bool _dark = true;
  bool _slow = false; // 400 ms simulated latency

  GraphViewTheme get _theme => _dark ? GraphViewTheme.deep : GraphViewTheme.paper;

  @override
  void initState() {
    super.initState();
    _store = GraphNodeStore(layout: _layout);
    _consoleSub = _store.nodes.listen((list) => _logEmit(list.length));
    _store.seed();
  }

  @override
  void dispose() {
    _consoleSub?.cancel();
    _store.dispose();
    super.dispose();
  }

  // ── Logging ────────────────────────────────────────────────────────────────

  String _ts() {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${t.millisecond.toString().padLeft(3, '0')}';
  }

  void _log(_Kind kind, String text) {
    setState(() {
      _entries.insert(0, _Entry(_seq++, _ts(), kind, text));
      if (_entries.length > 40) _entries.removeLast();
    });
  }

  void _logEmit(int count) {
    final delta = _prevCount == null ? null : count - _prevCount!;
    _prevCount = count;
    final head = delta == null
        ? 'initial'
        : delta == 0
            ? '·'
            : delta > 0
                ? '+$delta'
                : '$delta';
    _log(_Kind.emit, '← $head node${delta == 1 || delta == -1 ? '' : 's'} · $count total');
  }

  String _describe(GraphAction a) => switch (a) {
        CreateRootAction() => 'createRoot',
        CreateChildAction(:final parentId) => 'createChild($parentId)',
        MoveAction(:final id) => 'move($id)',
        MoveEndAction(:final id) => 'moveEnd($id)',
        RemoveAction(:final id) => 'remove($id)',
        SelectAction(:final id) => 'select(${id ?? '∅'})',
      };

  void _onAction(GraphAction a) {
    if (a is! MoveAction && a is! SelectAction) _log(_Kind.action, '→ ${_describe(a)}');
    if (a is MoveEndAction) _log(_Kind.action, '→ ${_describe(a)}');
    unawaited(_store.apply(a));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = _theme;
    return Scaffold(
      backgroundColor: theme.canvas,
      body: SafeArea(
        child: Column(
          children: [
            _toolbar(theme),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 760;
                  final graph = Expanded(child: _graphArea(theme));
                  final console = _consolePanel(theme);
                  return wide
                      ? Row(
                          children: [
                            graph,
                            SizedBox(width: 264, child: console),
                          ],
                        )
                      : Column(
                          children: [
                            graph,
                            SizedBox(height: 168, child: console),
                          ],
                        );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _graphArea(GraphViewTheme theme) {
    return Stack(
      children: [
        GraphView(
          nodes: _store.nodes,
          onAction: _onAction,
          theme: theme,
          layout: _layout,
          camera: _camera,
        ),
        // Empty-state hint, driven by the same stream.
        StreamBuilder<List<GraphNode>>(
          stream: _store.nodes,
          builder: (context, snap) {
            final empty = (snap.data ?? const []).isEmpty;
            return IgnorePointer(
              child: AnimatedOpacity(
                opacity: empty ? 1 : 0,
                duration: const Duration(milliseconds: 300),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    decoration: BoxDecoration(
                      color: theme.surface.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: theme.border),
                    ),
                    child: Text(
                      'double-tap to plant a root — every change flows through the stream',
                      style: TextStyle(fontSize: 11.5, color: theme.textDim, letterSpacing: 0.3),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _toolbar(GraphViewTheme theme) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.surface,
        border: Border(bottom: BorderSide(color: theme.border)),
        boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 12, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: 'GRAPH', style: TextStyle(color: theme.text)),
                TextSpan(text: 'VIEW', style: TextStyle(color: theme.depthRamp[0])),
              ],
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 2.5),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: theme.depthRamp[2].withOpacity(0.5)),
            ),
            child: Text(
              'STREAM-IN',
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.8,
                color: theme.depthRamp[2],
              ),
            ),
          ),
          const SizedBox(width: 14),
          _divider(theme),
          const SizedBox(width: 14),
          StreamBuilder<List<GraphNode>>(
            stream: _store.nodes,
            builder: (context, snap) {
              final n = snap.data?.length ?? 0;
              final links = snap.data?.where((x) => x.parentId != null).length ?? 0;
              return Text(
                '$n nodes · $links links',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.textDim),
              );
            },
          ),
          const Spacer(),

          // Latency switch — makes the optimistic ghosts visible.
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: theme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _segment('0 ms', !_slow, () => _setLatency(false), theme),
                _segment('400 ms', _slow, () => _setLatency(true), theme),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ToolButton(
            theme: theme,
            icon: Icons.bolt_outlined,
            tooltip: 'Inject a node from outside',
            onTap: () {
              final label = _store.injectRandom();
              _log(_Kind.info, '⇢ injected "$label" from outside');
            },
          ),
          const SizedBox(width: 8),
          _ToolButton(
            theme: theme,
            icon: Icons.open_with_outlined,
            tooltip: 'Nudge a random node',
            onTap: () {
              final id = _store.nudgeRandom();
              if (id != null) _log(_Kind.info, '⇢ nudged $id');
            },
          ),
          const SizedBox(width: 8),
          _ToolButton(
            theme: theme,
            icon: Icons.delete_sweep_outlined,
            tooltip: 'Clear graph',
            onTap: () {
              _store.clearAll();
              _log(_Kind.info, '⇢ cleared');
            },
          ),
          const SizedBox(width: 8),
          _ToolButton(
            theme: theme,
            icon: Icons.fit_screen,
            tooltip: 'Fit graph',
            onTap: () => _camera.fitView(),
          ),
          const SizedBox(width: 8),
          _ToolButton(
            theme: theme,
            icon: _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: 'Toggle theme',
            onTap: () => setState(() => _dark = !_dark),
          ),
        ],
      ),
    );
  }

  void _setLatency(bool slow) {
    setState(() => _slow = slow);
    _store.latency = slow ? const Duration(milliseconds: 400) : Duration.zero;
    _log(_Kind.info, '⇢ latency set to ${slow ? '400 ms' : '0 ms'}');
  }

  // ── Stream console ─────────────────────────────────────────────────────────

  Widget _consolePanel(GraphViewTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.surface.withOpacity(0.55),
        border: Border(left: BorderSide(color: theme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                _EmitPulse(tick: _seq, theme: theme),
                const SizedBox(width: 8),
                Text(
                  'STREAM',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.4,
                    color: theme.textDim,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_seq} events',
                  style: TextStyle(fontSize: 10, color: theme.textDim),
                ),
              ],
            ),
          ),
          Divider(color: theme.border, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                for (final e in _entries) _ConsoleRow(entry: e, theme: theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(String label, bool active, VoidCallback onTap, GraphViewTheme theme) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? theme.surfaceHover : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? theme.text : theme.textDim,
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(GraphViewTheme theme) => Container(width: 1, height: 20, color: theme.border);
}

class _ConsoleRow extends StatefulWidget {
  final _Entry entry;
  final GraphViewTheme theme;

  const _ConsoleRow({required this.entry, required this.theme});

  @override
  State<_ConsoleRow> createState() => _ConsoleRowState();
}

class _ConsoleRowState extends State<_ConsoleRow> with SingleTickerProviderStateMixin {
  late final AnimationController _in;

  @override
  void initState() {
    super.initState();
    _in = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))
      ..forward();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final e = widget.entry;
    final color = switch (e.kind) {
      _Kind.action => t.depthRamp[0],
      _Kind.emit => t.depthRamp[2],
      _Kind.info => t.textDim,
    };
    return FadeTransition(
      opacity: _in,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, -0.35), end: Offset.zero).animate(
          CurvedAnimation(parent: _in, curve: Curves.easeOut),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                e.time,
                style: TextStyle(fontSize: 9, letterSpacing: 0.4, color: t.textDim.withOpacity(0.7)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.text,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmitPulse extends StatefulWidget {
  final int tick;
  final GraphViewTheme theme;

  const _EmitPulse({required this.tick, required this.theme});

  @override
  State<_EmitPulse> createState() => _EmitPulseState();
}

class _EmitPulseState extends State<_EmitPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _seen = widget.tick;
  }

  @override
  void didUpdateWidget(covariant _EmitPulse old) {
    super.didUpdateWidget(old);
    if (widget.tick != _seen) {
      _seen = widget.tick;
      _pulse.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.theme.depthRamp[2];
    return SizedBox(
      width: 13,
      height: 13,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) {
          final k = 1 - _pulse.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (k > 0.02)
                Container(
                  width: 7 + 6 * k,
                  height: 7 + 6 * k,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: c.withOpacity(0.6 * k), width: 1.2),
                  ),
                ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ToolButton extends StatefulWidget {
  final GraphViewTheme theme;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolButton({
    required this.theme,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ToolButton> createState() => _ToolButtonState();
}

class _ToolButtonState extends State<_ToolButton> {
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
            scale: _hovered ? 1.08 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _hovered ? t.surfaceHover : t.surface,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: t.border),
              ),
              child: Icon(widget.icon, size: 16, color: _hovered ? t.text : t.textDim),
            ),
          ),
        ),
      ),
    );
  }
}