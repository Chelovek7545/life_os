import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'component_spec.dart';
import 'palette.dart';

class GraphNodeCard extends StatefulWidget {
  final GraphNodeInteraction state;
  final GraphNodeData node;
  final GraphNodeComponentSpec spec;
  final VoidCallback? onTap;
  final VoidCallback? onAddChild;
  final VoidCallback? onDelete;

  const GraphNodeCard({
    super.key,
    required this.state,
    required this.node,
    required this.spec,
    required this.onTap,
    required this.onAddChild,
    required this.onDelete,
  });

  @override
  State<GraphNodeCard> createState() => _GraphNodeCardState();
}

class _GraphNodeCardState extends State<GraphNodeCard> {
  bool _hovered = false;
  bool _plusHovered = false;
  bool _plusPressed = false;

  GraphComponentPalette get _palette => GraphComponentPalette.of(context);
  Color get _accent =>
      graphColor(widget.node.color, fallback: widget.state.accent);

  bool get _isRound => widget.spec.round;

  @override
  Widget build(BuildContext context) {
    final n = widget.node;
    final s = widget.state;
    final size = widget.state.size;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: (s.hasChildren || s.collapsed)
                ? s.toggleCollapse
                : null,
            onLongPress: widget.onTap == null
                ? null
                : () {
                    widget.state.select();
                    widget.onTap?.call();
                  },
            onPanStart: widget.state.dragStart,
            onPanUpdate: widget.state.dragUpdate,
            onPanEnd: widget.state.dragEnd,
            onPanCancel: () => widget.state.dragEnd(DragEndDetails()),
            child: AnimatedScale(
              scale: _hovered ? 1.03 : 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: size.width,
                height: size.height,
                decoration: BoxDecoration(
                  color: _hovered
                      ? _palette.surfaceBright
                      : _palette.surfaceContainer,
                  borderRadius: BorderRadius.circular(
                    _isRound ? size.width / 2 : 13,
                  ),
                  border: Border.all(
                    color: widget.state.selected
                        ? Colors.white
                        : _accent.withValues(alpha: 0.55),
                    width: widget.state.selected ? 1.6 : 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.state.selected
                          ? _accent.withValues(alpha: 0.45)
                          : _accent.withValues(alpha: 0.18),
                      blurRadius: widget.state.selected ? 20 : 14,
                      spreadRadius: widget.state.selected ? 1 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isRound ? _buildRoundContent(n) : _buildRectContent(n),
              ),
            ),
          ),

          if (_hovered && widget.onDelete != null)
            Positioned(
              top: -9,
              right: -9,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _palette.surfaceBright,
                      border: Border.all(color: _palette.borderGlass),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 12,
                      color: _palette.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),

          if (widget.onAddChild != null)
            Positioned(
              right: -15,
              top: size.height / 2 - 16,
              child: Tooltip(
                message: 'Добавить элемент',
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
                      widget.onAddChild?.call();
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
                              ? Color.lerp(_accent, Colors.white, 0.18)!
                              : _accent,
                          border: Border.all(
                            color: _palette.surfaceDim,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.add,
                          size: 17,
                          color: Color(0xFF08161B),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Шеврон сворачивания — снизу по центру карточки.
          if (s.hasChildren || s.collapsed)
            Positioned(
              left: s.size.width / 2 - 11,
              bottom: -12,
              child: Tooltip(
                message: s.collapsed ? 'Развернуть ветку' : 'Свернуть ветку',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: s.toggleCollapse,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.collapsed
                            ? s.accent
                            : _palette.surfaceContainerHigh,
                        border: Border.all(
                          color: _palette.surfaceContainer,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        s.collapsed ? Icons.chevron_right : Icons.expand_more,
                        size: 14,
                        color: s.collapsed
                            ? const Color(0xFF08161B)
                            : _palette.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Бейдж «+N» — сколько потомков скрыто.
          if (s.collapsed && s.hiddenCount > 0)
            Positioned(
              left: s.size.width / 2 + 16,
              bottom: -9,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: _palette.surface,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: s.accent.withValues(alpha: 0.55)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '+${s.hiddenCount}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: s.accent,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoundContent(GraphNodeData n) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accent.withValues(alpha: 0.18),
              border: Border.all(
                color: _accent.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Icon(widget.spec.icon, color: _accent, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            n.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _palette.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRectContent(GraphNodeData n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 5,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              bottomLeft: Radius.circular(12),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 22, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  widget.spec.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: _accent.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(widget.spec.icon, color: _accent, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _palette.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
                if (n.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    n.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _palette.onSurfaceVariant,
                      fontSize: 10.5,
                    ),
                  ),
                ],
                if (widget.spec.badge?.call(context, n) case final badge?) ...[
                  const SizedBox(height: 5),
                  badge,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
