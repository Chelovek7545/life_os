import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart' show CanvasSummary;

import 'canvas_editor_chrome.dart' show CanvasBreadcrumb;
import 'canvas_visuals.dart';

class CanvasSwitchMenu extends StatelessWidget {
  const CanvasSwitchMenu({
    super.key,
    required this.title,
    required this.compact,
    required this.canvases,
    required this.currentId,
    required this.controller,
    required this.onSelected,
  });

  final String title;
  final bool compact;
  final List<CanvasSummary> canvases;
  final String? currentId;
  final MenuController controller;
  final ValueChanged<CanvasSummary> onSelected;

  @override
  Widget build(BuildContext context) => RawMenuAnchor(
    controller: controller,
    consumeOutsideTaps: false,
    useRootOverlay: true,
    builder: (_, menu, _) => CanvasBreadcrumb(
      title: title,
      compact: compact,
      onPressed: canvases.isEmpty
          ? null
          : () => menu.isOpen ? menu.close() : menu.open(),
    ),
    overlayBuilder: _buildOverlay,
  );

  Widget _buildOverlay(BuildContext context, RawMenuOverlayInfo info) {
    final safe = MediaQueryData.fromView(View.of(context)).padding;
    final start = safe.left + AppMargins.lg;
    final right = math.max(
      start,
      info.overlaySize.width - safe.right - AppMargins.lg,
    );
    final minWidth = math.min(260.0, right - start);
    final left = info.anchorRect.left.clamp(start, right - minWidth);
    final bottom = math.max(
      0.0,
      info.overlaySize.height - safe.bottom - AppMargins.lg,
    );
    final top = math.min(info.anchorRect.bottom + AppSpacing.sm, bottom);
    final width = math.min(416.0, right - left);
    final padding = width >= 360 ? AppSpacing.lg : AppSpacing.md;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: bottom - top),
            child: TapRegion(
              groupId: info.tapRegionGroupId,
              behavior: HitTestBehavior.opaque,
              onTapOutside: (_) => controller.close(),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      controller.close,
                },
                child: FocusScope(
                  autofocus: true,
                  child: Material(
                    key: const ValueKey('canvas-switch-surface'),
                    color: AppColors.surface,
                    surfaceTintColor: Colors.transparent,
                    elevation: 8,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(color: AppColors.borderGlass),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: AppSpacing.md,
                        children: [
                          Row(
                            spacing: AppSpacing.sm,
                            children: [
                              const CanvasBadge(size: 34),
                              Expanded(
                                child: Semantics(
                                  header: true,
                                  child: Text(
                                    'Канвасы',
                                    style: AppTypography.headlineLgMobile
                                        .copyWith(
                                          fontSize: 20,
                                          color: AppColors.onSurface,
                                          fontFamilyFallback: const ['Inter'],
                                        ),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Закрыть',
                                onPressed: controller.close,
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.surfaceBright,
                                  foregroundColor: AppColors.onSurfaceVariant,
                                  minimumSize: const Size.square(36),
                                  tapTargetSize: MaterialTapTargetSize.padded,
                                  shape: const CircleBorder(),
                                ),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                          Flexible(
                            child: ListView.separated(
                              primary: false,
                              shrinkWrap: true,
                              itemCount: canvases.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppSpacing.sm),
                              itemBuilder: (context, index) {
                                final canvas = canvases[index];
                                return _CanvasSwitchOption(
                                  canvas: canvas,
                                  current: canvas.id == currentId,
                                  onSelected: () {
                                    controller.close();
                                    onSelected(canvas);
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CanvasSwitchOption extends StatelessWidget {
  const _CanvasSwitchOption({
    required this.canvas,
    required this.current,
    required this.onSelected,
  });

  final CanvasSummary canvas;
  final bool current;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary.withValues(alpha: .28);
    final detailStyle = AppTypography.bodySm.copyWith(fontSize: 12);
    return Semantics(
      selected: current,
      child: OutlinedButton(
        onPressed: current ? null : onSelected,
        style: ButtonStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.md)),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
            ),
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => BorderSide(
              color: states.contains(WidgetState.focused)
                  ? AppColors.primaryContainer
                  : current || states.contains(WidgetState.hovered)
                  ? accent
                  : AppColors.borderGlass,
            ),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                current ||
                    states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
                ? AppColors.surfaceBright
                : AppColors.surfaceContainerLow,
          ),
          overlayColor: WidgetStatePropertyAll(
            AppColors.primary.withValues(alpha: .08),
          ),
          animationDuration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
        ),
        child: Row(
          spacing: AppSpacing.sm,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: current
                    ? AppColors.primaryContainer.withValues(alpha: .12)
                    : AppColors.surfaceBright,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: current ? accent : AppColors.borderGlass,
                ),
              ),
              child: Icon(
                canvasKindIcon(canvas.sourceKind ?? ''),
                size: 18,
                color: current ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppSpacing.xs,
                children: [
                  Text(
                    canvas.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  if (current)
                    Text('Текущий канвас', style: detailStyle)
                  else
                    Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        Text(
                          canvasCardCount(canvas.cardCount),
                          style: detailStyle,
                        ),
                        if (canvas.updatedAt case final date?)
                          Text(formatDate(date.toLocal()), style: detailStyle),
                      ],
                    ),
                ],
              ),
            ),
            Icon(
              current ? Icons.check_rounded : Icons.chevron_right_rounded,
              size: 18,
              color: current ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
