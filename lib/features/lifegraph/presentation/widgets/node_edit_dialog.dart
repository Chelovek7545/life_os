import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/date_pick_button.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

/// Диалог редактирования ноды: название, описание, цвет (для всех, кроме
/// задач) и статус (для задач). Также предлагает удаление ноды.
class NodeEditDialog extends StatefulWidget {
  final GraphNode node;
  final ValueChanged<GraphNode> onSave;
  final ValueChanged<bool> onDelete; // keepChildren

  const NodeEditDialog({
    super.key,
    required this.node,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<NodeEditDialog> createState() => _NodeEditDialogState();
}

class _NodeEditDialogState extends State<NodeEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  String _selectedColor = '#4A90D9';
  TaskStatus? _selectedStatus;

  static const List<String> _colors = [
    '#4A90D9', '#E8A838', '#4CAF50', '#E91E63', '#9C27B0',
    '#00BCD4', '#FF9800', '#795548', '#607D8B', '#F44336',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.node.title);
    _subtitleController = TextEditingController(text: widget.node.subtitle);
    _selectedColor = widget.node.color;
    _selectedStatus = widget.node.taskStatus;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTask = widget.node.type == GraphNodeType.task;

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      title: Text(_dialogTitle),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subtitleController,
                decoration: const InputDecoration(
                  labelText: 'Описание',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              if (!isTask) ...[
                const SizedBox(height: 12),
                const Text('Цвет:', style: TextStyle(color: AppColors.onSurface)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colors.map((c) => _ColorChip(
                    color: c,
                    selected: _selectedColor == c,
                    onTap: () => setState(() => _selectedColor = c),
                  )).toList(),
                ),
              ],
              if (isTask) ...[
                const SizedBox(height: 12),
                const Text('Статус:', style: TextStyle(color: AppColors.onSurface)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: TaskStatus.values.map((s) => _StatusChip(
                    status: s,
                    selected: _selectedStatus == s,
                    onTap: () => setState(() => _selectedStatus = s),
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          label: const Text('Удалить', style: TextStyle(color: Colors.redAccent)),
          onPressed: () => _confirmDelete(context),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            final updated = widget.node.copyWith(
              title: _titleController.text.trim(),
              subtitle: _subtitleController.text.trim(),
              color: _selectedColor,
              taskStatus: _selectedStatus,
            );
            widget.onSave(updated);
            Navigator.pop(context);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }

  String get _dialogTitle {
    switch (widget.node.type) {
      case GraphNodeType.sphere:
        return 'Редактировать сферу';
      case GraphNodeType.goal:
        return 'Редактировать цель';
      case GraphNodeType.project:
        return 'Редактировать проект';
      case GraphNodeType.task:
        return 'Редактировать задачу';
    }
  }

  void _confirmDelete(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Удалить ноду?'),
        content: Text('Нода "${widget.node.title}" будет удалена. '
            'Выберите, что сделать с дочерними элементами.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(false); // каскадно
            },
            child: const Text('Удалить всё поддерево'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(true); // только ноду, дети станут осиротевшими
            },
            child: const Text('Сохранить детей (станут невидимыми)'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
        ],
      ),
    );
  }
}

/// Диалог создания дочерней ноды (следующий уровень иерархии).
class AddChildDialog extends StatefulWidget {
  final GraphNode parentNode;
  final Future<void> Function({
    required String title,
    required String description,
    String? color,
    DateTime? dueDate,
    DateTime? startsAt,
    DateTime? endsAt,
  }) onSave;

  const AddChildDialog({
    super.key,
    required this.parentNode,
    required this.onSave,
  });

  @override
  State<AddChildDialog> createState() => _AddChildDialogState();
}

class _AddChildDialogState extends State<AddChildDialog> {
  final TextEditingController _titleController = TextEditingController();
  String _description = '';
  String? _selectedColor;
  DateTime? _dueDate;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  static const List<String> _colors = [
    '#4A90D9', '#E8A838', '#4CAF50', '#E91E63', '#9C27B0',
    '#00BCD4', '#FF9800', '#795548', '#607D8B', '#F44336',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTaskChild = widget.parentNode.type == GraphNodeType.project;

    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      title: Text('Добавить ${_childName(widget.parentNode.type)}'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  border: OutlineInputBorder(),
                ),
              ),
              if (!isTaskChild) ...[
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Описание',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  onChanged: (v) => _description = v,
                ),
                const SizedBox(height: 12),
                const Text('Цвет:', style: TextStyle(color: AppColors.onSurface)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colors.map((c) => _ColorChip(
                    color: c,
                    selected: _selectedColor == c,
                    onTap: () => setState(() => _selectedColor = c),
                  )).toList(),
                ),
              ],
              if (isTaskChild) ...[
                const SizedBox(height: 12),
                const Text('Начало — конец:', style: TextStyle(color: AppColors.onSurface)),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TimeChip(
                        icon: Icons.calendar_month,
                        label: _startsAt == null
                            ? 'Set day'
                            : '${formatDate(_startsAt!)}${_endsAt != null && _startsAt!.startOfDay != _endsAt!.startOfDay ? " - ${formatDate(_endsAt!)}" : ""}',
                        isActive: _startsAt != null,
                        onPressed: _pickDay,
                        onCancel: _clearTimes,
                      ),
                      const SizedBox(width: 8),
                      _TimeChip(
                        icon: Icons.access_time,
                        label: _startsAt != null && !_startsAt!.isDateOnly
                            ? formatTimeOfDate(_startsAt!)
                            : 'Set start time',
                        isActive: _startsAt != null && !_startsAt!.isDateOnly,
                        onPressed: _pickStartTime,
                        onCancel: _clearStartTime,
                      ),
                      const SizedBox(width: 6),
                      const Text('-', style: TextStyle(color: Colors.white70)),
                      const SizedBox(width: 6),
                      _TimeChip(
                        icon: Icons.access_time,
                        label: _endsAt != null && !_endsAt!.isDateOnly
                            ? formatTimeOfDate(_endsAt!)
                            : 'Set end time',
                        isActive: _endsAt != null && !_endsAt!.isDateOnly,
                        onPressed: _pickEndTime,
                        onCancel: _clearEndTime,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Срок выполнения:', style: TextStyle(color: AppColors.onSurface)),
                const SizedBox(height: 8),
                datePickButton(
                  context,
                  label: 'Выбрать дату',
                  date: _dueDate,
                  onDateChange: (d) => setState(() => _dueDate = d),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _saving
              ? null
              : () async {
                  if (_titleController.text.trim().isEmpty) return;
                  setState(() => _saving = true);
                  await widget.onSave(
                    title: _titleController.text.trim(),
                    description: _description,
                    color: _selectedColor,
                    dueDate: _dueDate,
                    startsAt: _startsAt,
                    endsAt: _endsAt,
                  );
                  if (context.mounted) Navigator.pop(context);
                },
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }

  String _childName(GraphNodeType type) {
    switch (type) {
      case GraphNodeType.sphere:
        return 'цель';
      case GraphNodeType.goal:
        return 'проект';
      case GraphNodeType.project:
        return 'задачу';
      case GraphNodeType.task:
        return '';
    }
  }

  // ── Начало / конец (чипы, как в собранной форме задачи) ─────────────────

  Future<void> _pickDay() async {
    final selected = await chooseDateOnly(context, _startsAt);
    if (selected == null || !mounted) return;
    setState(() {
      _startsAt = selected.copyWith(
        hour: _startsAt?.hour,
        minute: _startsAt?.minute,
      );
      _endsAt = selected.copyWith(
        hour: _endsAt?.hour,
        minute: _endsAt?.minute,
      );
    });
  }

  void _clearTimes() {
    setState(() {
      _startsAt = null;
      _endsAt = null;
    });
  }

  Future<void> _pickStartTime() async {
    if (_startsAt == null) return;
    final selected = await chooseTimeForDate(context, _startsAt!);
    if (selected != null && _validateStart(selected) && mounted) {
      setState(() => _startsAt = selected);
    }
  }

  Future<void> _pickEndTime() async {
    if (_endsAt == null && _startsAt == null) return;
    final selected = await chooseTimeForDate(context, _endsAt ?? _startsAt!);
    if (selected != null && _validateEnd(selected) && mounted) {
      setState(() {
        _endsAt = _startsAt?.copyWith(
          hour: selected.hour,
          minute: selected.minute,
        );
      });
    }
  }

  void _clearStartTime() {
    setState(() => _startsAt = _startsAt?.startOfDay);
  }

  void _clearEndTime() {
    setState(() => _endsAt = _endsAt?.startOfDay);
  }

  bool _validateStart(DateTime date) {
    if (_endsAt != null) {
      return date.isBefore(_endsAt!) ||
          (date.isDateOnly || _endsAt!.isDateOnly) &&
              date.startOfDay.isAtSameMomentAs(_endsAt!.startOfDay);
    }
    return true;
  }

  bool _validateEnd(DateTime date) {
    if (_startsAt != null) {
      return date.isAfter(_startsAt!) ||
          (date.isDateOnly || _startsAt!.isDateOnly) &&
              date.startOfDay.isAtSameMomentAs(_startsAt!.startOfDay);
    }
    return true;
  }
}

/// Чип для выбора дня / времени начала и конца (как в собранной форме задачи).
class _TimeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;
  final VoidCallback onCancel;

  const _TimeChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onPressed,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primaryContainer : Colors.white70;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.overdueGlow : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.overdueGlow : AppColors.inputGlass,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onCancel,
              icon: Icon(isActive ? Icons.close : icon, size: 16, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 16,
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {  final String color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChip({required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = Color(int.parse(color.replaceFirst('#', '0xFF')));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: selected ? [
            BoxShadow(
              color: c.withValues(alpha: 0.5),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ] : [],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TaskStatus status;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({required this.status, required this.selected, required this.onTap});

  Color get _color {
    switch (status) {
      case TaskStatus.done:
        return Colors.green;
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.notStarted:
        return Colors.orange;
      case TaskStatus.open:
        return Colors.grey;
    }
  }

  String get _label {
    switch (status) {
      case TaskStatus.done:
        return '✓';
      case TaskStatus.inProgress:
        return '▶';
      case TaskStatus.notStarted:
        return '○';
      case TaskStatus.open:
        return '…';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _color : _color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _color : _color.withValues(alpha: 0.3)),
        ),
        child: Text(
          _label,
          style: TextStyle(
            color: selected ? Colors.white : _color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
