import 'package:flutter/material.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

import 'canvas_visuals.dart';

enum CanvasAddAction { existingObject, note }

Future<Object?> showCanvasAddDialog(
  BuildContext context, {
  required List<GraphNodeEditor> editors,
}) => showDialog<Object>(
  context: context,
  builder: (_) => _CanvasAddDialog(editors: editors),
);

class _CanvasAddDialog extends StatelessWidget {
  const _CanvasAddDialog({required this.editors});

  final List<GraphNodeEditor> editors;

  @override
  Widget build(BuildContext context) {
    final margin = MediaQuery.sizeOf(context).width >= 640
        ? AppMargins.xl
        : AppMargins.lg;
    final options = <_CanvasAddOption>[
      for (final editor in editors)
        _CanvasAddOption(
          value: editor,
          icon: canvasKindIcon(editor.kind),
          title: editor.standaloneForm!.label,
          detail: switch (editor.kind) {
            'task' => 'Появится в задачах',
            'project' => 'Появится в проектах',
            _ => null,
          },
          accented: true,
        ),
      const _CanvasAddOption(
        value: CanvasAddAction.existingObject,
        icon: Icons.dashboard_customize_outlined,
        title: 'Добавить из списка',
        detail: 'Сфера, цель, проект или задача',
      ),
      const _CanvasAddOption(
        value: CanvasAddAction.note,
        icon: Icons.note_add_outlined,
        title: 'Добавить заметку',
        detail: 'Стикер или Markdown',
      ),
    ];
    return Dialog(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 16,
      shadowColor: Colors.black54,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.borderGlass),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: margin,
        vertical: AppMargins.lg,
      ),
      child: SizedBox(
        width: 640,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 540 ||
                MediaQuery.textScalerOf(context).scale(16) > 20;
            final padding = compact ? AppSpacing.lg : AppSpacing.xl;
            return FocusTraversalGroup(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const _OptionIcon(
                          Icons.add_rounded,
                          accented: true,
                          size: 44,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              'Добавить на канвас',
                              style: AppTypography.headlineLgMobile.copyWith(
                                color: AppColors.onSurface,
                                fontFamilyFallback: const ['Inter'],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        IconButton(
                          tooltip: 'Закрыть',
                          onPressed: () => Navigator.of(context).pop(),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.surfaceBright,
                            foregroundColor: AppColors.onSurfaceVariant,
                            minimumSize: const Size.square(44),
                            tapTargetSize: MaterialTapTargetSize.padded,
                            shape: const CircleBorder(),
                          ),
                          icon: const Icon(Icons.close_rounded, size: 20),
                        ),
                      ],
                    ),
                    SizedBox(height: padding),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: compact ? AppSpacing.sm : AppSpacing.md,
                          children: compact
                              ? options
                              : [
                                  for (var i = 0; i < options.length; i += 2)
                                    IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(child: options[i]),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: i + 1 < options.length
                                                ? options[i + 1]
                                                : const SizedBox(),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CanvasAddOption extends StatelessWidget {
  const _CanvasAddOption({
    required this.value,
    required this.icon,
    required this.title,
    this.detail,
    this.accented = false,
  });

  final Object value;
  final IconData icon;
  final String title;
  final String? detail;
  final bool accented;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () => Navigator.of(context).pop(value),
    style: ButtonStyle(
      alignment: Alignment.centerLeft,
      padding: const WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.lg)),
      minimumSize: const WidgetStatePropertyAll(Size(0, 80)),
      shape: const WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.xl)),
        ),
      ),
      side: WidgetStateProperty.resolveWith(
        (states) => BorderSide(
          color: states.contains(WidgetState.focused)
              ? AppColors.primaryContainer
              : states.contains(WidgetState.hovered)
              ? AppColors.primary.withValues(alpha: .34)
              : AppColors.borderGlass,
        ),
      ),
      backgroundColor: WidgetStateProperty.resolveWith(
        (states) =>
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
      children: [
        _OptionIcon(icon, accented: accented),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              if (detail case final description?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(description, style: AppTypography.bodySm),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        const Icon(
          Icons.chevron_right_rounded,
          size: 18,
          color: AppColors.onSurfaceVariant,
        ),
      ],
    ),
  );
}

class _OptionIcon extends StatelessWidget {
  const _OptionIcon(this.icon, {required this.accented, this.size = 40});
  final IconData icon;
  final bool accented;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: accented
          ? AppColors.primaryContainer.withValues(alpha: .12)
          : AppColors.surfaceBright,
      border: Border.all(
        color: accented
            ? AppColors.primaryContainer.withValues(alpha: .22)
            : AppColors.borderGlass,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
    ),
    child: Icon(
      icon,
      size: 21,
      color: accented ? AppColors.primary : AppColors.onSurfaceVariant,
    ),
  );
}
