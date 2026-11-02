import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

// Windows Tooltip/OverlayPortal can orphan accessibility nodes inside ListView:
// https://github.com/flutter/flutter/issues/182444
// Keep the hint on the control's semantics node; its visual overlay has no nodes.
class CalendarTaskHint extends StatefulWidget {
  const CalendarTaskHint({
    super.key,
    required this.message,
    required this.child,
  });
  final String message;
  final Widget child;
  @override
  State<CalendarTaskHint> createState() => _CalendarTaskHintState();
}

class _CalendarTaskHintState extends State<CalendarTaskHint> {
  Timer? _delay;
  OverlayEntry? _entry;
  ScrollPosition? _scroll;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _hide();
    _scroll?.removeListener(_hide);
    _scroll = Scrollable.maybeOf(context)?.position;
    _scroll?.addListener(_hide);
  }

  @override
  void didUpdateWidget(CalendarTaskHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message != widget.message) _hide();
  }

  void _hide() {
    _delay?.cancel();
    _delay = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void _show() {
    if (!mounted || _entry != null) return;
    final overlay = Overlay.of(context);
    final target = context.findRenderObject()! as RenderBox;
    final surface = overlay.context.findRenderObject()! as RenderBox;
    final origin = target.localToGlobal(Offset.zero, ancestor: surface);
    final width = math.min(320.0, math.max(0.0, surface.size.width - 16));
    final left = origin.dx.clamp(
      8.0,
      math.max(8.0, surface.size.width - width - 8),
    );
    final top = (origin.dy + target.size.height + 6).clamp(
      8.0,
      math.max(8.0, surface.size.height - 132),
    );
    _entry = OverlayEntry(
      builder: (_) => Positioned(
          left: left.toDouble(),
          top: top.toDouble(),
        width: width,
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  widget.message,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    overlay.insert(_entry!);
  }

  @override
  void dispose() {
    _scroll?.removeListener(_hide);
    _hide();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Theme.of(context).platform != TargetPlatform.windows) {
      return Tooltip(
        message: widget.message,
        triggerMode: TooltipTriggerMode.manual,
        child: widget.child,
      );
    }
    return Semantics(
      tooltip: widget.message,
      child: MouseRegion(
        onEnter: (_) {
          _delay?.cancel();
          _delay = Timer(const Duration(milliseconds: 400), _show);
        },
        onExit: (_) => _hide(),
        child: Listener(onPointerDown: (_) => _hide(), child: widget.child),
      ),
    );
  }
}
