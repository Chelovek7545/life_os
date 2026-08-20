import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

/// Компактная форма быстрого создания задачи: название + проект.
///
/// Появляется рядом с гостем, который пользователь выделил на таймлайне.
class MiniTaskForm extends StatefulWidget {
  const MiniTaskForm({
    super.key,
    required this.start,
    required this.end,
    required this.projects,
    required this.onSubmit,
    required this.onCancel,
    this.width = 260,
  });

  final DateTime start;
  final DateTime end;
  final Stream<List<Project>>? projects;
  final ValueChanged<Task> onSubmit;
  final VoidCallback onCancel;
  final double width;

  @override
  State<MiniTaskForm> createState() => _MiniTaskFormState();
}

class _MiniTaskFormState extends State<MiniTaskForm> {
  final TextEditingController _titleController = TextEditingController();
  String? _selectedProjectId;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final task = Task.blank().copyWith(
      title: title.isEmpty ? 'Untitled' : title,
      projectId: Wrapped(_selectedProjectId),
      startsAt: Wrapped(widget.start),
      endsAt: Wrapped(widget.end),
    );
    widget.onSubmit(task);
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      color: AppColors.surface.withValues(alpha: 0.4),
      blurLevel: 20,
      borderRadius: 16,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: widget.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('mini_task_title'),
              controller: _titleController,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                hintText: 'Название задачи',
                isDense: true,
                prefixIcon: Icon(Icons.task_alt, size: 18),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<Project>>(
              stream: widget.projects,
              builder: (context, snapshot) {
                final projects = snapshot.data ?? const <Project>[];
                return DropdownMenu<String?>(
                  key: ValueKey(
                    'mini_project_${_selectedProjectId}_${projects.length}',
                  ),
                  initialSelection: _selectedProjectId,
                  hintText: 'Проект',
                  width: widget.width,
                  textStyle: Theme.of(context).textTheme.bodySmall,
                  trailingIcon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppColors.primary,
                  ),
                  selectedTrailingIcon: const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: AppColors.primary,
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStateProperty.all(
                      AppColors.surfaceContainerLow,
                    ),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                  dropdownMenuEntries: [
                    const DropdownMenuEntry<String?>(
                      label: 'Без проекта',
                      value: null,
                    ),
                    ...projects.map((project) {
                      return DropdownMenuEntry<String?>(
                        value: project.id,
                        label: project.name,
                        labelWidget: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 12,
                              color: parseHexColor(project.color),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  onSelected: (value) =>
                      setState(() => _selectedProjectId = value),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: widget.onCancel,
                  icon: const Icon(Icons.close),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Отмена',
                ),
                const SizedBox(width: 4),
                FilledButton(onPressed: _submit, child: const Text('Create')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
