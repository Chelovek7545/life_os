import 'package:life_os/features/lifegraph/data/drift_graph_deletion.dart';
import 'dart:async';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:telegram_plugin/telegram_plugin.dart'
    show TelegramPlugin, LocalBotService;
import 'package:life_os/features/settings/telegram_settings_adapter.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/telegram_task_queries.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/lifegraph/presentation/pulse_screen_view_model.dart';
import 'package:life_os/features/resources/data/obsidian_repository.dart';
import 'package:life_os/features/resources/presentation/resources_view_model.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';
import 'package:life_os/features/spheres/data/spheres_dao.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/goals/data/goals_dao.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/habits/data/habits_repository.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/data/work_logs_dao.dart';
import 'package:life_os/features/tasks/data/work_logs_repository.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

class DependencyContainer {
  DependencyContainer({
    AppDatabase? database,
    this.enableTelegram = const bool.fromEnvironment(
      'ENABLE_TELEGRAM',
      defaultValue: true,
    ),
    Iterable<AppPlugin> additionalPlugins = const [],
  }) : database = database ?? AppDatabase() {
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
    obsidianRepository = ObsidianRepository();
    graphPositionsRepository = GraphPositionsRepository();
    graphNotesRepository = GraphNotesRepository(
      obsidianRepository: obsidianRepository,
    );
    graphBuilder = GraphBuilder(
      spheresRepository: spheresRepository,
      goalsRepository: goalsRepository,
      projectsRepository: projectsRepository,
      tasksRepository: tasksRepository,
    );
    pulseScreenViewModel = PulseScreenViewModel(
      spheresRepository: spheresRepository,
      goalsRepository: goalsRepository,
      projectsRepository: projectsRepository,
      tasksRepository: tasksRepository,
      positionsRepository: graphPositionsRepository,
      notesRepository: graphNotesRepository,
      graphBuilder: graphBuilder,
      deletion: DriftGraphDeletion(this.database),
      obsidianRepository: obsidianRepository,
    );
    taskWithPrjct = GetTasksWithProjectsUseCase(
      tasksRepository,
      projectsRepository,
    );
    tasksViewModel = TasksViewModel(
      tasksRepository,
      taskWithPrjct,
      projectsRepository,
    );
    projectViewModel = ProjectsViewModel(
      repository: projectsRepository,
      taskRepo: tasksRepository,
    );
    habitsViewModel = HabitsViewModel(habitsRepository);
    resourcesViewModel = ResourcesViewModel(
      graphNotesRepo: graphNotesRepository,
      obsidianRepo: obsidianRepository,
    );
    localBotService = enableTelegram
        ? LocalBotService(
            settings: AppTelegramSettings(),
            taskStore: BotTaskStore(this.database),
            tasksRepository: tasksRepository,
            workLogsRepository: workLogsRepository,
          )
        : null;
    plugins = PluginHost([
      if (localBotService != null) TelegramPlugin(localBotService!),
      ...additionalPlugins,
    ]);
  }

  final AppDatabase database;
  final bool enableTelegram;
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
  late final ObsidianRepository obsidianRepository;
  late final GraphBuilder graphBuilder;
  late final PulseScreenViewModel pulseScreenViewModel;
  late final TasksViewModel tasksViewModel;
  late final ProjectsViewModel projectViewModel;
  late final GetTasksWithProjectsUseCase taskWithPrjct;
  late final HabitsViewModel habitsViewModel;
  late final ResourcesViewModel resourcesViewModel;
  late final LocalBotService? localBotService;
  Future<void>? _initialization;
  Future<void>? _disposal;
  bool _listeningForSettings = false;

  Future<void> init() {
    if (_disposal != null) {
      throw StateError('Application dependencies are closed.');
    }
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await graphNotesRepository.init();
    await plugins.start();
    await pulseScreenViewModel.initialize();
    tasksViewModel.initialize();
    projectViewModel.initialize();
    habitsViewModel.initialize();
    SettingsService.obsidianVaultPath.addListener(_onVaultPathChanged);
    _listeningForSettings = true;
    _onVaultPathChanged();
  }

  void _onVaultPathChanged() {
    unawaited(
      resourcesViewModel.scanVault(SettingsService.obsidianVaultPath.value),
    );
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    // Cleanup must also work after a partial or failed startup.
    try {
      await _initialization;
    } catch (_) {}
    if (_listeningForSettings) {
      SettingsService.obsidianVaultPath.removeListener(_onVaultPathChanged);
      _listeningForSettings = false;
    }
    final failures = <String, Object>{};
    Future<void> close(String name, FutureOr<void> Function() action) async {
      try {
        await action();
      } catch (error) {
        failures[name] = error;
      }
    }

    await close('plugins', plugins.stop);
    await close('tasks', tasksViewModel.dispose);
    await close('projects', projectViewModel.dispose);
    await close('habits', habitsViewModel.dispose);
    await close('pulse', pulseScreenViewModel.dispose);
    await close('resources', () async {
      resourcesViewModel.dispose();
      await resourcesViewModel.pendingScan;
    });
    await close('graphNotes', graphNotesRepository.dispose);
    await close('obsidian', obsidianRepository.dispose);
    await close('database', database.close);
    if (failures.isNotEmpty) throw PluginLifecycleException(failures);
  }
}
