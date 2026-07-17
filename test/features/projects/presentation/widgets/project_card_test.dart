import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';
import 'package:life_os/features/projects/presentation/widgets/project_card.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
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
      when(viewModel.watchTaskByProject(any)).thenAnswer((_) => taskStream.stream);
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
      taskStream.add([
        createMockTask(status: TaskStatus.done),
      ]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('shows "No tasks yet" when empty', (tester) async {
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('No tasks yet'), findsOneWidget);
    });

    testWidgets('shows task titles', (tester) async {
      taskStream.add([
        createMockTask(title: 'Task A'),
        createMockTask(title: 'Task B'),
      ]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsOneWidget);
    });

    testWidgets('calls onEditRequested from popup menu', (tester) async {
      bool editRequested = false;
      await tester.pumpWidget(MaterialApp(
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
      ));
      await tester.pump();

      final moreVert = find.byIcon(Icons.more_vert);
      final gesture = await tester.startGesture(tester.getCenter(moreVert));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Edit').last);
      await tester.pump();

      expect(editRequested, isTrue);
    });

    testWidgets('calls deleteProject from popup menu', (tester) async {
      when(viewModel.deleteProject(any)).thenAnswer((_) async => {});

      await tester.pumpWidget(MaterialApp(
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
      ));
      await tester.pump();

      final moreVert = find.byIcon(Icons.more_vert);
      final gesture = await tester.startGesture(tester.getCenter(moreVert));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Delete').last);
      await tester.pump();

      verify(viewModel.deleteProject(project.id)).called(1);
    });

    testWidgets('shows due date', (tester) async {
      final projectWithDueDate = Project.create(
        name: 'Due Project',
      ).copyWith(dueDate: Wrapped(DateTime(2024, 12, 31)));
      when(viewModel.watchTaskByProject(any)).thenAnswer((_) => taskStream.stream);

      await tester.pumpWidget(MaterialApp(
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
      ));
      await tester.pump();

      expect(find.textContaining('Due date'), findsOneWidget);
    });
  });
}
