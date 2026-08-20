import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

import 'task_form_content.dart';

typedef OnCancel = void Function();

/// Форма задачи в коллапсируемой шторке.
///
/// Состоит из двух переиспользуемых частей:
/// - [CollapsibleSheet] — сама шторка (перетаскивание, прилипание, анимация);
/// - [TaskFormContent] — содержимое формы (поля задачи).
class CollapsibleTaskForm extends StatefulWidget {
  const CollapsibleTaskForm({
    super.key,
    required this.task,
    required this.height,
    required this.onSubmit,
    required this.onCancel,
    required this.projects,
    required this.isEditMode,
    required this.onDelete,
    required this.onFormVisibilityChanged,
    required this.onChanged,
    this.forceExpanded = false,
  });

  final OnTaskSubmit onSubmit;
  final Function(String) onDelete;
  final OnCancel onCancel;
  final Stream<List<Project>> projects;
  final Task task;
  final bool isEditMode;
  final double height;
  final ValueChanged<bool>? onFormVisibilityChanged;
  final bool forceExpanded;

  //Нужно при чтобы хранить значения при изменении ориентации
  final ValueChanged<Task>? onChanged;

  @override
  State<CollapsibleTaskForm> createState() => _CollapsibleTaskFormState();
}

class _CollapsibleTaskFormState extends State<CollapsibleTaskForm> {
  final GlobalKey<TaskFormContentState> _formKey =
      GlobalKey<TaskFormContentState>();

  void _save() => _formKey.currentState?.submit();

  @override
  Widget build(BuildContext context) {
    return CollapsibleSheet(
      snapPoints: [60, 190, widget.height],
      forceExpanded: widget.forceExpanded,
      // Стартуем сразу в развернутом виде, если это редактирование
      initialHeight: widget.isEditMode ? widget.height : null,
      onVisibilityChanged: widget.onFormVisibilityChanged,
      header: widget.forceExpanded
          ? _PanelHeader(
              isEditMode: widget.isEditMode,
              onCancel: widget.onCancel,
              onSave: _save,
            )
          : _DragHeader(
              isEditMode: widget.isEditMode,
              onCancel: widget.onCancel,
              onSave: _save,
            ),
      bodyBuilder: (progress, snapIndex) => TaskFormContent(
        key: _formKey,
        task: widget.task,
        projects: widget.projects,
        isEditMode: widget.isEditMode,
        onSubmit: widget.onSubmit,
        onDelete: widget.onDelete,
        onChanged: widget.onChanged,
        // Двухстадийная анимация формы: стадия 1 — минимум -> середина,
        // стадия 2 — середина -> максимум.
        midProgress: snapIndex == 0 ? progress : 1.0,
        maxProgress: snapIndex == 1 ? progress : (snapIndex > 1 ? 1.0 : 0.0),
      ),
    );
  }
}

/// Шапка перетаскиваемой шторки: хэндл-полоска, заголовок и кнопки.
class _DragHeader extends StatelessWidget {
  const _DragHeader({
    required this.isEditMode,
    required this.onCancel,
    required this.onSave,
  });

  final bool isEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60, // Должно совпадать с CollapsibleSheet.minHeight
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.transparent, // Делаем всю область хэндла кликабельной
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: onCancel,
                icon: Icon(Icons.close),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Традиционная полоска-индикатор
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isEditMode ? 'Edit task' : 'New task',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: AppButtonStyles.saveButton,
                onPressed: onSave,
                child: Text(
                  "Save",
                  style: AppTypography.bodySm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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

/// Шапка для всегда развёрнутой панели (без перетаскивания).
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({
    required this.isEditMode,
    required this.onCancel,
    required this.onSave,
  });

  final bool isEditMode;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderGlass)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isEditMode ? 'Edit task' : 'New task',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: AppButtonStyles.saveButton,
            onPressed: onSave,
            child: Text(
              "Save",
              style: AppTypography.bodySm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
