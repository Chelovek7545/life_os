// core/di/dependency_container.dart
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
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
  late final GraphBuilder graphBuilder;
  late final LifeGraphViewModel lifeGraphViewModel;

  late final TasksViewModel tasksViewModel;
  // late final MoodViewModel moodViewModel;
  late final ProjectsViewModel projectViewModel;
  // late final AiCoachViewModel aiCoachViewModel;
  late final GetTasksWithProjectsUseCase taskWithPrjct;
  late final HabitsViewModel habitsViewModel;

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

    graphPositionsRepository = GraphPositionsRepository();
    graphNotesRepository = GraphNotesRepository();
    graphNotesRepository.init();
    graphBuilder = GraphBuilder(
      spheresRepository: spheresRepository,
      goalsRepository: goalsRepository,
      projectsRepository: projectsRepository,
      tasksRepository: tasksRepository,
    );
    lifeGraphViewModel = LifeGraphViewModel(
      spheresRepository: spheresRepository,
      goalsRepository: goalsRepository,
      projectsRepository: projectsRepository,
      tasksRepository: tasksRepository,
      positionsRepository: graphPositionsRepository,
      notesRepository: graphNotesRepository,
      graphBuilder: graphBuilder,
    );
    lifeGraphViewModel.initialize();

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
    // moodViewModel = MoodViewModel(moodRepository, AiMoodAnalyzer(apiClient));
    // aiCoachViewModel = AiCoachViewModel(aiRepository);
  }

  void dispose() {
    tasksViewModel.dispose();
    projectViewModel.dispose();
    habitsViewModel.dispose();
    lifeGraphViewModel.dispose();
    database.close();
  }
}
