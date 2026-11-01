import 'package:tasks_api/tasks_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_plugin/tasks_plugin.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';
import 'package:life_os/features/tasks/presentation/tasks_graph_ui.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:life_os/features/lifegraph/presentation/widgets/builtin_graph_forms.dart';

TasksPlugin createTasksPlugin({
  required TasksApi tasks,
  required ProjectsQueries projects,
  required WorkLogsApi workLogs,
  required PluginUiRegistry ui,
  required GraphContributorRegistry contributors,
  required GraphNodePresentationRegistry presentations,
  required GraphEditorRegistry editors,
  required GraphCommandRegistry commands,
  required GraphDeleteHandler delete,
}) {
  TasksNodeUi node(GraphNodeType type) {
    final card = builtinGraphPresentation(type);
    return TasksNodeUi(
      size: card.size,
      card: card.builder,
      editor: builtinGraphEditor(type).builder,
      create: (_, actions) => builtinGraphChildForm(type, actions),
      attach: (watchTasks) => tasksGraphAttachForm(
        watchTasks,
        subtask: type == GraphNodeType.subTask,
      ),
    );
  }

  return TasksPlugin(
    tasks: tasks,
    projects: projects,
    workLogs: workLogs,
    ui: ui,
    contributors: contributors,
    presentations: presentations,
    editors: editors,
    commands: commands,
    delete: delete,
    visuals: TasksUiBindings(
      screen: (_, model, logs, setInset) => TasksScreen(
        viewModel: model,
        workLogs: logs,
        onFormVisibilityChanged: setInset,
      ),
      task: node(GraphNodeType.task),
      subtask: node(GraphNodeType.subTask),
    ),
  );
}
