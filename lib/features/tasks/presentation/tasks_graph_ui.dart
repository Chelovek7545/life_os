import 'package:flutter/widgets.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import '../../lifegraph/presentation/widgets/existing_task_picker_dialog.dart';

GraphFormBuilder tasksGraphAttachForm(
  Stream<List<Task>> Function() watchTasks, {
  required bool subtask,
}) =>
    (_, actions) => StreamBuilder<List<Task>>(
      stream: watchTasks(),
      builder: (_, snapshot) => ExistingTaskPickerDialog(
        title: subtask
            ? 'Добавить существующую подзадачу'
            : 'Добавить существующую задачу',
        emptyText: subtask
            ? 'Нет доступных задач для подзадачи'
            : 'Нет задач без проекта',
        tasks: (snapshot.data ?? const <Task>[])
            .where(
              (task) => subtask
                  ? task.id != actions.node.id && task.parentTaskId == null
                  : task.projectId == null && task.parentTaskId == null,
            )
            .toList(),
        onSelect: (id) => actions.attachNode(subtask ? 'subTask' : 'task', id),
      ),
    );
