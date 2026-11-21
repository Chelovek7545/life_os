import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
    final startConnection = s.startConnection;

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.state.select,
            dragStartBehavior: DragStartBehavior.down,
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
                child: Tooltip(
                  message: n.subtitle.isEmpty
                      ? n.title
                      : '${n.title}\n${n.subtitle}',
                  triggerMode: TooltipTriggerMode.manual,
                  child: ClipRect(
                    child: _isRound
                        ? _buildRoundContent(n)
                        : _buildRectContent(n),
                  ),
                ),
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

          if (widget.onAddChild != null || startConnection != null)
            Positioned(
              // Keep the drag handle mounted when the hover-only delete button changes.
              key: const ValueKey('add-child'),
              right: startConnection == null ? -15 : -9,
              top: size.height / 2 - 16,
              child: Tooltip(
                message: startConnection == null
                    ? 'Добавить элемент'
                    : widget.onAddChild == null
                    ? 'Протянуть связь'
                    : 'Добавить элемент или протянуть связь',
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
                    child: _connectionHandle(
                      startConnection: startConnection,
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

  Widget _connectionHandle({
    required GestureMultiDragStartCallback? startConnection,
    required Widget child,
  }) {
    if (startConnection == null) return child;
    return RawGestureDetector(
      key: ValueKey('graph-connect:${widget.node.id}'),
      gestures: {
        ImmediateMultiDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              ImmediateMultiDragGestureRecognizer
            >(
              ImmediateMultiDragGestureRecognizer.new,
              (recognizer) => recognizer.onStart = startConnection,
            ),
      },
      child: child,
    );
  }

  Widget _buildRoundContent(GraphNodeData node) {
    final details = widget.spec.details?.call(context, node, widget.state);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, space) {
          final showIcon = space.maxHeight >= 74 && space.maxWidth >= 42;
          final showDetails = details != null && space.maxHeight >= 86;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showIcon) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accent.withValues(alpha: .18),
                    border: Border.all(color: _accent.withValues(alpha: .6)),
                  ),
                  child: Icon(widget.spec.icon, color: _accent, size: 22),
                ),
                const SizedBox(height: 5),
              ],
              Flexible(child: _title(node.title, centered: true)),
              if (showDetails) ...[
                const SizedBox(height: 3),
                SizedBox(
                  height: 16,
                  child: FittedBox(fit: BoxFit.scaleDown, child: details),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _title(String title, {bool centered = false}) => LayoutBuilder(
    builder: (context, space) {
      final lineHeight = MediaQuery.textScalerOf(context).scale(13) * 1.2;
      return Text(
        title,
        maxLines: (space.maxHeight / lineHeight).floor().clamp(1, 4),
        textAlign: centered ? TextAlign.center : TextAlign.start,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: _palette.onSurface,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      );
    },
  );

  Widget _buildRectContent(GraphNodeData node) {
    final badge = widget.spec.badge?.call(context, node);
    final details = widget.spec.details?.call(context, node, widget.state);
    final showDescription =
        widget.spec.details == null && node.subtitle.isNotEmpty;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: _accent, width: 4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        child: LayoutBuilder(
          builder: (context, space) {
            final scaler = MediaQuery.textScalerOf(context);
            final labelHeight = scaler.scale(9) * 1.2;
            final footerHeight = math.max(18.0, scaler.scale(10) * 1.2 + 6);
            final titleBudget = scaler.scale(13) * 2.4;
            final showFooter =
                (details != null || badge != null || showDescription) &&
                space.maxHeight >= footerHeight + titleBudget + 4 &&
                space.maxWidth >= 42;
            final showLabel =
                space.maxHeight >=
                labelHeight +
                    titleBudget +
                    4 +
                    (showFooter ? footerHeight + 4 : 0);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (showLabel) ...[
                  Text(
                    widget.spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _accent,
                      fontSize: 9,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Expanded(
                  child: Row(
                    children: [
                      if (space.maxWidth >= 52) ...[
                        widget.spec.leading?.call(
                              context,
                              node,
                              widget.state,
                            ) ??
                            Icon(widget.spec.icon, color: _accent, size: 18),
                        const SizedBox(width: 6),
                      ],
                      Expanded(child: _title(node.title)),
                    ],
                  ),
                ),
                if (showFooter) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: footerHeight,
                    child: Row(
                      children: [
                        if (details != null)
                          Expanded(child: details)
                        else if (showDescription)
                          Expanded(
                            child: Text(
                              node.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _palette.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        if (badge != null) ...[
                          const SizedBox(width: 5),
                          Flexible(
                            flex: details == null && !showDescription ? 4 : 1,
                            child: badge,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class GraphNodeMetaChip extends StatelessWidget {
  const GraphNodeMetaChip({
    super.key,
    required this.label,
    this.icon,
    this.accent,
  });

  final String label;
  final IconData? icon;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = GraphComponentPalette.of(context);
    final foreground = accent ?? palette.onSurfaceVariant;
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent?.withValues(alpha: .18) ?? palette.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: accent == null
              ? null
              : Border.all(color: accent!.withValues(alpha: .45)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: foreground, size: 11),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
