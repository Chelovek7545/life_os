// core/di/dependency_container.dart
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/routine/data/routine_repository.dart';
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
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

class DependencyContainer {
  static final DependencyContainer _instance = DependencyContainer._internal();
  factory DependencyContainer() => _instance;
  DependencyContainer._internal();

  late final AppDatabase database;
  RoutineRepository? _routineRepository;
  RoutineRepository get routineRepository =>
      _routineRepository ??= RoutineRepository(database);
  late final TasksDao tasksDAO;
  late final ProjectsDao projectsDao;
  late final SpheresDao spheresDao;
  late final GoalsDao goalsDao;
  late final HabitsDao habitsDao;
  // late final ApiClient apiClient;
  // late final SyncService syncService;

  late final TasksRepository tasksRepository;
  late final ProjectsRepository projectsRepository;
  late final SpheresRepository spheresRepository;
  late final GoalsRepository goalsRepository;
  late final HabitsRepository habitsRepository;
  // late final MoodRepository moodRepository;
  // late final AiCoachRepository aiRepository;

  late final GraphPositionsRepository graphPositionsRepository;
  late final GraphNotesRepository graphNotesRepository;
  late final ObsidianRepository obsidianRepository;
  late final GraphBuilder graphBuilder;

  late final PulseScreenViewModel pulseScreenViewModel;
  late final TasksViewModel tasksViewModel;
  // late final MoodViewModel moodViewModel;
  late final ProjectsViewModel projectViewModel;
  // late final AiCoachViewModel aiCoachViewModel;
  late final GetTasksWithProjectsUseCase taskWithPrjct;
  late final HabitsViewModel habitsViewModel;
  late final ResourcesViewModel resourcesViewModel;

  void init() {
    database = AppDatabase();
    tasksDAO = TasksDao(database);
    projectsDao = ProjectsDao(database);
    spheresDao = SpheresDao(database);
    goalsDao = GoalsDao(database);
    // apiClient = ApiClient('https://api.motivator.com');
    // syncService = SyncService(apiClient, localDatabase);
    tasksRepository = TasksRepository(
      tasksDAO,
      //TaskLocalDS(localDatabase),
      // apiClient,
      // syncService,
    );
    projectsRepository = ProjectsRepository(projectsDao);
    spheresRepository = SpheresRepository(spheresDao);
    goalsRepository = GoalsRepository(goalsDao);
    habitsDao = HabitsDao(database);
    habitsRepository = HabitsRepository(habitsDao);
    // moodRepository = MoodRepository(
    //   MoodLocalDS(localDatabase),
    //   apiClient,
    // );
    obsidianRepository = ObsidianRepository();
    // obsidianRepository.scanVault(SettingsService.obsidianVaultPath.value, (){},(e){});
    // SettingsService.obsidianVaultPath.addListener(() {
    //   obsidianRepository.scanVault(SettingsService.obsidianVaultPath.value, (){},(e){} );
    // });

    graphPositionsRepository = GraphPositionsRepository();
    graphNotesRepository = GraphNotesRepository(
      obsidianRepository: obsidianRepository,
    );
    graphNotesRepository.init();

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
      obsidianRepository: obsidianRepository,
    );
    pulseScreenViewModel.initialize();

    taskWithPrjct = GetTasksWithProjectsUseCase(
      tasksRepository,
      projectsRepository,
    );

    // aiRepository = AiCoachRepository(apiClient);
    tasksViewModel = TasksViewModel(
      tasksRepository,
      taskWithPrjct,
      projectsRepository,
    );
    tasksViewModel.initialize();

    projectViewModel = ProjectsViewModel(
      repository: projectsRepository,
      taskRepo: tasksRepository,
    );
    projectViewModel.initialize();

    habitsViewModel = HabitsViewModel(habitsRepository);
    habitsViewModel.initialize();
    resourcesViewModel = ResourcesViewModel(
      graphNotesRepo: graphNotesRepository,
      obsidianRepo: obsidianRepository,
    );

    //resourcesViewModel.scanVault(SettingsService.obsidianVaultPath.value);
    SettingsService.obsidianVaultPath.addListener(() {
      resourcesViewModel.scanVault(SettingsService.obsidianVaultPath.value);
    });
    // moodViewModel = MoodViewModel(moodRepository, AiMoodAnalyzer(apiClient));
    // aiCoachViewModel = AiCoachViewModel(aiRepository);
  }

  void dispose() {
    _routineRepository?.dispose();
    _routineRepository = null;
    tasksViewModel.dispose();
    projectViewModel.dispose();
    habitsViewModel.dispose();
    pulseScreenViewModel.dispose();
    database.close();
  }
}
