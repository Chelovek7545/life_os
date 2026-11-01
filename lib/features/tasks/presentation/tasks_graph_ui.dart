import 'package:flutter/widgets.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import '../../lifegraph/domain/graph_node.dart';
import '../../lifegraph/presentation/widgets/builtin_graph_forms.dart';
import '../../lifegraph/presentation/widgets/existing_task_picker_dialog.dart';

List<GraphNodeEditor> tasksGraphEditors() => [
  builtinGraphEditor(GraphNodeType.task),
  builtinGraphEditor(GraphNodeType.subTask),
];

List<GraphChildAction> tasksGraphChildActions(TaskQueries tasks) => [
  GraphChildAction(
    id: 'tasks.create',
    label: 'Новую задачу',
    childKind: 'task',
    parentKinds: {'project'},
    order: 10,
    builder: (_, actions) => builtinGraphChildForm(GraphNodeType.task, actions),
  ),
  GraphChildAction(
    id: 'tasks.createSubtask',
    label: 'Новую подзадачу',
    childKind: 'subTask',
    parentKinds: {'task'},
    order: 10,
    builder: (_, actions) =>
        builtinGraphChildForm(GraphNodeType.subTask, actions),
  ),
  _attach(tasks, subtask: false),
  _attach(tasks, subtask: true),
];

GraphChildAction _attach(TaskQueries tasks, {required bool subtask}) =>
    GraphChildAction(
      id: subtask ? 'tasks.attachSubtask' : 'tasks.attach',
      label: 'Существующую задачу',
      childKind: subtask ? 'subTask' : 'task',
      parentKinds: {subtask ? 'task' : 'project'},
      operation: GraphChildOperation.attach,
      builder: (_, actions) => StreamBuilder<List<Task>>(
        stream: tasks.watchTasks(),
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
          onSelect: (id) =>
              actions.attachNode(subtask ? 'subTask' : 'task', id),
        ),
      ),
    );
