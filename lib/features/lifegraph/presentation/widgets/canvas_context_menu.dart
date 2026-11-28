import 'dart:math' as math;
import 'dart:ui' show ImageFilter, SemanticsRole, clampDouble;

import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/features/settings/settings_service.dart';

const _menuAnimation = Duration(milliseconds: 160);
const _menuItemHeight = 40.0;

class _CanvasMenuBackdrop extends StatelessWidget {
  const _CanvasMenuBackdrop({required this.child});

  static final _blur = ImageFilter.blur(sigmaX: 8, sigmaY: 8);
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: SettingsService.hasBlur,
    builder: (context, blur, child) => BackdropFilter(
      filter: _blur,
      enabled: blur,
      child: Material(
        color: blur
            ? AppColors.surface.withValues(alpha: .60)
            : AppColors.surfaceContainer.withValues(alpha: .90),
        child: child,
      ),
    ),
    child: child,
  );
}

class CanvasContextOption<T> {
  const CanvasContextOption(
    this.value,
    this.label,
    this.icon, {
    this.accented = false,
    this.destructive = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final bool accented;
  final bool destructive;
}

Future<T?> showCanvasContextMenu<T>(
  BuildContext context,
  Rect anchor, {
  required String title,
  required List<CanvasContextOption<T>> actions,
}) {
  if (actions.isEmpty) return Future.value();
  final navigator = Navigator.of(context);
  final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
  final localAnchor = Rect.fromPoints(
    overlay.globalToLocal(anchor.topLeft),
    overlay.globalToLocal(anchor.bottomRight),
  );
  final themes = InheritedTheme.capture(from: context, to: navigator.context);

  return showGeneralDialog<T>(
    context: context,
    useRootNavigator: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    transitionDuration: Duration.zero,
    pageBuilder: (context, _, _) => themes.wrap(
      CustomSingleChildLayout(
        delegate: _CanvasMenuLayout(
          anchor: localAnchor,
          padding:
              MediaQuery.paddingOf(context) +
              const EdgeInsets.all(AppSpacing.sm),
          direction: Directionality.of(context),
        ),
        child: Semantics(
          role: SemanticsRole.menu,
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: Material(
            color: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.black54,
            elevation: 8,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              side: BorderSide(color: AppColors.borderGlass),
            ),
            // Scroll-edge masks isolate their contents from the canvas.
            child: _CanvasMenuBackdrop(
              child: SingleChildScrollView(
                primary: false,
                child: _CanvasMenuBody(title: title, actions: actions),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _CanvasMenuLayout extends SingleChildLayoutDelegate {
  const _CanvasMenuLayout({
    required this.anchor,
    required this.padding,
    required this.direction,
  });

  final Rect anchor;
  final EdgeInsets padding;
  final TextDirection direction;

  double get _below => anchor.bottom + AppSpacing.xs;
  double get _above => anchor.top - AppSpacing.xs;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final width = math.min(
      272.0,
      math.max(0.0, constraints.maxWidth - padding.horizontal),
    );
    final safeHeight = constraints.maxHeight - padding.vertical;
    final height = anchor.isEmpty
        ? safeHeight
        : math.min(
            safeHeight,
            math.max(
              _above - padding.top,
              constraints.maxHeight - padding.bottom - _below,
            ),
          );
    return BoxConstraints(
      minWidth: math.min(216.0, width),
      maxWidth: width,
      maxHeight: math.max(0.0, height),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = padding.left;
    final right = size.width - padding.right;
    final bottom = size.height - padding.bottom;
    final maxLeft = math.max(left, right - childSize.width);
    final maxTop = math.max(padding.top, bottom - childSize.height);
    if (!anchor.isEmpty) {
      final x = direction == TextDirection.rtl
          ? anchor.left
          : anchor.right - childSize.width;
      final y = _below <= maxTop ? _below : _above - childSize.height;
      return Offset(
        clampDouble(x, left, maxLeft),
        clampDouble(y, padding.top, maxTop),
      );
    }
    final point = anchor.topLeft;
    final before = point.dx - left;
    final after = right - point.dx;
    final growLeft =
        before > after || (before == after && direction == TextDirection.rtl);
    return Offset(
      clampDouble(
        growLeft ? point.dx - childSize.width : point.dx,
        left,
        maxLeft,
      ),
      clampDouble(point.dy, padding.top, maxTop),
    );
  }

  @override
  bool shouldRelayout(_CanvasMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor ||
      padding != oldDelegate.padding ||
      direction != oldDelegate.direction;
}

class _CanvasMenuBody<T> extends StatelessWidget {
  const _CanvasMenuBody({required this.title, required this.actions});

  final String title;
  final List<CanvasContextOption<T>> actions;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return IntrinsicWidth(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Divider(
              height: 1,
              indent: AppSpacing.md,
              endIndent: AppSpacing.md,
              color: AppColors.borderGlass,
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final action in actions)
              PopupMenuItem<T>(
                value: action.value,
                height: _menuItemHeight,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  spacing: AppSpacing.sm,
                  children: [
                    Icon(
                      action.icon,
                      size: 18,
                      color: action.destructive
                          ? error
                          : action.accented
                          ? AppColors.primary
                          : AppColors.onSurfaceVariant,
                    ),
                    Expanded(
                      child: Text(
                        action.label,
                        style: AppTypography.bodySm.copyWith(
                          color: action.destructive
                              ? error
                              : AppColors.onSurface,
                          fontWeight: action.accented ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

enum CanvasNodeAction { edit, link, copy, delete, more }

typedef CanvasNodeMenuSelection = ({CanvasNodeAction action, Rect button});

Future<CanvasNodeMenuSelection?> showCanvasNodeActions(
  BuildContext context,
  Rect bounds, {
  required bool canEdit,
  required bool canLink,
}) {
  final overlay =
      Navigator.of(
            context,
            rootNavigator: true,
          ).overlay!.context.findRenderObject()!
          as RenderBox;
  final anchor = Rect.fromPoints(
    overlay.globalToLocal(bounds.topLeft),
    overlay.globalToLocal(bounds.bottomRight),
  );
  final safe = MediaQueryData.fromView(View.of(context)).padding;
  final error = Theme.of(context).colorScheme.error;
  return showGeneralDialog<CanvasNodeMenuSelection>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Закрыть меню карточки',
    barrierColor: Colors.transparent,
    transitionDuration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _menuAnimation,
    // Fading the route puts its contents in a separate buffer. Keep the
    // backdrop on the canvas layer and fade only the menu controls.
    transitionBuilder: (_, _, _, child) => child,
    pageBuilder: (context, animation, _) => SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rect = anchor.shift(Offset(-safe.left, -safe.top));
          const margin = AppSpacing.sm;
          const height = 56 + _NodeMenuShape.tailHeight;
          final width = math.min(
            264.0,
            math.max(1.0, constraints.maxWidth - 2 * margin),
          );
          final left = clampDouble(
            rect.center.dx - width / 2,
            margin,
            math.max(margin, constraints.maxWidth - width - margin),
          );
          final above = rect.top >= height + 2 * margin;
          final top = clampDouble(
            above ? rect.top - height - margin : rect.bottom + margin,
            margin,
            math.max(margin, constraints.maxHeight - height - margin),
          );
          final tailInset = math.min(width / 2, AppRadius.xl + margin);
          final tailX = clampDouble(
            rect.center.dx - left,
            tailInset,
            width - tailInset,
          );
          final shape = _NodeMenuShape(above: above, tailX: tailX);

          Widget action(
            CanvasNodeAction value,
            IconData icon,
            String label, {
            Color color = AppColors.onSurfaceVariant,
            bool enabled = true,
          }) => Expanded(
            child: Builder(
              builder: (buttonContext) => IconButton(
                onPressed: enabled
                    ? () {
                        final button =
                            buttonContext.findRenderObject()! as RenderBox;
                        Navigator.of(context).pop<CanvasNodeMenuSelection>((
                          action: value,
                          button:
                              button.localToGlobal(Offset.zero) & button.size,
                        ));
                      }
                    : null,
                tooltip: label,
                icon: Icon(icon, size: 20),
                style: ButtonStyle(
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled)
                        ? AppColors.onSurfaceVariant.withValues(alpha: .38)
                        : color,
                  ),
                  backgroundColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  overlayColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.pressed)) {
                      return color.withValues(alpha: .20);
                    }
                    if (states.contains(WidgetState.hovered) ||
                        states.contains(WidgetState.focused)) {
                      return color.withValues(alpha: .12);
                    }
                    return Colors.transparent;
                  }),
                  side: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.focused)
                        ? const BorderSide(color: AppColors.primaryContainer)
                        : BorderSide.none,
                  ),
                  shape: const WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(
                        Radius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          );

          return Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: width,
                height: height,
                child: CustomPaint(
                  key: const ValueKey('canvas-node-actions'),
                  painter: _NodeMenuOutline(shape, shadow: true),
                  foregroundPainter: _NodeMenuOutline(shape),
                  child: ClipPath(
                    clipper: shape,
                    clipBehavior: Clip.antiAlias,
                    child: _CanvasMenuBackdrop(
                      child: FadeTransition(
                        opacity: animation,
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.xs,
                            AppSpacing.xs +
                                (above ? 0 : _NodeMenuShape.tailHeight),
                            AppSpacing.xs,
                            AppSpacing.xs +
                                (above ? _NodeMenuShape.tailHeight : 0),
                          ),
                          child: Row(
                            spacing: AppSpacing.xs,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              action(
                                CanvasNodeAction.edit,
                                Icons.edit_outlined,
                                'Редактировать карточку',
                                color: AppColors.primary,
                                enabled: canEdit,
                              ),
                              action(
                                CanvasNodeAction.link,
                                Icons.link_outlined,
                                'Связать с карточкой',
                                enabled: canLink,
                              ),
                              action(
                                CanvasNodeAction.copy,
                                Icons.content_copy_outlined,
                                'Дублировать как стикер',
                              ),
                              Center(
                                child: SizedBox(
                                  width: 1,
                                  height: 24,
                                  child: ColoredBox(
                                    color: AppColors.borderGlass,
                                  ),
                                ),
                              ),
                              action(
                                CanvasNodeAction.delete,
                                Icons.delete_outline,
                                'Убрать с канваса',
                                color: error,
                              ),
                              action(
                                CanvasNodeAction.more,
                                Icons.more_horiz,
                                'Другие действия',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

class _NodeMenuShape extends CustomClipper<Path> {
  const _NodeMenuShape({required this.above, required this.tailX});

  static const tailHeight = 7.0;
  final bool above;
  final double tailX;

  @override
  Path getClip(Size size) {
    final body = Rect.fromLTRB(
      .5,
      above ? .5 : tailHeight + .5,
      size.width - .5,
      size.height - (above ? tailHeight : 0) - .5,
    );
    final baseY = above ? body.bottom - 1 : body.top + 1;
    final halfTail = math.min(7.0, body.width / 2);
    return Path.combine(
      PathOperation.union,
      Path()..addRRect(
        RRect.fromRectAndRadius(body, const Radius.circular(AppRadius.xl)),
      ),
      Path()
        ..moveTo(tailX - halfTail, baseY)
        ..lineTo(tailX, above ? size.height - .5 : .5)
        ..lineTo(tailX + halfTail, baseY)
        ..close(),
    );
  }

  @override
  bool shouldReclip(_NodeMenuShape oldClipper) =>
      above != oldClipper.above || tailX != oldClipper.tailX;
}

class _NodeMenuOutline extends CustomPainter {
  const _NodeMenuOutline(this.shape, {this.shadow = false});

  final _NodeMenuShape shape;
  final bool shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final outline = shape.getClip(size);
    if (shadow) {
      canvas.drawShadow(outline, Colors.black54, 8, false);
      return;
    }
    canvas.drawPath(
      outline,
      Paint()
        ..color = AppColors.borderGlass
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_NodeMenuOutline oldDelegate) =>
      shadow != oldDelegate.shadow || shape.shouldReclip(oldDelegate.shape);
}
