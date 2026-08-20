import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/habits/data/habits_repository.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
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
  testWidgets('toggle works in the full app', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final tasksDao = TasksDao(db);
    final projectsDao = ProjectsDao(db);
    final spheresDao = SpheresDao(db);
    final goalsDao = GoalsDao(db);
    final habitsDao = HabitsDao(db);
    final tasksRepo = TasksRepository(tasksDao);
    final projectsRepo = ProjectsRepository(projectsDao);
    final spheresRepo = SpheresRepository(spheresDao);
    final goalsRepo = GoalsRepository(goalsDao);
    final habitsRepo = HabitsRepository(habitsDao);
    final positionsRepo = GraphPositionsRepository();
    final useCase = GetTasksWithProjectsUseCase(tasksRepo, projectsRepo);

    final weekday = DateTime.now().weekday;
    await habitsRepo.addHabit(
      Habit.create(
        title: 'Read',
        type: const MorningHabit(),
        schedule: HabitSchedule(daysOfWeek: [weekday]),
      ),
    );

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
    dc.habitsDao = habitsDao;
    dc.tasksRepository = tasksRepo;
    dc.projectsRepository = projectsRepo;
    dc.spheresRepository = spheresRepo;
    dc.goalsRepository = goalsRepo;
    dc.habitsRepository = habitsRepo;
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
    dc.habitsViewModel = HabitsViewModel(habitsRepo);

    await tester.pumpWidget(MyApp(diContainer: dc));
    await tester.pump();
    await tester.pump();

    expect(find.text('Read'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    await tester.tap(find.byTooltip('Toggle'));
    await tester.pump();

    var checkmarks = find.byIcon(Icons.check_circle_rounded).evaluate().length;
    var pumps = 1;
    while (checkmarks == 0 && pumps < 20) {
      await tester.pump();
      pumps++;
      checkmarks = find.byIcon(Icons.check_circle_rounded).evaluate().length;
    }

    expect(
      checkmarks,
      1,
      reason: 'checkmark should appear after $pumps pump(s)',
    );
    debugPrint('FULL APP: CHECKMARK APPEARED AFTER $pumps PUMP(S)');

    dc.habitsViewModel.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await db.close();
  });
}
