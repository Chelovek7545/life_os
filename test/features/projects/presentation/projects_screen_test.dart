import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
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
import 'package:tasks_api/tasks_api.dart' show Task;
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
  Stream<List<Task>> watchAllTasks() => Stream.value([]);

  @override
  Future<void> dispose() async {
    _stateController.close();
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

      expect(find.text('No projects available yet.'), findsOneWidget);
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

      // Scroll down to render the second card (ListView is lazy)
      final listView = find.byType(ListView);
      await tester.drag(listView, const Offset(0, -500));
      await tester.pump();

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

      expect(find.text('New project'), findsOneWidget);
    });

    testWidgets('tapping new project button shows edit form', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      viewModel._stateController.add(
        ProjectsLoaded(projects: [], curProject: null),
      );
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.tap(find.text('New project'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(EditProjectCard), findsOneWidget);
    });

    testWidgets('renders ProjectsScreen with title', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(createWidget());

      expect(find.text('Projects'), findsOneWidget);
    });
  });
}
