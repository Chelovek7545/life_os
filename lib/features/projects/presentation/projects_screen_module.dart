import 'package:plugin_ui/plugin_ui.dart';
import 'package:projects_plugin/projects_plugin.dart';
import 'projects_screen.dart';

UiModuleSpec projectsScreenModule(ProjectsViewModel viewModel) => UiModuleSpec(
  id: 'projects.screen',
  screens: [
    projectsScreenContribution(
      model: () => viewModel,
      builder: (_, model) => ProjectsScreen(viewModel: model),
    ),
  ],
);
