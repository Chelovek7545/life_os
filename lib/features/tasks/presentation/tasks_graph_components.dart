import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_components/graph_components.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'task_status_visuals.dart';
import 'graph_task_schedule_fields.dart';

GraphNodeComponentSpec taskGraphComponent({bool subtask = false}) =>
    GraphNodeComponentSpec(
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
      editFields: _statusFields,
      createFields: subtask
          ? null
          : (_, _, onChanged) => GraphTaskScheduleFields(onChanged: onChanged),
    );

String _statusLabel(TaskStatus status) => switch (status) {
  TaskStatus.done => 'Выполнено',
  TaskStatus.inProgress => 'В процессе',
  TaskStatus.notStarted => 'Не начато',
  TaskStatus.open => 'Открыто',
};

Widget? _statusBadge(BuildContext context, GraphNodeData node) {
  final value = node.attributes['taskStatus'];
  if (value is! String) return null;
  final status = taskStatusFromStorage(value);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: status.color.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      _statusLabel(status),
      style: TextStyle(
        color: status.color,
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
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
