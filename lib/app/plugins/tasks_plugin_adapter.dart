import 'package:tasks_api/tasks_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_plugin/tasks_plugin.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';
import 'package:life_os/features/tasks/presentation/components/task_editor_overlay.dart';
import 'package:life_os/features/tasks/presentation/tasks_graph_ui.dart';
import 'package:graph_components/graph_components.dart';
import 'package:life_os/features/tasks/presentation/tasks_graph_components.dart';
import 'package:life_os/features/tasks/presentation/components/pulse_quick_task.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart' show PulsePanelSlots;

UiModuleSpec pulseQuickTaskModule(TasksViewModel Function() tasks) =>
    UiModuleSpec(
      id: 'tasks.quick-input',
      dependencies: {'tasks.core', 'lifegraph.screen'},
      panels: [
        PluginPanelContribution(
          id: 'tasks.quick-input.pulse',
          slot: PulsePanelSlots.toolbar,
          order: -10,
          builder: (_, panel) {
            final model = tasks();
            return PulseQuickTaskAction(
              addTask: model.addTask,
              isActive: () => panel.isActive && model.isActive,
              watchProjects: model.watchProjects,
            );
          },
        ),
      ],
    );

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
  TasksNodeUi node({bool subtask = false}) {
    final spec = taskGraphComponent(subtask: subtask);
    return TasksNodeUi(
      size: spec.size,
      card: (context, node, state, setStatus) => graphNodePresentation(
        taskGraphComponent(subtask: subtask, setStatus: setStatus),
      ).builder(context, node, state),
      editor: graphNodeEditor(spec).builder,
      create: (_, actions) => graphChildForm(spec, actions),
      standaloneForm: subtask
          ? null
          : GraphStandaloneForm(
              label: 'Создать задачу',
              builder: (_, create) =>
                  GraphChildCreateDialog(spec: spec, onSave: create),
            ),
      attach: (watchTasks) =>
          tasksGraphAttachForm(watchTasks, subtask: subtask),
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
        embeddedEditor: false,
      ),
      overlay: (_, model, logs) =>
          TaskEditorOverlay(viewModel: model, workLogs: logs),
      task: node(),
      subtask: node(subtask: true),
    ),
  );
}
