import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

import 'graph_theme.dart';

const canvasToolInk = AppColors.onSurfaceVariant;

class CanvasToolSurface extends StatelessWidget {
  const CanvasToolSurface({
    super.key,
    required this.child,
    this.circular = false,
  });
  final Widget child;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final theme = AppGraphThemes.dark;
    final radius = BorderRadius.circular(100);
    final side = BorderSide(color: theme.border);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : radius,
        boxShadow: [
          BoxShadow(
            color: theme.shadow,
            blurRadius: 10,
            offset: circular ? const Offset(0, 3) : const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: theme.controlsBg ,
        clipBehavior: Clip.antiAlias,
        shape: circular
            ? CircleBorder(side: side)
            : RoundedRectangleBorder(borderRadius: radius, side: side),
        child: child,
      ),
    );
  }
}

class CanvasBreadcrumb extends StatelessWidget {
  const CanvasBreadcrumb({
    super.key,
    required this.title,
    required this.onPressed,
    required this.compact,
  });
  final String title;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) => CanvasToolSurface(
    child: Tooltip(
      message: onPressed == null ? title : 'Переключить канвас',
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_tree_outlined,
                size: 18,
                color: canvasToolInk,
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                const Text('Граф', style: TextStyle(color: canvasToolInk)),
              ],
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, size: 17, color: canvasToolInk),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: canvasToolInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
