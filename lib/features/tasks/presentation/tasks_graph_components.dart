import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_components/graph_components.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'task_status_visuals.dart';
import 'graph_task_schedule_fields.dart';

GraphNodeComponentSpec taskGraphComponent({
  bool subtask = false,
  Future<void> Function(String, TaskStatus)? setStatus,
}) => GraphNodeComponentSpec(
  kind: subtask ? 'subTask' : 'task',
  label: subtask ? 'ПОДЗАДАЧА' : 'ЗАДАЧА',
  icon: Icons.task_alt_rounded,
  size: const Size(160, 120),
  editTitle: subtask ? 'Редактировать подзадачу' : 'Редактировать задачу',
  createTitle: subtask ? 'Добавить Подзадачу' : 'Добавить задачу',
  editColor: false,
  createColor: subtask,
  createDescription: subtask,
  badge: _statusBadge,
  details: _taskDuration,
  leading: setStatus == null
      ? null
      : (_, node, state) => _GraphTaskCheckbox(
          completed: node.attributes['taskStatus'] == TaskStatus.done.name,
          accent: graphColor(node.color, fallback: state.accent),
          setStatus: (status) => setStatus(node.id, status),
        ),
  editFields: _statusFields,
  createFields: subtask
      ? null
      : (_, _, onChanged) => GraphTaskScheduleFields(onChanged: onChanged),
);

String _statusLabel(TaskStatus status) => switch (status) {
  TaskStatus.done => 'Выполнено',
  TaskStatus.inProgress => 'В работе',
  TaskStatus.notStarted => 'Не начато',
  TaskStatus.open => 'Открыто',
};

Widget? _statusBadge(BuildContext context, GraphNodeData node) {
  final value = node.attributes['taskStatus'];
  if (value is! String) return null;
  final status = taskStatusFromStorage(value);
  return GraphNodeMetaChip(label: _statusLabel(status), accent: status.color);
}

class _GraphTaskCheckbox extends StatefulWidget {
  const _GraphTaskCheckbox({
    required this.completed,
    required this.accent,
    required this.setStatus,
  });

  final bool completed;
  final Color accent;
  final Future<void> Function(TaskStatus) setStatus;

  @override
  State<_GraphTaskCheckbox> createState() => _GraphTaskCheckboxState();
}

class _GraphTaskCheckboxState extends State<_GraphTaskCheckbox> {
  bool _saving = false;

  Future<void> _setCompleted(bool? checked) async {
    if (_saving || checked == null) return;
    setState(() => _saving = true);
    try {
      await widget.setStatus(checked ? TaskStatus.done : TaskStatus.inProgress);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось изменить статус задачи.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.completed
        ? 'Вернуть в работу'
        : 'Отметить выполненной';
    final palette = GraphComponentPalette.of(context);
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox(
        width: 24,
        height: 28,
        child: Checkbox(
          value: widget.completed,
          onChanged: _saving ? null : _setCompleted,
          semanticLabel: label,
          //shape: const CircleBorder(),
          //side: BorderSide(color: widget.accent, width: 1.7),
          //activeColor: widget.accent,
          checkColor: palette.surfaceDim,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}

Widget? _taskDuration(
  BuildContext context,
  GraphNodeData node,
  GraphNodeInteraction state,
) {
  final minutes = node.attributes['durationMinutes'];
  if (minutes is! int || minutes <= 0) return null;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  final label = [
    if (hours > 0) '$hours ч',
    if (rest > 0) '$rest мин',
  ].join(' ');
  return GraphNodeMetaChip(icon: Icons.schedule_outlined, label: label);
}

Widget _statusFields(
  BuildContext context,
  Map<String, Object?> attributes,
  ValueChanged<Map<String, Object?>> onChanged,
) {
  final value = attributes['taskStatus'];
  final status = value is String
      ? taskStatusFromStorage(value)
      : TaskStatus.open;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 12),
      const Text('Status:', style: TextStyle(color: AppColors.onSurface)),
      const SizedBox(height: 8),
      PillSwitcher(
        options: TaskStatus.values.map((e) => Icon(e.icon)).toList(),
        colors: TaskStatus.values.map((e) => e.color).toList(),
        onSelectionChanged: (index) =>
            onChanged({'taskStatus': TaskStatus.values[index].name}),
        selectedIndex: TaskStatus.values.indexOf(status),
      ),
    ],
  );
}
