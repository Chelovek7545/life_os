import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';
import 'package:life_os/features/spheres/data/spheres_dao.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/goals/data/goals_dao.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

void main() {
  group('MyApp', () {
    testWidgets('renders MaterialApp with dark theme', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final tasksDao = TasksDao(db);
      final projectsDao = ProjectsDao(db);
      final spheresDao = SpheresDao(db);
      final goalsDao = GoalsDao(db);
      final tasksRepo = TasksRepository(tasksDao);
      final projectsRepo = ProjectsRepository(projectsDao);
      final spheresRepo = SpheresRepository(spheresDao);
      final goalsRepo = GoalsRepository(goalsDao);
      final positionsRepo = GraphPositionsRepository();
      final useCase = GetTasksWithProjectsUseCase(tasksRepo, projectsRepo);

      final graphBuilder = GraphBuilder(
        spheresRepository: spheresRepo,
        goalsRepository: goalsRepo,
        projectsRepository: projectsRepo,
        tasksRepository: tasksRepo,
      );

      final dc = DependencyContainer();
      dc.database = db;
      dc.tasksDAO = tasksDao;
      dc.projectsDao = projectsDao;
      dc.spheresDao = spheresDao;
      dc.goalsDao = goalsDao;
      dc.tasksRepository = tasksRepo;
      dc.projectsRepository = projectsRepo;
      dc.spheresRepository = spheresRepo;
      dc.goalsRepository = goalsRepo;
      dc.graphPositionsRepository = positionsRepo;
      dc.graphBuilder = graphBuilder;
      dc.lifeGraphViewModel = LifeGraphViewModel(
        spheresRepository: spheresRepo,
        goalsRepository: goalsRepo,
        projectsRepository: projectsRepo,
        tasksRepository: tasksRepo,
        positionsRepository: positionsRepo,
        graphBuilder: graphBuilder,
      );
      dc.lifeGraphViewModel.initialize();

      dc.taskWithPrjct = useCase;
      dc.tasksViewModel = TasksViewModel(tasksRepo, useCase, projectsRepo);
      dc.projectViewModel = ProjectsViewModel(
        repository: projectsRepo,
        taskRepo: tasksRepo,
      );

      await tester.pumpWidget(MyApp(diContainer: dc));
      await tester.pump();

      expect(find.byType(MyApp), findsOneWidget);

      await db.close();
    });
  });
}