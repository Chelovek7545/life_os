import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

import 'graph_theme.dart';

const canvasToolInk = AppColors.onSurfaceVariant;

class CanvasToolSurface extends StatelessWidget {
  const CanvasToolSurface({
    super.key,
    required this.child,
    this.floating = false,
    this.circular = false,
  });
  final Widget child;
  final bool floating;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final theme = AppGraphThemes.dark;
    final radius = BorderRadius.circular(floating ? 17 : 100);
    final side = BorderSide(color: theme.border);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular ? null : radius,
        boxShadow: [
          BoxShadow(
            color: floating
                ? theme.shadow.withValues(alpha: .52)
                : theme.shadow,
            blurRadius: floating ? 22 : 10,
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

enum CanvasNodeAction { edit, link, copy, delete, more }

Future<CanvasNodeAction?> showCanvasNodeActions(
  BuildContext context,
  Rect bounds, {
  required bool canEdit,
  required bool canLink,
}) {
  final theme = AppGraphThemes.dark;
  final overlay =
      Navigator.of(
            context,
            rootNavigator: true,
          ).overlay!.context.findRenderObject()!
          as RenderBox;
  final anchor = bounds.shift(-overlay.localToGlobal(Offset.zero));
  final origin = MediaQueryData.fromView(View.of(context)).padding;
  return showGeneralDialog<CanvasNodeAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть меню карточки',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 100),
    pageBuilder: (context, _, _) => SafeArea(
      child: LayoutBuilder(
        builder: (context, size) {
          final rect = anchor.shift(Offset(-origin.left, -origin.top));
          final width = math.min(262.0, math.max(size.maxWidth - 16, 1.0));
          final spacing = width >= 225 ? 5.0 : 2.0;
          const actionGap = SizedBox(width: 4);
          final buttonSize = Size.square(
            math.max(1.0, math.min(38.0, (width - spacing * 2 - 29) / 5)),
          );
          const height = 56.0;
          final left = (rect.center.dx - width / 2)
              .clamp(8.0, math.max(8.0, size.maxWidth - width - 8))
              .toDouble();
          final above = rect.top >= height + 12;
          final top = (above ? rect.top - height - 8 : rect.bottom + 8)
              .clamp(6.0, math.max(6.0, size.maxHeight - height - 8))
              .toDouble();
          final arrow = (rect.center.dx - left - 5)
              .clamp(12.0, math.max(12.0, width - 22))
              .toDouble();
          Widget action(
            CanvasNodeAction value,
            IconData icon,
            String tooltip, {
            bool enabled = true,
          }) => IconButton(
            icon: Icon(icon, size: 19),
            tooltip: tooltip,
            onPressed: enabled ? () => Navigator.of(context).pop(value) : null,
            style: IconButton.styleFrom(
              foregroundColor: theme.textDim,
              disabledForegroundColor: theme.textDim.withValues(alpha: .38),
              backgroundColor: Colors.transparent,
              overlayColor: theme.textDim.withValues(alpha: .12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: EdgeInsets.zero,
              minimumSize: buttonSize,
              maximumSize: buttonSize,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
          return Stack(
            children: [
              Positioned(
                left: left + arrow,
                top: above ? top + height - 6 : top - 5,
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: theme.controlsBg,
                      border: Border.all(color: theme.border),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
                child: CanvasToolSurface(
                  floating: true,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      action(
                        CanvasNodeAction.edit,
                        Icons.edit_outlined,
                        'Редактировать карточку',
                        enabled: canEdit,
                      ),
                      actionGap,
                      action(
                        CanvasNodeAction.link,
                        Icons.link,
                        'Связать с карточкой',
                        enabled: canLink,
                      ),
                      actionGap,
                      action(
                        CanvasNodeAction.copy,
                        Icons.copy_all_outlined,
                        'Дублировать как стикер',
                      ),
                      SizedBox(width: spacing),
                      SizedBox(
                        height: 24,
                        child: VerticalDivider(width: 1, color: theme.border),
                      ),
                      SizedBox(width: spacing),
                      action(
                        CanvasNodeAction.delete,
                        Icons.delete_outline,
                        'Убрать с канваса',
                      ),
                      actionGap,
                      action(
                        CanvasNodeAction.more,
                        Icons.more_horiz,
                        'Другие действия',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
