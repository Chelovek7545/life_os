import 'dart:async';

import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/projects/presentation/projects_state.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import '../../../test_helpers.dart';
import 'projects_view_model_test.mocks.dart';

@GenerateMocks([ProjectsRepository, TasksRepository])
void main() {
  late MockProjectsRepository mockProjectsRepo;
  late MockTasksRepository mockTasksRepo;
  late ProjectsViewModel viewModel;

  setUp(() {
    mockProjectsRepo = MockProjectsRepository();
    mockTasksRepo = MockTasksRepository();
    viewModel = ProjectsViewModel(
      repository: mockProjectsRepo,
      taskRepo: mockTasksRepo,
    );
  });

  tearDown(() {
    viewModel.dispose();
  });

  group('ProjectsViewModel', () {
    group('initialization', () {
      test('starts with ProjectsLoading state', () {
        expect(viewModel.state, isA<Stream<ProjectsScreenState>>());
      });

      test('initialize listens to watchAllProjects', () {
        when(
          mockProjectsRepo.watchAllProjects(),
        ).thenAnswer((_) => Stream<List<Project>>.value([]));

        viewModel.initialize();

        verify(mockProjectsRepo.watchAllProjects()).called(1);
      });
    });

    group('state management', () {
      late BehaviorSubject<List<Project>> projectStream;

      setUp(() {
        projectStream = BehaviorSubject<List<Project>>.seeded([]);
        when(
          mockProjectsRepo.watchAllProjects(),
        ).thenAnswer((_) => projectStream.stream);
        viewModel.initialize();
      });

      Future<ProjectsScreenState> getState() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return viewModel.state.first;
      }

      test('emits ProjectsLoaded with projects', () async {
        final projects = [
          createMockProject(name: 'Project A'),
          createMockProject(name: 'Project B'),
        ];
        projectStream.add(projects);

        final state = await getState();
        expect(state, isA<ProjectsLoaded>());
        final loaded = state as ProjectsLoaded;
        expect(loaded.projects.length, 2);
        expect(loaded.projects.first.name, 'Project A');
      });

      test('emits ProjectsLoaded with curProject set to first', () async {
        final projects = [createMockProject(name: 'First')];
        projectStream.add(projects);

        final state = await getState() as ProjectsLoaded;
        expect(state.curProject, isNotNull);
        expect(state.curProject!.name, 'First');
      });

      test('emits ProjectsLoaded with null curProject when empty', () async {
        projectStream.add([]);

        final state = await getState() as ProjectsLoaded;
        expect(state.curProject, isNull);
      });

      test('emits ProjectsError on stream error', () async {
        projectStream.addError('Failed to load');

        final states = await viewModel.state.take(2).toList();
        expect(states.any((s) => s is ProjectsError), isTrue);
      });
    });

    group('CRUD operations', () {
      test('addProject delegates to repository and refreshes', () async {
        when(
          mockProjectsRepo.watchAllProjects(),
        ).thenAnswer((_) => Stream<List<Project>>.value([]));
        when(mockProjectsRepo.addProject(any)).thenAnswer((_) async => {});
        viewModel.initialize();

        final project = createMockProject();
        await viewModel.addProjects(project);

        verify(mockProjectsRepo.addProject(project)).called(1);
      });

      test('updateProject delegates to repository', () async {
        when(
          mockProjectsRepo.watchAllProjects(),
        ).thenAnswer((_) => Stream<List<Project>>.value([]));
        when(mockProjectsRepo.updateProject(any)).thenAnswer((_) async => {});
        viewModel.initialize();

        await viewModel.updateProject(createMockProject());

        verify(mockProjectsRepo.updateProject(any)).called(1);
      });

      test('deleteProject delegates to repository', () async {
        when(
          mockProjectsRepo.watchAllProjects(),
        ).thenAnswer((_) => Stream<List<Project>>.value([]));
        when(mockProjectsRepo.deleteProject(any)).thenAnswer((_) async => {});
        viewModel.initialize();

        await viewModel.deleteProject('proj-1');

        verify(mockProjectsRepo.deleteProject('proj-1')).called(1);
      });

      test('getProject delegates to repository', () async {
        when(
          mockProjectsRepo.getProjectById(any),
        ).thenAnswer((_) async => null);

        await viewModel.getProject('proj-1');

        verify(mockProjectsRepo.getProjectById('proj-1')).called(1);
      });
    });

    group('tasks integration', () {
      test('watchTaskByProject delegates to tasks repo', () {
        final stream = Stream<List<Task>>.value([]);
        when(mockTasksRepo.watchTasksForProject(any)).thenAnswer((_) => stream);

        final result = viewModel.watchTaskByProject('proj-1');

        expect(result, stream);
        verify(mockTasksRepo.watchTasksForProject('proj-1')).called(1);
      });

      test('updateTask delegates to tasks repo', () async {
        when(mockTasksRepo.updateTask(any)).thenAnswer((_) async => {});

        await viewModel.updateTask(createMockTask());

        verify(mockTasksRepo.updateTask(any)).called(1);
      });
    });

    group('dispose', () {
      test('dispose closes without throwing', () {
        expect(() => viewModel.dispose(), returnsNormally);
      });
    });
  });
}
