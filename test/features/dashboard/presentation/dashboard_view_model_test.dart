import 'dart:async';

import 'package:life_os/features/dashboard/presentation/dashboard_screen_state.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_view_model.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';

import '../../../test_helpers.dart';
import 'dashboard_view_model_test.mocks.dart';

@GenerateMocks([TasksRepository, ProjectsRepository])
void main() {
  late MockTasksRepository mockTaskRepo;
  late MockProjectsRepository mockProjectRepo;
  late DashboardViewModel viewModel;
  late List<DashboardScreenState> emittedStates;
  late StreamSubscription<DashboardScreenState> _stateSub;

  setUp(() {
    mockTaskRepo = MockTasksRepository();
    mockProjectRepo = MockProjectsRepository();
    viewModel = DashboardViewModel(mockTaskRepo, mockProjectRepo);
    emittedStates = [];
    _stateSub = viewModel.state.listen(emittedStates.add);
  });

  tearDown(() {
    _stateSub.cancel();
    viewModel.dispose();
  });

  group('DashboardViewModel', () {
    test('initial state is DashboardScreenLoading', () {
      expect(emittedStates.first, isA<DashboardScreenLoading>());
    });

    test('emits DashboardScreenLoaded with counts', () async {
      final tasks = [createMockTask(), createMockTask()];
      final projects = [createMockProject()];

      when(mockTaskRepo.watchTasks()).thenAnswer((_) => Stream.value(tasks));
      when(mockProjectRepo.watchAllProjects())
          .thenAnswer((_) => Stream.value(projects));

      viewModel.initialize();
      await Future.delayed(Duration.zero);

      final state = emittedStates.last;
      expect(state, isA<DashboardScreenLoaded>());
      final loaded = state as DashboardScreenLoaded;
      expect(loaded.items.length, 2);
      expect(loaded.items[0].title, 'Tasks');
      expect(loaded.items[0].value, '2');
      expect(loaded.items[1].title, 'Projects');
      expect(loaded.items[1].value, '1');
    });

    test('emits DashboardScreenLoaded with zero counts', () async {
      when(mockTaskRepo.watchTasks()).thenAnswer((_) => Stream.value([]));
      when(mockProjectRepo.watchAllProjects())
          .thenAnswer((_) => Stream.value([]));

      viewModel.initialize();
      await Future.delayed(Duration.zero);

      final state = emittedStates.last;
      expect(state, isA<DashboardScreenLoaded>());
      final loaded = state as DashboardScreenLoaded;
      expect(loaded.items[0].value, '0');
      expect(loaded.items[1].value, '0');
    });

    test('emits DashboardScreenError on stream error', () async {
      when(mockTaskRepo.watchTasks())
          .thenAnswer((_) => Stream.error('db error'));
      when(mockProjectRepo.watchAllProjects())
          .thenAnswer((_) => Stream.value([]));

      viewModel.initialize();
      await Future.delayed(Duration.zero);

      final state = emittedStates.last;
      expect(state, isA<DashboardScreenError>());
    });
  });
}
