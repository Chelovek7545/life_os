// core/di/dependency_container.dart
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';
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
  // late final ApiClient apiClient;
  // late final SyncService syncService;
  
  late final TasksRepository tasksRepository;
  // late final MoodRepository moodRepository;
  late final ProjectsRepository projectsRepository;
  // late final AiCoachRepository aiRepository;
  
  late final TasksViewModel tasksViewModel;
  // late final MoodViewModel moodViewModel;
  late final ProjectsViewModel projectViewModel;
  late final DashboardViewModel dashboardViewModel;
  // late final AiCoachViewModel aiCoachViewModel;
  late final GetTasksWithProjectsUseCase taskWithPrjct; 

  void init() {
    database = AppDatabase();
    tasksDAO = TasksDao(database);
    projectsDao = ProjectsDao(database);
    // apiClient = ApiClient('https://api.motivator.com');
    // syncService = SyncService(apiClient, localDatabase);
    tasksRepository = TasksRepository(
      tasksDAO
      //TaskLocalDS(localDatabase),
      // apiClient,
      // syncService,
    );
    projectsRepository = ProjectsRepository(
      projectsDao
    );
    // moodRepository = MoodRepository(
    //   MoodLocalDS(localDatabase),
    //   apiClient,
    // );
    
    taskWithPrjct = GetTasksWithProjectsUseCase(tasksRepository, projectsRepository);
    


    // aiRepository = AiCoachRepository(apiClient);
    dashboardViewModel = DashboardViewModel(tasksRepository, projectsRepository);
    dashboardViewModel.initialize();

    tasksViewModel = TasksViewModel(tasksRepository, taskWithPrjct, projectsRepository);
    tasksViewModel.initialize();
    
    projectViewModel = ProjectsViewModel(projectsRepository);
    projectViewModel.initialize();
    // moodViewModel = MoodViewModel(moodRepository, AiMoodAnalyzer(apiClient));
    // aiCoachViewModel = AiCoachViewModel(aiRepository);
  }
}