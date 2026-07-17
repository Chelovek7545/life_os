import 'dart:async';

import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:mockito/mockito.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

import '../../../../test_helpers.dart';

class FakeTasksRepo extends Fake implements TasksRepository {
  final BehaviorSubject<List<Task>> _controller;
<<<<<<< HEAD
  FakeTasksRepo(List<Task> initial)
    : _controller = BehaviorSubject.seeded(initial);

  void addTasks(List<Task> tasks) => _controller.add(tasks);
  @override
  Stream<List<Task>> watchTasks() => _controller.stream;
  @override
  Future<void> addTask(Task task) async {}
  @override
  Future<void> deleteTask(String id) async {}
  @override
  Future<Task?> getById(String id) async => null;
  @override
  Future<void> updateTask(Task task) async {}
  @override
  Stream<List<Task>> watchTasksForProject(String projectId) =>
      _controller.stream;
=======
  FakeTasksRepo(List<Task> initial) : _controller = BehaviorSubject.seeded(initial);

  void addTasks(List<Task> tasks) => _controller.add(tasks);
  @override Stream<List<Task>> watchTasks() => _controller.stream;
  @override Future<void> addTask(Task task) async {}
  @override Future<void> deleteTask(String id) async {}
  @override Future<Task?> getById(String id) async => null;
  @override Future<void> updateTask(Task task) async {}
  @override Stream<List<Task>> watchTasksForProject(String projectId) => _controller.stream;
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791
  Future<void> close() => _controller.close();
}

class FakeProjectsRepo extends Fake implements ProjectsRepository {
  final BehaviorSubject<List<Project>> _controller;
<<<<<<< HEAD
  FakeProjectsRepo(List<Project> initial)
    : _controller = BehaviorSubject.seeded(initial);

  void addProjects(List<Project> projects) => _controller.add(projects);
  @override
  Stream<List<Project>> watchAllProjects() => _controller.stream;
  @override
  Future<void> addProject(Project project) async {}
  @override
  Future<void> deleteProject(String id) async {}
  @override
  Future<List<Project>> getAllProjects() async => [];
  @override
  Future<Project?> getProjectById(String id) async => null;
  @override
  Future<void> updateProject(Project project) async {}
=======
  FakeProjectsRepo(List<Project> initial) : _controller = BehaviorSubject.seeded(initial);

  void addProjects(List<Project> projects) => _controller.add(projects);
  @override Stream<List<Project>> watchAllProjects() => _controller.stream;
  @override Future<void> addProject(Project project) async {}
  @override Future<void> deleteProject(String id) async {}
  @override Future<List<Project>> getAllProjects() async => [];
  @override Future<Project?> getProjectById(String id) async => null;
  @override Future<void> updateProject(Project project) async {}
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791
  Future<void> close() => _controller.close();
}

void main() {
  group('GetTasksWithProjectsUseCase', () {
    late FakeTasksRepo fakeTaskRepo;
    late FakeProjectsRepo fakeProjectRepo;
    late GetTasksWithProjectsUseCase useCase;

    setUp(() {
      fakeTaskRepo = FakeTasksRepo([]);
      fakeProjectRepo = FakeProjectsRepo([]);
      useCase = GetTasksWithProjectsUseCase(fakeTaskRepo, fakeProjectRepo);
    });

    tearDown(() async {
      await fakeTaskRepo.close();
      await fakeProjectRepo.close();
    });

    test('emits empty list when no tasks or projects', () async {
      final result = useCase.call();
      final collected = <List<TaskWithProject>>[];
      final sub = result.listen(collected.add);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(collected.length, 1);
      expect(collected.first, isEmpty);

      await sub.cancel();
    });

    test('matches tasks to their projects by projectId', () async {
      final project = createMockProject(id: 'proj-1', name: 'My Project');
      final task = createMockTask(projectId: 'proj-1', title: 'Task 1');

      fakeTaskRepo.addTasks([task]);
      fakeProjectRepo.addProjects([project]);

      final result = useCase.call();
      final collected = <List<TaskWithProject>>[];
      final sub = result.listen(collected.add);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(collected.last.length, 1);
      expect(collected.last.first.task.id, task.id);
      expect(collected.last.first.project?.id, 'proj-1');
      expect(collected.last.first.project?.name, 'My Project');

      await sub.cancel();
    });

    test('sets project to null when no matching project', () async {
      final task = createMockTask(projectId: 'nonexistent', title: 'Task 1');

      fakeTaskRepo.addTasks([task]);

      final result = useCase.call();
      final collected = <List<TaskWithProject>>[];
      final sub = result.listen(collected.add);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(collected.last.length, 1);
      expect(collected.last.first.project, isNull);

      await sub.cancel();
    });

    test('re-emits when task stream updates', () async {
      final result = useCase.call();
      final collected = <List<TaskWithProject>>[];
      final sub = result.listen(collected.add);
      await Future.delayed(const Duration(milliseconds: 50));

      fakeTaskRepo.addTasks([createMockTask(projectId: 'proj-1')]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(collected.length, 2);
      expect(collected.last.length, 1);

      await sub.cancel();
    });

    test('re-emits when project stream updates', () async {
      final result = useCase.call();
      final collected = <List<TaskWithProject>>[];
      final sub = result.listen(collected.add);
      await Future.delayed(const Duration(milliseconds: 50));

      fakeProjectRepo.addProjects([createMockProject(id: 'proj-1')]);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(collected.length, 2);

      await sub.cancel();
    });

    test('handles task with null projectId', () async {
      final task = createMockTask(projectId: null, title: 'No project');

      fakeTaskRepo.addTasks([task]);

      final result = useCase.call();
      final collected = <List<TaskWithProject>>[];
      final sub = result.listen(collected.add);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(collected.last.length, 1);
      expect(collected.last.first.project, isNull);

      await sub.cancel();
    });
  });
}
