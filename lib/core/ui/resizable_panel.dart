import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

class ResizablePanel extends StatefulWidget {
  final Widget child;
  final double initialWidth;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double>? onWidthChanged;

  const ResizablePanel({
    super.key,
    required this.child,
    this.initialWidth = 300,
    this.minWidth = 200,
    this.maxWidth = 600,
    this.onWidthChanged,
  });

  @override
  State<ResizablePanel> createState() => _ResizablePanelState();
}

class _ResizablePanelState extends State<ResizablePanel> {
  late double _width;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _width = widget.initialWidth;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _width = (_width - details.delta.dx)
          .clamp(widget.minWidth, widget.maxWidth);
    });
    widget.onWidthChanged?.call(_width);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned(
            left: -3,
            top: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              onHover: (_) => setState(() => _isHovering = true),
              onExit: (_) => setState(() => _isHovering = false),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate: _onDragUpdate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  color: Colors.transparent,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: _isHovering
                          ? AppColors.secondary.withValues(alpha: 0.4)
                          : Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
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
