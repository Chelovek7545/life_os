import 'package:flutter/material.dart';
import 'package:life_os/features/lifegraph/presentation/v1.dart';



void main() => runApp(const PlaygroundApp());

class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GraphView playground',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: const PlaygroundScreen(),
    );
  }
}

class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  late final GraphViewController _controller;
  bool _dark = true;
  bool _chips = false;
  String _lastEvent = 'graph seeded';

  GraphViewTheme get _theme => _dark ? GraphViewTheme.deep : GraphViewTheme.paper;

  @override
  void initState() {
    super.initState();
    _controller = GraphViewController();

    // Event hooks — the widget reports everything back.
    _controller.onNodeCreated = (n) => _flash('＋ ${n.label}');
    _controller.onSubtreeRemoved = (list) => _flash('－ ${list.first.label} ×${list.length}');
    _controller.onSelectionChanged = (n) => _flash(n == null ? 'selection cleared' : '● ${n.label}');

    // Seed something alive before the first frame.
    final root = _controller.addRoot(label: 'Origin');
    final a = _controller.addChild(root.id);
    _controller.addChild(root.id);
    _controller.addChild(a.id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _flash(String s) {
    if (!mounted) return;
    setState(() => _lastEvent = s);
  }

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
              // ── The entire graph, in one widget ──────────────────────────
              child: GraphView(
                controller: _controller,
                theme: theme,
                nodeBuilder: _chips ? _chipNode : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────────────

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
              border: Border.all(color: theme.depthRamp[0].withOpacity(0.5)),
            ),
            child: Text(
              'ONE WIDGET',
              style: TextStyle(
                fontSize: 8.5, fontWeight: FontWeight.w700,
                letterSpacing: 1.8, color: theme.depthRamp[0],
              ),
            ),
          ),
          const SizedBox(width: 14),
          _divider(theme),
          const SizedBox(width: 14),
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Text(
              '${_controller.nodes.length} nodes · ${_controller.linkCount} links',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.textDim),
            ),
          ),
          const SizedBox(width: 14),
          _divider(theme),
          const SizedBox(width: 14),
          SizedBox(
            width: 190,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  '› $_lastEvent',
                  key: ValueKey(_lastEvent),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: theme.textDim, letterSpacing: 0.3),
                ),
              ),
            ),
          ),
          const Spacer(),

          // Node style: default cards vs custom nodeBuilder.
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
                _segment('cards', !_chips, () => setState(() => _chips = false), theme),
                _segment('chips', _chips, () => setState(() => _chips = true), theme),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _ToolButton(
            theme: theme,
            icon: _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            tooltip: 'Toggle theme',
            onTap: () => setState(() => _dark = !_dark),
          ),
          const SizedBox(width: 8),
          _ToolButton(
            theme: theme,
            icon: Icons.fit_screen,
            tooltip: 'Fit graph',
            onTap: () => _controller.fitView(),
          ),
          const SizedBox(width: 8),
          _HoverScale(
            child: GestureDetector(
              onTap: () {
                final n = _controller.addRoot();
                _controller.revealNode(n.id);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: theme.depthRamp[0],
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [BoxShadow(color: theme.shadow, blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 13, color: Color(0xFF102026)),
                    const SizedBox(width: 5),
                    Text(
                      'root',
                      style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w800,
                        letterSpacing: 0.6, color: Color(0xFF102026),
                      ),
                    ),
                  ],
                ),
              ),
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

  Widget _divider(GraphViewTheme theme) =>
      Container(width: 1, height: 20, color: theme.border);

  // ── Custom node renderer — proves the nodeBuilder hook ─────────────────────

  Widget _chipNode(BuildContext context, NodeState s) {
    final theme = _theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: s.select,
      onLongPress: s.canDelete ? s.remove : null,
      onPanStart: s.dragStart,
      onPanUpdate: s.dragUpdate,
      child: MouseRegion(
        cursor: SystemMouseCursors.grab,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Center(
              child: Container(
                width: s.size.width,
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: theme.surface,
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: s.selected ? s.accent : theme.border,
                    width: s.selected ? 1.6 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: s.selected ? s.accent.withOpacity(0.30) : theme.shadow,
                      blurRadius: s.selected ? 18 : 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: s.accent),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        s.node.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700, color: theme.text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -9,
              top: s.size.height / 2 - 10,
              child: GestureDetector(
                onTap: s.addChild,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: s.accent,
                      border: Border.all(color: theme.canvas, width: 2.5),
                    ),
                    child: const Icon(Icons.add, size: 11, color: Color(0xFF102026)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small shared bits ────────────────────────────────────────────────────────

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

class _HoverScale extends StatefulWidget {
  final Widget child;

  const _HoverScale({required this.child});

  @override
  State<_HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<_HoverScale> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.06 : 1,
        duration: const Duration(milliseconds: 140),
        child: widget.child,
      ),
    );
  }
}