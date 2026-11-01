import 'package:projects_plugin/projects_plugin.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:life_os/features/projects/presentation/projects_screen.dart';
import 'package:graph_components/graph_components.dart';
import 'package:life_os/features/projects/presentation/projects_graph_ui.dart';

ProjectsPlugin createProjectsPlugin({
  required ProjectsApi projects,
  required TasksApi tasks,
  required GraphContributorRegistry contributors,
  required GraphNodePresentationRegistry presentations,
  required GraphEditorRegistry editors,
  required GraphCommandRegistry commands,
  required PluginUiRegistry ui,
  required GraphDeleteHandler delete,
}) {
  final card = graphNodePresentation(projectGraphComponent);
  final editor = graphNodeEditor(projectGraphComponent);
  return ProjectsPlugin(
    projects: projects,
    tasks: tasks,
    contributors: contributors,
    presentations: presentations,
    editors: editors,
    commands: commands,
    ui: ui,
    delete: delete,
    visuals: ProjectsUiBindings(
      screen: (_, viewModel) => ProjectsScreen(viewModel: viewModel),
      nodeCard: card.builder,
      nodeSize: card.size,
      editor: editor.builder,
      createForm: (_, actions) =>
          graphChildForm(projectGraphComponent, actions),
    ),
  );
}
