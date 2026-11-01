import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'plugins/life_graph_modules.dart';
import 'plugins/application_ui_modules.dart';
import 'plugins/projects_plugin_adapter.dart';
import 'plugins/habits_plugin_adapter.dart';
import 'plugins/tasks_plugin_adapter.dart';
import 'plugins/lifegraph_plugin_adapter.dart';
import 'plugins/resources_plugin_adapter.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:resources_plugin/resources_plugin.dart';
import 'package:tasks_plugin/tasks_plugin.dart';
import 'package:habits_plugin/habits_plugin.dart';
import 'package:projects_plugin/projects_plugin.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'plugins/telegram_ui.dart';
import 'plugins/obsidian_ui.dart';
import 'package:life_os/features/settings/vault_settings_adapter.dart';
import 'package:life_os/features/lifegraph/data/drift_graph_deletion.dart';
import 'dart:async';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:telegram_plugin/telegram_plugin.dart' show LocalBotService;
import 'package:life_os/features/settings/telegram_settings_adapter.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/telegram_task_queries.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/spheres/data/spheres_dao.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/goals/data/goals_dao.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/habits/data/habits_repository.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';

class DependencyContainer {
  DependencyContainer({
    AppDatabase? database,
    this.enableTelegram = const bool.fromEnvironment(
      'ENABLE_TELEGRAM',
      defaultValue: true,
    ),
    this.enableObsidian = const bool.fromEnvironment(
      'ENABLE_OBSIDIAN',
      defaultValue: true,
    ),
    Iterable<AppPlugin> additionalPlugins = const [],
    Iterable<GraphModule> graphModules = const [],
    Iterable<UiModuleSpec> uiModules = const [],
  }) : database = database ?? AppDatabase() {
    final extraGraphModules = List<GraphModule>.of(graphModules);
    tasksDAO = TasksDao(this.database);
    projectsDao = ProjectsDao(this.database);
    spheresDao = SpheresDao(this.database);
    goalsDao = GoalsDao(this.database);
    habitsDao = HabitsDao(this.database);
    workLogsDao = WorkLogsDao(this.database);
    tasksRepository = TasksRepository(tasksDAO);
    projectsRepository = ProjectsRepository(projectsDao);
    spheresRepository = SpheresRepository(spheresDao);
    goalsRepository = GoalsRepository(goalsDao);
    habitsRepository = HabitsRepository(habitsDao);
    workLogsRepository = WorkLogsRepository(workLogsDao);
    obsidianRepository = enableObsidian ? ObsidianVault() : null;
    ui = PluginUiRegistry();
    navigation = PluginNavigationController(ui);
    graphPositionsRepository = GraphPositionsRepository();
    graphNotesRepository = GraphNotesRepository();
    graphContributors = GraphContributorRegistry();
    graphPresentations = GraphNodePresentationRegistry();
    graphEditors = GraphEditorRegistry();
    graphCommands = GraphCommandRegistry();
    lifeGraphPlugin = createLifeGraphPlugin(
      spheres: spheresRepository,
      goals: goalsRepository,
      projects: projectsRepository,
      tasks: tasksRepository,
      positions: graphPositionsRepository,
      notes: graphNotesRepository,
      contributors: graphContributors,
      presentations: graphPresentations,
      editors: graphEditors,
      commands: graphCommands,
      ui: ui,
      vault: obsidianRepository,
      completeTask: (task) => tasksPlugin.viewModel.toggleTask(task),
      dependencies: {
        'spheres.graph',
        'goals.graph',
        'projects.graph',
        'tasks.graph',
        for (final module in extraGraphModules) module.id,
        if (enableObsidian) 'obsidian',
      },
    );
    habitsPlugin = createHabitsPlugin(habits: habitsRepository, ui: ui);
    resourcesPlugin = createResourcesPlugin(
      notes: graphNotesRepository,
      vault: obsidianRepository,
      ui: ui,
      dependencies: {if (enableObsidian) 'obsidian'},
    );
    localBotService = enableTelegram
        ? LocalBotService(
            settings: AppTelegramSettings(),
            taskStore: BotTaskStore(this.database),
            tasksRepository: tasksRepository,
            workLogsRepository: workLogsRepository,
          )
        : null;
    projectsPlugin = createProjectsPlugin(
      projects: projectsRepository,
      tasks: tasksRepository,
      contributors: graphContributors,
      presentations: graphPresentations,
      editors: graphEditors,
      commands: graphCommands,
      ui: ui,
      delete: (request) => DriftGraphDeletion(this.database).delete(
        GraphNodeType.project,
        request.node.id,
        keepChildren: request.keepChildren,
      ),
    );
    tasksPlugin = createTasksPlugin(
      tasks: tasksRepository,
      projects: projectsRepository,
      workLogs: workLogsRepository,
      ui: ui,
      contributors: graphContributors,
      presentations: graphPresentations,
      editors: graphEditors,
      commands: graphCommands,
      delete: (request) => DriftGraphDeletion(this.database).delete(
        GraphNodeType.task,
        request.node.id,
        keepChildren: request.keepChildren,
      ),
    );
    plugins = PluginHost([
      for (final module in [
        ...lifeGraphModules(
          spheres: spheresRepository,
          goals: goalsRepository,
          deletion: DriftGraphDeletion(this.database),
        ),
        ...extraGraphModules,
      ])
        GraphModulePlugin(
          module: module,
          contributors: graphContributors,
          presentations: graphPresentations,
          commands: graphCommands,
          editors: graphEditors,
        ),
      if (obsidianRepository != null)
        registerObsidianUi(obsidianRepository!, AppVaultSettings(), ui),
      if (localBotService != null) registerTelegramUi(localBotService!, ui),
      ...lifeGraphPlugin.plugins,
      ...resourcesPlugin.plugins,
      ...projectsPlugin.plugins,
      ...habitsPlugin.plugins,
      ...tasksPlugin.plugins,
      for (final module in uiModules) registerUiModule(module, ui),
      ...additionalPlugins,
    ]);
  }

  final AppDatabase database;
  final bool enableTelegram;
  final bool enableObsidian;
  late final PluginUiRegistry ui;
  late final PluginNavigationController navigation;
  late final PluginHost plugins;
  late final TasksDao tasksDAO;
  late final ProjectsDao projectsDao;
  late final SpheresDao spheresDao;
  late final GoalsDao goalsDao;
  late final HabitsDao habitsDao;
  late final WorkLogsDao workLogsDao;
  late final TasksRepository tasksRepository;
  late final ProjectsRepository projectsRepository;
  late final SpheresRepository spheresRepository;
  late final GoalsRepository goalsRepository;
  late final HabitsRepository habitsRepository;
  late final WorkLogsRepository workLogsRepository;
  late final GraphPositionsRepository graphPositionsRepository;
  late final GraphNotesRepository graphNotesRepository;
  late final ObsidianVault? obsidianRepository;
  GraphBuilder get graphBuilder => lifeGraphPlugin.graphBuilder;
  late final GraphContributorRegistry graphContributors;
  late final GraphNodePresentationRegistry graphPresentations;
  late final GraphEditorRegistry graphEditors;
  late final GraphCommandRegistry graphCommands;
  late final LifeGraphPlugin lifeGraphPlugin;
  PulseScreenViewModel get pulseScreenViewModel => lifeGraphPlugin.viewModel;
  late final TasksPlugin tasksPlugin;
  TasksViewModel get tasksViewModel => tasksPlugin.viewModel;
  late final ProjectsPlugin projectsPlugin;
  ProjectsViewModel get projectViewModel => projectsPlugin.viewModel;
  late final HabitsPlugin habitsPlugin;
  HabitsViewModel get habitsViewModel => habitsPlugin.viewModel;
  late final ResourcesPlugin resourcesPlugin;
  ResourcesViewModel get resourcesViewModel => resourcesPlugin.viewModel;
  late final LocalBotService? localBotService;
  Future<void>? _initialization;
  Future<void>? _disposal;

  Future<void> init() {
    if (_disposal != null) {
      throw StateError('Application dependencies are closed.');
    }
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await graphNotesRepository.init();
    await plugins.start();
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    // Cleanup must also work after a partial or failed startup.
    try {
      await _initialization;
    } catch (_) {}
    final failures = <String, Object>{};
    Future<void> close(String name, FutureOr<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        failures[name] = error;
      }
    }

    await close('plugins', plugins.stop);
    await close('graphCommands', graphCommands.dispose);
    await close('graphEditors', graphEditors.dispose);
    await close('graphContributors', graphContributors.dispose);
    await close('graphPresentations', graphPresentations.dispose);
    await close('graphNotes', graphNotesRepository.dispose);
    if (obsidianRepository != null)
      await close('obsidian', obsidianRepository!.dispose);
    await close('navigation', navigation.dispose);
    await close('pluginUi', ui.dispose);
    await close('database', database.close);
    if (failures.isNotEmpty) throw PluginLifecycleException(failures);
  }
}
