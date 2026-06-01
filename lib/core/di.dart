// core/di/dependency_container.dart
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

class DependencyContainer {
  static final DependencyContainer _instance = DependencyContainer._internal();
  factory DependencyContainer() => _instance;
  DependencyContainer._internal();

  late final TasksDao tasksDAO;
  // late final LocalDatabase localDatabase;
  // late final ApiClient apiClient;
  // late final SyncService syncService;
  
  late final TasksRepository tasksRepository;
  // late final MoodRepository moodRepository;
  // late final ProjectRepository projectRepository;
  // late final AiCoachRepository aiRepository;
  
  late final TasksViewModel tasksViewModel;
  // late final MoodViewModel moodViewModel;
  // late final ProjectViewModel projectViewModel;
  // late final AiCoachViewModel aiCoachViewModel;

  void init() {
    tasksDAO = TasksDao();
    // localDatabase = LocalDatabase();
    // apiClient = ApiClient('https://api.motivator.com');
    // syncService = SyncService(apiClient, localDatabase);
    
    tasksRepository = TasksRepository(
      tasksDAO
      //TaskLocalDS(localDatabase),
      // apiClient,
      // syncService,
    );
    
    // moodRepository = MoodRepository(
    //   MoodLocalDS(localDatabase),
    //   apiClient,
    // );
    
    // aiRepository = AiCoachRepository(apiClient);
    
    tasksViewModel = TasksViewModel(tasksRepository);
    tasksViewModel.initialize();
    // moodViewModel = MoodViewModel(moodRepository, AiMoodAnalyzer(apiClient));
    // aiCoachViewModel = AiCoachViewModel(aiRepository);
  }
}