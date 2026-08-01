import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
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
}

class _ColorChip extends StatelessWidget {
  final String color;
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
