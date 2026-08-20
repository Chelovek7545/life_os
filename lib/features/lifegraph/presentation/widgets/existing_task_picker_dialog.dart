import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

/// Диалог выбора уже существующей задачи (без проекта) для привязки к проекту
/// в графе. По тапу по задаче вызывает [onSelect] с её id.
class ExistingTaskPickerDialog extends StatefulWidget {
  final List<Task> tasks;
  final ValueChanged<String> onSelect;

  const ExistingTaskPickerDialog({
    super.key,
    required this.tasks,
    required this.onSelect,
  });

  @override
  State<ExistingTaskPickerDialog> createState() => _ExistingTaskPickerDialogState();
}

class _ExistingTaskPickerDialogState extends State<ExistingTaskPickerDialog> {
  String _query = '';

  List<Task> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.tasks;
    return widget.tasks
        .where((t) => t.title.toLowerCase().contains(q) || t.description.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      title: const Text('Добавить существующую задачу'),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Поиск по названию…',
                prefixIcon: Icon(Icons.search, size: 20),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'Нет задач без проекта',
                        style: TextStyle(color: AppColors.onSurfaceVariant),
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filtered.length,
                      separatorBuilder: (_, _) => Divider(height: 1, color: AppColors.borderGlass),
                      itemBuilder: (context, index) {
                        final task = _filtered[index];
                        return ListTile(
                          leading: Icon(task.status.icon, color: task.status.color, size: 22),
                          title: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                          ),
                          subtitle: task.description.isEmpty
                              ? null
                              : Text(
                                  task.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11.5),
                                ),
                          trailing: _StatusChip(status: task.status),
                          onTap: () {
                            widget.onSelect(task.id);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _label(status),
        style: TextStyle(color: status.color, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }

  String _label(TaskStatus status) {
    switch (status) {
      case TaskStatus.done:
        return 'Выполнено';
      case TaskStatus.inProgress:
        return 'В процессе';
      case TaskStatus.notStarted:
        return 'Не начато';
      case TaskStatus.open:
        return 'Открыто';
    }
  }
}
