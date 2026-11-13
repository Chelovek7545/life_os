import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:projects_api/projects_api.dart' show Project;
import 'package:life_os/features/projects/presentation/projects_screen.dart';
import 'package:projects_plugin/projects_logic.dart'
    show
        ProjectsScreenState,
        ProjectsLoading,
        ProjectsLoaded,
        ProjectsError,
        ProjectsViewModel;
import 'package:life_os/features/projects/presentation/widgets/project_card.dart';
import 'package:tasks_api/tasks_api.dart' show Task, TaskStatus;
import 'package:rxdart/rxdart.dart';

import '../../../test_helpers.dart';

class FakeProjectsViewModel extends Fake implements ProjectsViewModel {
  final BehaviorSubject<ProjectsScreenState> _stateController;

  FakeProjectsViewModel({ProjectsScreenState? initialState})
    : _stateController = BehaviorSubject<ProjectsScreenState>.seeded(
        initialState ?? const ProjectsLoading(),
      );

  @override
  Stream<ProjectsScreenState> get state => _stateController.stream;

  @override
  void initialize() {}

  @override
  Stream<List<Task>> watchAllTasks() => taskController.stream;

  final taskController = BehaviorSubject<List<Task>>.seeded([]);

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await taskController.close();
  }

  @override
  Future<void> addProjects(Project project) async {}

  @override
  Future<void> updateProject(Project project) async {}

  @override
  Future<void> deleteProject(String id) async {}

  @override
  Future<Project?> getProject(String id) async => null;

  @override
  Stream<List<Task>> watchTaskByProject(String projectId) => Stream.value([]);

  @override
  Future<void> updateTask(covariant Task task) async {}
}

void main() {
  group('ProjectsScreen', () {
    late FakeProjectsViewModel viewModel;

    setUp(() {
      viewModel = FakeProjectsViewModel();
    });

    tearDown(() {
      viewModel.dispose();
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
        home: Scaffold(body: ProjectsScreen(viewModel: viewModel)),
      );
    }

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(createWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error message when state is error', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(const ProjectsError('Failed'));
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Failed'), findsOneWidget);
    });

    testWidgets('shows empty state when no projects', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(projects: [], curProject: null),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.pumpAndSettle();
      expect(find.text('Здесь будут ваши проекты'), findsOneWidget);
    });

    testWidgets('renders project cards when projects exist', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(
          projects: [
            createMockProject(name: 'Project A'),
            createMockProject(name: 'Project B'),
          ],
          curProject: null,
        ),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsNWidgets(2));
    });

    testWidgets('shows new project button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(projects: [], curProject: null),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Новый проект'), findsOneWidget);
      expect(find.byType(SegmentedPillControl), findsOneWidget);
    });

    testWidgets('tapping new project button shows edit form', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(projects: [], curProject: null),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.tap(find.text('Новый проект'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(EditProjectCard), findsOneWidget);
    });

    testWidgets('filters completion and archive and reacts to task updates', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final active = createMockProject(name: 'Active project');
      final completed = createMockProject(name: 'Completed project');
      final archived = createMockProject(
        name: 'Archived project',
      ).copyWith(isArchived: true);
      viewModel._stateController.add(
        ProjectsLoaded(projects: [active, completed, archived]),
      );
      viewModel.taskController.add([
        createMockTask(projectId: active.id),
        createMockTask(projectId: completed.id, status: TaskStatus.done),
      ]);
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsNWidgets(3));
      await tester.tap(find.text('Активные'));
      await tester.pumpAndSettle();
      expect(find.text('Active project'), findsOneWidget);
      expect(find.text('Completed project'), findsNothing);
      expect(find.text('Archived project'), findsNothing);
      await tester.tap(find.text('Завершённые'));
      await tester.pumpAndSettle();
      expect(find.text('Completed project'), findsOneWidget);
      expect(find.text('Active project'), findsNothing);
      viewModel.taskController.add([
        createMockTask(projectId: active.id, status: TaskStatus.done),
        createMockTask(projectId: completed.id, status: TaskStatus.done),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(ProjectCard), findsNWidgets(2));
      await tester.tap(find.text('Архив'));
      await tester.pumpAndSettle();
      expect(find.text('Archived project'), findsOneWidget);
      expect(find.byType(ProjectCard), findsOneWidget);
    });

    testWidgets('switches gallery rows to list without losing projects', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(
          projects: [
            createMockProject(name: 'Project A'),
            createMockProject(name: 'Project B'),
          ],
        ),
      );
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      final cards = find.byType(ProjectCard);
      expect(
        tester.getTopLeft(cards.at(0)).dy,
        tester.getTopLeft(cards.at(1)).dy,
      );
      await tester.tap(find.byTooltip('Список'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(cards.at(1)).dy,
        greaterThan(tester.getTopLeft(cards.at(0)).dy),
      );
      await tester.tap(find.byTooltip('Сетка'));
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(cards.at(0)).dy,
        tester.getTopLeft(cards.at(1)).dy,
      );
    });

    testWidgets('fits narrow screen with long project text and creation form', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(
          projects: [
            createMockProject(
              name: 'Очень длинное название проекта для проверки переноса',
              description: 'Подробное описание проекта ' * 20,
            ),
          ],
        ),
      );
      await tester.pumpWidget(createWidget());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ProjectCard), findsOneWidget);
      await tester.tap(find.text('Новый проект'));
      await tester.pumpAndSettle();
      expect(find.byType(EditProjectCard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders ProjectsScreen with title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(createWidget());

      expect(find.text('Проекты'), findsOneWidget);
    });
  });
}
