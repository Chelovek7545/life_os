import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/dashboard/data/dashboard_widgets_dao.dart';
import 'package:life_os/features/dashboard/data/dashboard_widgets_repository.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';
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
      final dashboardWidgetsDao = DashboardWidgetsDao(db);
      final tasksRepo = TasksRepository(tasksDao);
      final projectsRepo = ProjectsRepository(projectsDao);
      final dashboardWidgetsRepo = DashboardWidgetsRepository(dashboardWidgetsDao);
      final useCase = GetTasksWithProjectsUseCase(tasksRepo, projectsRepo);

      final dc = DependencyContainer();
      dc.database = db;
      dc.tasksDAO = tasksDao;
      dc.projectsDao = projectsDao;
      dc.dashboardWidgetsDao = dashboardWidgetsDao;
      dc.tasksRepository = tasksRepo;
      dc.projectsRepository = projectsRepo;
      dc.dashboardWidgetsRepository = dashboardWidgetsRepo;
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
