import 'package:life_os/features/projects/presentation/widgets/project_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:core_contracts/core_contracts.dart' show Wrapped;
import 'package:projects_api/projects_api.dart' show Project;
import 'package:projects_plugin/projects_logic.dart' show ProjectsViewModel;
import 'package:tasks_api/tasks_api.dart' show Task, TaskStatus;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../test_helpers.dart';

import 'project_card_test.mocks.dart';

@GenerateMocks([ProjectsViewModel])
void main() {
  group('ProjectCard', () {
    late MockProjectsViewModel viewModel;
    late BehaviorSubject<List<Task>> taskStream;
    late Project project;

    setUp(() {
      viewModel = MockProjectsViewModel();
      taskStream = BehaviorSubject<List<Task>>.seeded([]);
      project = createMockProject(name: 'Test Project', color: '#FF0000');
      when(
        viewModel.watchTaskByProject(any),
      ).thenAnswer((_) => taskStream.stream);
    });

    tearDown(() {
      taskStream.close();
    });

    Widget createWidget() {
      return MaterialApp(
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: AppColors.surfaceDim,
          colorScheme: const ColorScheme.dark(
            surface: AppColors.surface,
            primary: AppColors.primary,
            onSurface: Colors.white,
          ),
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProjectCard(
              title: project.name,
              description: project.description,
              color: Colors.red,
              project: project,
              viewModel: viewModel,
              onEditRequested: () {},
              dueDate: project.dueDate,
            ),
          ),
        ),
      );
    }

    testWidgets('renders project name and description', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Test Project'), findsOneWidget);
    });

    testWidgets('shows 0% when no tasks', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('0%'), findsOneWidget);
    });

    testWidgets('shows progress based on completed tasks', (tester) async {
      taskStream.add([
        createMockTask(status: TaskStatus.done),
        createMockTask(status: TaskStatus.open),
      ]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('shows 100% when all tasks done', (tester) async {
      taskStream.add([createMockTask(status: TaskStatus.done)]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows "No tasks yet" when empty', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Нет задач'), findsOneWidget);
    });

    testWidgets('shows task titles', (tester) async {
      taskStream.add([
        createMockTask(title: 'Task A'),
        createMockTask(title: 'Task B'),
      ]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Task A'), findsNothing);
      await tester.tap(find.text('0 / 2 задач'));
      await tester.pumpAndSettle();
      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsOneWidget);
    });

    testWidgets('calls onEditRequested from popup menu', (tester) async {
      bool editRequested = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.surfaceDim,
            colorScheme: const ColorScheme.dark(
              surface: AppColors.surface,
              primary: AppColors.primary,
              onSurface: Colors.white,
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectCard(
                title: project.name,
                description: project.description,
                color: Colors.red,
                project: project,
                viewModel: viewModel,
                onEditRequested: () => editRequested = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final moreVert = find.byIcon(Icons.more_horiz_rounded);
      final gesture = await tester.startGesture(tester.getCenter(moreVert));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Редактировать').last);
      await tester.pump();

      expect(editRequested, isTrue);
    });

    testWidgets('calls deleteProject from popup menu', (tester) async {
      when(viewModel.deleteProject(any)).thenAnswer((_) async => {});

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.surfaceDim,
            colorScheme: const ColorScheme.dark(
              surface: AppColors.surface,
              primary: AppColors.primary,
              onSurface: Colors.white,
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectCard(
                title: project.name,
                description: project.description,
                color: Colors.red,
                project: project,
                viewModel: viewModel,
                onEditRequested: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final moreVert = find.byIcon(Icons.more_horiz_rounded);
      final gesture = await tester.startGesture(tester.getCenter(moreVert));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Удалить').last);
      await tester.pump();

      verify(viewModel.deleteProject(project.id)).called(1);
    });

    testWidgets('task details still allow completing a task', (tester) async {
      final task = createMockTask(title: 'Finish this task');
      taskStream.add([task]);
      when(viewModel.updateTask(any)).thenAnswer((_) async {});
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.text('0 / 1 задач'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      final updated =
          verify(viewModel.updateTask(captureAny)).captured.single as Task;
      expect(updated.id, task.id);
      expect(updated.status, TaskStatus.done);
    });

    testWidgets('archives project from menu', (tester) async {
      when(viewModel.updateProject(any)).thenAnswer((_) async {});
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.more_horiz_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('В архив'));
      await tester.pumpAndSettle();
      final updated =
          verify(viewModel.updateProject(captureAny)).captured.single
              as Project;
      expect(updated.id, project.id);
      expect(updated.isArchived, isTrue);
    });

    testWidgets('shows due date', (tester) async {
      final projectWithDueDate = Project.create(
        name: 'Due Project',
      ).copyWith(dueDate: Wrapped(DateTime(2024, 12, 31)));
      when(
        viewModel.watchTaskByProject(any),
      ).thenAnswer((_) => taskStream.stream);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            scaffoldBackgroundColor: AppColors.surfaceDim,
            colorScheme: const ColorScheme.dark(
              surface: AppColors.surface,
              primary: AppColors.primary,
              onSurface: Colors.white,
            ),
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ProjectCard(
                title: projectWithDueDate.name,
                description: projectWithDueDate.description,
                color: Colors.red,
                project: projectWithDueDate,
                viewModel: viewModel,
                onEditRequested: () {},
                dueDate: projectWithDueDate.dueDate,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('До '), findsOneWidget);
    });
  });
}
