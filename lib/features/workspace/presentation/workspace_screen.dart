import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/ui/app_dropdown_menu.dart';
import 'package:life_os/core/ui/glassPopUpMenuButton.dart';
import '../workspace_controller.dart';
import '../workspace_layout.dart';
import '../workspace_geometry.dart';

class WorkspaceEditor {
  const WorkspaceEditor({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });
  final String id;
  final String label;
  final IconData icon;
  final Widget Function(BuildContext, String paneId) builder;
}

class WorkspaceScreen extends StatelessWidget {
  const WorkspaceScreen({
    super.key,
    required this.controller,
    required this.editors,
  });
  final WorkspaceController controller;
  final List<WorkspaceEditor> editors;
  static const _gap = WorkspaceGeometry.gap;
  static const _paneSize = WorkspaceGeometry.paneSize;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final panes = controller.layout.root.panes.toList();
      final byId = {for (final editor in editors) editor.id: editor};
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.dashboard_customize_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      key: const ValueKey('workspace-area-selector'),
                      value: controller.selectedId,
                      isExpanded: true,
                      items: [
                        for (var i = 0; i < panes.length; i++)
                          DropdownMenuItem(
                            value: panes[i].id,
                            child: Text(
                              'Область ${i + 1} · ${byId[panes[i].editorId]!.label}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (id) {
                        if (id == null) return;
                        if (controller.maximizedId != null &&
                            controller.maximizedId != id) {
                          controller.toggleMaximize(id);
                        } else {
                          controller.select(id);
                        }
                      },
                    ),
                  ),
                ),
                TextButton.icon(
                  key: const ValueKey('workspace-edit-toggle'),
                  onPressed: () => controller.setEditing(!controller.isEditing),
                  icon: Icon(controller.isEditing ? Icons.done : Icons.edit_outlined, size: 18),
                  label: Text(controller.isEditing ? 'Готово' : 'Изменить'),
                ),
                if (controller.isEditing) Tooltip(
                  message:
                      'Выберите содержимое в заголовке области. В меню ⋮ можно разделить область или закрыть её. Границы можно перетаскивать.',
                  triggerMode: TooltipTriggerMode.tap,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(Icons.help_outline, size: 20),
                  ),
                ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bounds = Offset.zero & constraints.biggest;
                  final geometry = WorkspaceGeometry(
                    controller.layout.root,
                    bounds.size,
                  );
                  final compact = !geometry.fits;
                  final solo =
                      controller.maximizedId ??
                      (compact ? controller.selectedId : null);
                  final areas = geometry.panes;
                  final dividers = <Widget>[];

                  if (solo == null) {
                    for (final divider in geometry.splits.values) {
                      final split = divider.split;
                      final horizontal = divider.horizontal;
                      void resize(DragUpdateDetails details) {
                        final delta = horizontal
                            ? details.delta.dx
                            : details.delta.dy;
                        controller.moveDivider(split.id, delta, bounds.size);
                      }

                      dividers.add(
                        Positioned.fromRect(
                          key: ValueKey('workspace-divider:${split.id}'),
                          rect: divider.divider,
                          child: Semantics(
                            label: 'Размер областей',
                            onIncrease: () => controller.moveDivider(
                              split.id, divider.extent * .05, bounds.size,
                            ),
                            onDecrease: () => controller.moveDivider(
                              split.id, -divider.extent * .05, bounds.size,
                            ),
                            child: MouseRegion(
                              cursor: horizontal
                                  ? SystemMouseCursors.resizeLeftRight
                                  : SystemMouseCursors.resizeUpDown,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onHorizontalDragUpdate: horizontal ? resize : null,
                                onVerticalDragUpdate: horizontal ? null : resize,
                                child: Center(
                                  child: Container(
                                    width: horizontal ? 2 : 32,
                                    height: horizontal ? 32 : 2,
                                    color: Theme.of(context).colorScheme.outlineVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                  }

                  return Stack(
                    children: [
                      // All panes retain the same parent and identity during layout edits.
                      for (final pane in panes)
                        Positioned.fromRect(
                          key: ValueKey('workspace-pane:${pane.id}'),
                          rect: solo == null ? areas[pane.id]! : bounds,
                          child: Offstage(
                            offstage: solo != null && solo != pane.id,
                            child: TickerMode(
                              enabled: solo == null || solo == pane.id,
                              child: _area(
                                context,
                                pane,
                                byId,
                                solo == null ? areas[pane.id]! : bounds,
                                panes.length,
                              ),
                            ),
                          ),
                        ),
                      ...dividers,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _area(
    BuildContext context,
    WorkspacePane pane,
    Map<String, WorkspaceEditor> editors,
    Rect rect,
    int count,
  ) {
    final colors = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      primary: false,
      physics: rect.height >= _paneSize.height
          ? const NeverScrollableScrollPhysics()
          : null,
      child: SizedBox(
        height: math.max(rect.height, _paneSize.height),
        child: Listener(
          onPointerDown: (_) => controller.select(pane.id),
          child: Container(
            padding: EdgeInsets.all(AppSpacing.md),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              children: [
                if (controller.isEditing) SizedBox(
                  height: 44,
                  child: Container(
                    padding: EdgeInsets.all(2.0),
                    color: controller.selectedId == pane.id
                        ? colors.surfaceContainerLow
                        : colors.surfaceDim,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 200,
                          child: AppDropdownMenu<String>(
                            key: ValueKey('workspace-editor:${pane.id}'),
                            initialSelection: pane.editorId,
                            selectOnly: true,
                            width: null,
                            expandedInsets: EdgeInsets.zero,
                            leadingIcon: Icon(
                              editors[pane.editorId]!.icon,
                              size: 18,
                            ),
                            inputDecorationTheme: AppButtonStyles
                                .baseInputDecoration
                                .copyWith(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  constraints: const BoxConstraints(
                                    maxHeight: 40,
                                  ),
                                ),
                            dropdownMenuEntries: [
                              for (final editor in editors.values)
                                DropdownMenuEntry(
                                  value: editor.id,
                                  label: editor.label,
                                  style: AppButtonStyles.baseButtonStyle.copyWith(
                                    padding: WidgetStatePropertyAll(EdgeInsets.all(AppSpacing.md))
                                  ),
                                  leadingIcon: Icon(editor.icon, size: 18),
                                  labelWidget: Text(
                                    editor.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],

                            onSelected: (editor) {
                              if (editor != null) {
                                controller.changeEditor(pane.id, editor);
                              }
                            },
                          ),
                        ),
                        Spacer(),
                        GlassPopUpMenuButton(
                          key: ValueKey('workspace-menu:${pane.id}'),
                          tooltip: 'Действия области',
                          overflowActions: [
                            PopUpMenuAction(
                              icon: Icons.vertical_split_outlined,
                              label: 'Разделить горизонтально',
                              onTap: () => controller.split(
                                pane.id,
                                WorkspaceAxis.horizontal,
                              ),
                              enabled:
                                  count < WorkspaceLayout.maxPanes &&
                                  rect.width >= _paneSize.width * 2 + _gap,
                            ),
                            PopUpMenuAction(
                              icon: Icons.horizontal_split_outlined,
                              label: 'Разделить вертикально',
                              onTap: () => controller.split(
                                pane.id,
                                WorkspaceAxis.vertical,
                              ),
                              enabled:
                                  count < WorkspaceLayout.maxPanes &&
                                  rect.height >= _paneSize.height * 2 + _gap,
                            ),
                            PopUpMenuAction(
                              icon: controller.maximizedId == pane.id
                                  ? Icons.fullscreen_exit
                                  : Icons.fullscreen,
                              onTap: () => controller.toggleMaximize(pane.id),
                              label: controller.maximizedId == pane.id
                                  ? 'Вернуть раскладку'
                                  : 'Развернуть область',
                            ),
                            PopUpMenuAction(
                              icon: Icons.close,
                              label: 'Закрыть область',
                              onTap: () => controller.closePane(pane.id),
                              enabled: count > 1,
                            ),
                          ],
                        ),
                        SizedBox(width: 2,)
                      ],
                    ),
                  ),
                ),
                Expanded(
                  key: ValueKey('workspace-content:${pane.id}'),
                  child: KeyedSubtree(
                    key: ValueKey(pane.editorId),
                    child: editors[pane.editorId]!.builder(context, pane.id),
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


