import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:notes_api/notes_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/lifegraph/presentation/pulse_screen.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_folders_form.dart';
import 'package:life_os/features/lifegraph/data/graph_storage_settings_adapter.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_directory_picker.dart';

LifeGraphPlugin createLifeGraphPlugin({
  required SpheresApi spheres,
  required GoalsQueries goals,
  required ProjectsQueries projects,
  required TaskQueries tasks,
  required GraphPositionsStore positions,
  required CanvasNotesStore notes,
  required GraphContributorRegistry contributors,
  required GraphNodePresentationRegistry presentations,
  required GraphEditorRegistry editors,
  required GraphCommandRegistry commands,
  required PluginUiRegistry ui,
  required Future<void> Function(Task) completeTask,
  required Set<String> dependencies,
  VaultNotesApi? vault,
  Future<void> Function(GraphStorageTarget)? selectStorageTarget,
}) => LifeGraphPlugin(
  spheres: spheres,
  goals: goals,
  projects: projects,
  tasks: tasks,
  positions: positions,
  notes: notes,
  contributors: contributors,
  presentations: presentations,
  editors: editors,
  commands: commands,
  ui: ui,
  completeTask: completeTask,
  vault: vault,
  dependencies: dependencies,
  storageSettings: AppGraphStorageSettings(),
  storageSettingsBuilder: (_, isActive) => GraphFoldersForm(
    initial: SettingsService.graphFolders.value,
    initialTarget: SettingsService.graphStorageTarget.value,
    vaultPath: SettingsService.obsidianVaultPath.value,
    pickDirectory: pickGraphDirectory,
    saveTarget: selectStorageTarget == null
        ? null
        : (target) async {
            if (!isActive()) throw StateError('Настройки графа уже закрыты.');
            await selectStorageTarget(target);
            if (!isActive()) throw StateError('Настройки графа уже закрыты.');
            await SettingsService.setGraphStorageTarget(target);
          },
    listFolders: () async => vault is CanvasStorageFoldersApi
        ? (vault as CanvasStorageFoldersApi).listFolders()
        : [],
    save: (value) async {
      if (!isActive()) throw StateError('Настройки графа уже закрыты.');
      var folders = value;
      if (vault is CanvasStorageFoldersApi) {
        final storage = vault as CanvasStorageFoldersApi;
        await storage.configureFolders(value);
        folders = storage.folders;
      }
      if (!isActive()) throw StateError('Настройки графа уже закрыты.');
      await SettingsService.setGraphFolders(folders);
    },
  ),
  screen: (_, model, registry, openTask, completeTask) => PulseScreen(
    viewModel: model,
    registry: registry,
    portraitAppBarAction: PluginActions(
      registry: registry,
      location: PluginActionLocation.appBar,
      compact: true,
    ),
    onOpenTask: openTask,
    onCompleteTask: completeTask,
  ),
);
