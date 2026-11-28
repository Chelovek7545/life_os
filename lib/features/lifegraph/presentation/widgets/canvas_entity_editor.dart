import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart' show GraphPresentedForm;
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';

class CanvasEntityEditorPanel extends StatelessWidget {
  const CanvasEntityEditorPanel({
    super.key,
    required this.form,
    required this.onClose,
  });

  final GraphPresentedForm? form;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 660;
      final short = constraints.maxHeight < 450;
      final smallHeight = constraints.maxHeight < 260;
      final width = wide
          ? 460.0
          : (constraints.maxWidth - 72).clamp(0.0, 460.0);
      final editor = form;
      return ClipRect(
        child: Padding(
          padding: EdgeInsets.only(
            top: smallHeight ? AppSpacing.sm : (wide ? 64 : 104),
            bottom: smallHeight || (wide && !short) ? AppSpacing.lg : 64,
            right: wide ? 64 : AppSpacing.sm,
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: width,
              height: double.infinity,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => SlideTransition(
                  position: Tween(
                    begin: const Offset(1.2, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [
                    for (final child in previous)
                      IgnorePointer(child: ExcludeFocus(child: child)),
                    ?current,
                  ],
                ),
                child: editor == null
                    ? null
                    : Listener(
                        key: ObjectKey(editor),
                        behavior: HitTestBehavior.opaque,
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape):
                                onClose,
                          },
                          child: GraphNodeEditLayout(
                            onClose: onClose,
                            builder: (_, content) => _CanvasEntityEditor(
                              content: content,
                              compact: !wide,
                            ),
                            child: Builder(
                              builder: (context) => editor(context, onClose),
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _CanvasEntityEditor extends StatelessWidget {
  const _CanvasEntityEditor({required this.content, required this.compact});

  final GraphNodeEditContent content;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final padding = compact ? AppSpacing.lg : AppSpacing.xl;
    final theme = Theme.of(context);
    OutlineInputBorder border(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: color, width: width),
        );
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppColors.borderGlass),
      ),
      child: Theme(
        data: theme.copyWith(
          inputDecorationTheme: InputDecorationThemeData(
            filled: true,
            fillColor: AppColors.inputGlass,
            contentPadding: const EdgeInsets.all(AppSpacing.lg),
            labelStyle: AppTypography.bodySm,
            hintStyle: AppTypography.bodySm,
            enabledBorder: border(AppColors.inputBorderGlass),
            border: border(AppColors.inputBorderGlass),
            focusedBorder: border(AppColors.primaryContainer, width: 1.5),
          ),
          textTheme: theme.textTheme.copyWith(
            bodyLarge: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurface,
            ),
            bodyMedium: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          colorScheme: theme.colorScheme.copyWith(
            primary: AppColors.primary,
            onSurface: AppColors.onSurface,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showIcon =
                constraints.maxWidth >= 390 &&
                MediaQuery.textScalerOf(context).scale(24) <= 30;
            final buttonText = AppTypography.bodySm.copyWith(
              fontWeight: FontWeight.w600,
            );
            final header = Padding(
              padding: EdgeInsets.all(padding),
              child: Row(
                children: [
                  if (showIcon) ...[
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(
                          alpha: .12,
                        ),
                        border: Border.all(
                          color: AppColors.primaryContainer.withValues(
                            alpha: .22,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Icon(
                        content.icon,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        content.title,
                        style: AppTypography.headlineLgMobile.copyWith(
                          fontSize: constraints.maxWidth < 320 ? 20 : 24,
                          color: AppColors.onSurface,
                          fontFamilyFallback: const ['Inter'],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'Закрыть редактор',
                    onPressed: content.onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surfaceBright,
                      foregroundColor: AppColors.onSurfaceVariant,
                      minimumSize: const Size.square(44),
                      tapTargetSize: MaterialTapTargetSize.padded,
                    ),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
            );
            final fields = Padding(
              padding: EdgeInsets.all(padding),
              child: content.fields,
            );
            final footer = DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                border: Border(top: BorderSide(color: AppColors.borderGlass)),
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: AppSpacing.md,
                  children: [
                    if (content.error case final error?)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          error,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.tertiary,
                          ),
                        ),
                      ),
                    OverflowBar(
                      alignment: MainAxisAlignment.end,
                      spacing: AppSpacing.sm,
                      overflowSpacing: AppSpacing.sm,
                      children: [
                        TextButton(
                          onPressed: content.onClose,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.onSurface,
                            backgroundColor: AppColors.surfaceBright,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            textStyle: buttonText,
                            shape: const StadiumBorder(),
                          ),
                          child: const Text('Отмена'),
                        ),
                        FilledButton(
                          onPressed: content.onSave,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            foregroundColor: AppColors.surfaceDim,
                            minimumSize: const Size(0, 48),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.sm,
                            ),
                            textStyle: buttonText,
                            shape: const StadiumBorder(),
                          ),
                          child: content.saving
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    semanticsLabel: 'Сохранение',
                                  ),
                                )
                              : const Text('Сохранить'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
            final divider = Divider(height: 1, color: AppColors.borderGlass);
            if (constraints.maxHeight < 320 ||
                (constraints.maxHeight < 460 &&
                    MediaQuery.textScalerOf(context).scale(16) > 24)) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [header, divider, fields, footer],
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                divider,
                Expanded(child: SingleChildScrollView(child: fields)),
                footer,
              ],
            );
          },
        ),
      ),
    );
  }
}
