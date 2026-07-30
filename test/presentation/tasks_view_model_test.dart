import 'dart:async';

import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import '../test_helpers.dart';
import 'tasks_view_model_test.mocks.dart';

@GenerateMocks([
  TasksRepository,
  GetTasksWithProjectsUseCase,
  ProjectsRepository,
])
void main() {
  late MockTasksRepository mockRepository;
  late MockGetTasksWithProjectsUseCase mockUseCase;
  late MockProjectsRepository mockProjectsRepository;
  late TasksViewModel viewModel;
  late List<TaskScreenState> emittedStates;
  late StreamSubscription<TaskScreenState> _stateSub;

  setUp(() {
    mockRepository = MockTasksRepository();
    mockUseCase = MockGetTasksWithProjectsUseCase();
    mockProjectsRepository = MockProjectsRepository();
    viewModel = TasksViewModel(
      mockRepository,
      mockUseCase,
      mockProjectsRepository,
    );
    emittedStates = [];
    _stateSub = viewModel.state.listen(emittedStates.add);
  });

  tearDown(() {
    _stateSub.cancel();
    viewModel.dispose();
  });

  Future<TaskScreenState> latestState() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return emittedStates.last;
  }

  group('TasksViewModel', () {
    group('initialization', () {
      test('initialize sets up combineLatest subscription', () {
        final taskStream = BehaviorSubject<List<TaskWithProject>>.seeded([]);
        when(mockUseCase.call()).thenAnswer((_) => taskStream.stream);

        viewModel.initialize();

        verify(mockUseCase.call()).called(1);
      });
    });

    group('filter logic', () {
      late BehaviorSubject<List<TaskWithProject>> taskStream;
      late DateTime today;

      setUp(() {
        taskStream = BehaviorSubject<List<TaskWithProject>>.seeded([]);
        when(mockUseCase.call()).thenAnswer((_) => taskStream.stream);
        today = DateTime.now().startOfDay;
        viewModel.initialize();
      });

      void emitTasks(List<TaskWithProject> tasks) {
        taskStream.add(tasks);
      }

      // Helper to create task with time
      TaskWithProject taskAt(
        DateTime date,
        int hour, {
        int endHour = 10,
        String? projectId,
        List<Tag>? tags,
        TaskStatus? status,
      }) {
        final start = date.atTime(hour);
        final end = date.atTime(endHour);
        return createMockTaskWithProject(
          task: createTaskWithTimes(
            start: start,
            end: end,
            projectId: projectId,
            tags: tags,
            status: status,
          ),
        );
      }

      test('emits TasksLoading initially', () async {
        // The viewModel starts with TasksLoading, but the empty taskStream
        // immediately triggers _handleDataUpdate which emits TasksEmpty.
        final state = await latestState();
        expect(state, isA<TasksEmpty>());
      });

      test('emits TasksEmpty when no tasks', () async {
        emitTasks([]);
        final state = await latestState();
        expect(state, isA<TasksEmpty>());
      });

      test('filters by day period - only today tasks', () async {
        final tomorrow = today.add(const Duration(days: 1));
        final tasks = [taskAt(today, 9), taskAt(tomorrow, 9)];
        emitTasks(tasks);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 1);
      });

      test('filters by week period - tasks in same week', () async {
        viewModel.updateFilter((c) => c.copyWith(period: DatePeriod.week));

        final mondayThisWeek = getWeekStart(today);
        final fridayThisWeek = mondayThisWeek.add(const Duration(days: 4));
        final mondayNextWeek = mondayThisWeek.add(const Duration(days: 7));

        final tasks = [
          taskAt(mondayThisWeek, 9),
          taskAt(fridayThisWeek, 14),
          taskAt(mondayNextWeek, 9),
        ];
        emitTasks(tasks);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 2);
      });

      test('filters by month period - tasks in same month', () async {
        viewModel.updateFilter((c) => c.copyWith(period: DatePeriod.month));

        final nextMonth = DateTime(today.year, today.month + 1, 1);
        final tasks = [taskAt(today, 9), taskAt(nextMonth, 9)];
        emitTasks(tasks);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 1);
      });

      test('filters by year period - tasks in same year', () async {
        viewModel.updateFilter((c) => c.copyWith(period: DatePeriod.year));

        final nextYear = DateTime(today.year + 1, 1, 1);
        final tasks = [taskAt(today, 9), taskAt(nextYear, 9)];
        emitTasks(tasks);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 1);
      });

      test('excludes tasks without startsAt when period is not day', () async {
        viewModel.updateFilter((c) => c.copyWith(period: DatePeriod.week));

        final tasks = [
          createMockTaskWithProject(task: createMockTask(startsAt: null)),
          taskAt(today, 9),
        ];
        emitTasks(tasks);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 1);
      });

      test('filters by projectIds', () async {
        final projectA = createMockProject(id: 'proj-a');
        final projectB = createMockProject(id: 'proj-b');

        final tasks = [
          createMockTaskWithProject(
            task: taskAt(today, 9).task.copyWith(projectId: Wrapped('proj-a')),
            project: projectA,
          ),
          createMockTaskWithProject(
            task: taskAt(today, 14).task.copyWith(projectId: Wrapped('proj-b')),
            project: projectB,
          ),
        ];
        emitTasks(tasks);

        viewModel.updateFilter((c) => c.copyWith(projectIds: ['proj-a']));

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 1);
        expect((state as TasksLoaded).tasks.first.task.projectId, 'proj-a');
      });

      test('filters by tagIds - includes if ANY tag matches', () async {
        viewModel.updateFilter(
          (c) => c.copyWith(period: DatePeriod.week, tagIds: [1]),
        );

        final mondayThisWeek = getWeekStart(today);
        final tasks = [
          taskAt(mondayThisWeek, 9, tags: [createMockTag(id: 1)]),
          taskAt(mondayThisWeek, 14, tags: [createMockTag(id: 2)]),
          taskAt(
            mondayThisWeek.add(const Duration(days: 1)),
            9,
            tags: [createMockTag(id: 1), createMockTag(id: 2)],
          ),
        ];
        emitTasks(tasks);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 2);
        expect(
          (state as TasksLoaded).tasks
              .every((t) => t.task.tags.any((tag) => tag.id == 1)),
          isTrue,
        );
      });

      test('filters by showCompleted true - only completed', () async {
        final tasks = [
          taskAt(today, 9, status: TaskStatus.done),
          taskAt(today, 14, status: TaskStatus.inProgress),
        ];
        emitTasks(tasks);

        viewModel.updateFilter((c) => c.copyWith(showCompleted: () => true));

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 1);
        expect((state as TasksLoaded).tasks.first.task.isCompleted, isTrue);
      });

      test('filters by showCompleted false - only active', () async {
        final tasks = [
          taskAt(today, 9, status: TaskStatus.done),
          taskAt(today, 14, status: TaskStatus.inProgress),
        ];
        emitTasks(tasks);

        viewModel.updateFilter((c) => c.copyWith(showCompleted: () => false));

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).tasks.length, 1);
        expect((state as TasksLoaded).tasks.first.task.isCompleted, isFalse);
      });
    });

    group('state management', () {
      late BehaviorSubject<List<TaskWithProject>> taskStream;
      late DateTime today;

      setUp(() {
        taskStream = BehaviorSubject<List<TaskWithProject>>.seeded([]);
        when(mockUseCase.call()).thenAnswer((_) => taskStream.stream);
        today = DateTime.now().startOfDay;
        viewModel.initialize();
      });

      test('updateFilter updates filter and re-emits state', () async {
        final tasks = [
          createMockTaskWithProject(
            task: createTaskWithTimes(start: today.atTime(9)),
          ),
        ];
        taskStream.add(tasks);

        viewModel.updateFilter((c) => c.copyWith(period: DatePeriod.week));

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
      });

      test('resetFilters resets to day period, keeps anchorDate', () {
        viewModel.updateFilter(
          (c) => c.copyWith(period: DatePeriod.month, projectIds: ['p1']),
        );
        viewModel.resetFilters();

        final filter = viewModel.currentFilterValue;
        expect(filter.period, DatePeriod.day);
        expect(filter.projectIds, isEmpty);
        expect(filter.anchorDate, isNotNull);
      });

      test('toggleTaskSelection adds task to selectedTasks', () async {
        final task = createMockTaskWithProject(
          task: createTaskWithTimes(start: today.atTime(9)),
        );
        taskStream.add([task]);

        viewModel.toggleTaskSelection(task.task);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).selectedTasks.length, 1);
        expect((state as TasksLoaded).selectedTasks.first.id, task.task.id);
      });

      test('toggleTaskSelection removes task from selectedTasks', () async {
        final task = createMockTaskWithProject(
          task: createTaskWithTimes(start: today.atTime(9)),
        );
        taskStream.add([task]);
        viewModel.toggleTaskSelection(task.task);

        viewModel.toggleTaskSelection(task.task);

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).selectedTasks, isEmpty);
      });

      test('showForm/hideForm controls form visibility', () async {
        viewModel.showForm();
        expect((await viewModel.uiFlags.first).isFormVisible, isTrue);
        expect(viewModel.shouldRenderForm, isTrue);

        viewModel.hideForm();
        expect((await viewModel.uiFlags.first).isFormVisible, isFalse);
      });

      test('disableForm resets form state', () {
        viewModel.showForm();
        viewModel.startEditingTask(createMockTaskWithProject());
        viewModel.disableForm();

        expect(viewModel.shouldRenderForm, isFalse);
        expect(viewModel.activeTaskWithProject, isNull);
      });

      test('startEditingTask sets active task', () {
        final item = createMockTaskWithProject();
        viewModel.startEditingTask(item);

        expect(viewModel.activeTaskWithProject, item);
      });

      test('clearTaskSelection clears selectedTasks and re-emits state', () async {
        final task = createMockTaskWithProject(
          task: createTaskWithTimes(start: today.atTime(9)),
        );
        taskStream.add([task]);
        viewModel.toggleTaskSelection(task.task);

        viewModel.clearTaskSelection();

        final state = await latestState();
        expect(state, isA<TasksLoaded>());
        expect((state as TasksLoaded).selectedTasks, isEmpty);
      });

      test('draftTask resets to blank after hideForm', () {
        viewModel.showForm();
        viewModel.draftTask = createMockTask(title: 'Custom Draft');
        viewModel.hideForm();

        expect(viewModel.draftTask.title, 'Untitled');
        expect(viewModel.draftTask.description, isEmpty);
        expect(viewModel.draftTask.status, TaskStatus.open);
      });

      test('deleteSelectedTask deletes each selected task', () async {
        final task1 = createMockTaskWithProject(
          task: createTaskWithTimes(start: today.atTime(9)),
        );
        final task2 = createMockTaskWithProject(
          task: createTaskWithTimes(start: today.atTime(14)),
        );
        taskStream.add([task1, task2]);
        when(mockRepository.deleteTask(any)).thenAnswer((_) async => {});
        viewModel.toggleTaskSelection(task1.task);
        viewModel.toggleTaskSelection(task2.task);

        await viewModel.deleteSelectedTask();

        verify(mockRepository.deleteTask(task1.task.id)).called(1);
        verify(mockRepository.deleteTask(task2.task.id)).called(1);
      });

      test('markSelectedAsDone updates each selected task', () async {
        final task1 = createMockTaskWithProject(
          task: createTaskWithTimes(
            start: today.atTime(9),
            status: TaskStatus.open,
          ),
        );
        final task2 = createMockTaskWithProject(
          task: createTaskWithTimes(
            start: today.atTime(14),
            status: TaskStatus.open,
          ),
        );
        taskStream.add([task1, task2]);
        when(mockRepository.updateTask(any)).thenAnswer((_) async => {});
        viewModel.toggleTaskSelection(task1.task);
        viewModel.toggleTaskSelection(task2.task);

        await viewModel.markSelectedAsDone();

        verify(mockRepository.updateTask(
          argThat(predicate<Task>((t) => t.id == task1.task.id && t.status == TaskStatus.done)),
        )).called(1);
        verify(mockRepository.updateTask(
          argThat(predicate<Task>((t) => t.id == task2.task.id && t.status == TaskStatus.done)),
        )).called(1);
      });
    });

    group('CRUD operations', () {
      test('getTask delegates to repository', () async {
        final task = createMockTask();
        when(mockRepository.getById('task-1'))
            .thenAnswer((_) async => task);

        final result = await viewModel.getTask('task-1');

        expect(result, task);
        verify(mockRepository.getById('task-1')).called(1);
      });

      test('getTask returns null when not found', () async {
        when(mockRepository.getById('missing'))
            .thenAnswer((_) async => null);

        final result = await viewModel.getTask('missing');

        expect(result, isNull);
      });

      test('addTask delegates to repository', () async {
        final task = createMockTask();
        when(mockRepository.addTask(any)).thenAnswer((_) async => {});

        await viewModel.addTask(task);

        verify(
          mockRepository.addTask(
            argThat(
              predicate<Task>((t) => t.id == task.id && t.title == task.title),
            ),
          ),
        ).called(1);
      });

      test('updateTask delegates to repository', () async {
        final task = createMockTask();
        when(mockRepository.updateTask(any)).thenAnswer((_) async => {});

        await viewModel.updateTask(task);

        verify(mockRepository.updateTask(task)).called(1);
      });

      test('toggleTask toggles status and calls updateTask', () async {
        final task = createMockTask(status: TaskStatus.open);
        when(mockRepository.updateTask(any)).thenAnswer((_) async => {});

        await viewModel.toggleTask(task);

        verify(
          mockRepository.updateTask(
            argThat(predicate<Task>((t) => t.status == TaskStatus.done)),
          ),
        ).called(1);
      });

      test('deleteTask delegates to repository', () async {
        when(mockRepository.deleteTask('task-1')).thenAnswer((_) async => {});

        await viewModel.deleteTask('task-1');

        verify(mockRepository.deleteTask('task-1')).called(1);
      });
    });

    group('projects', () {
      test('watchProjects delegates to projects repository', () {
        final stream = Stream<List<Project>>.value([]);
        when(
          mockProjectsRepository.watchAllProjects(),
        ).thenAnswer((_) => stream);

        final result = viewModel.watchProjects();

        expect(result, stream);
        verify(mockProjectsRepository.watchAllProjects()).called(1);
      });
    });

    group('dispose', () {
      test('disposes without throwing', () {
        final taskStream = BehaviorSubject<List<TaskWithProject>>.seeded([]);
        when(mockUseCase.call()).thenAnswer((_) => taskStream.stream);

        viewModel.initialize();
        expect(() => viewModel.dispose(), returnsNormally);
      });
    });
  });
}
