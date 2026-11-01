import 'dart:async';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:rxdart/rxdart.dart';
import 'projects_state.dart';

class ProjectsViewModel {
  ProjectsViewModel({required this._repository, required this._taskRepo});
  final ProjectsApi _repository;
  final TasksApi _taskRepo;
  final _states = BehaviorSubject<ProjectsScreenState>.seeded(
    const ProjectsLoading(),
  );
  Stream<ProjectsScreenState> get state => _states.stream;
  StreamSubscription<List<Project>>? _subscription;
  bool _initialized = false;
  bool _accepting = true;
  bool _disposed = false;
  Future<void> _operations = Future.value();
  Future<void>? _closing;

  void initialize() {
    _requireActive();
    if (_initialized) return;
    _initialized = true;
    _subscription = _repository.watchAllProjects().listen(
      (values) {
        if (_disposed) return;
        final snapshot = List<Project>.unmodifiable(values);
        _states.add(
          ProjectsLoaded(
            projects: snapshot,
            curProject: snapshot.isEmpty ? null : snapshot.first,
          ),
        );
      },
      onError: (Object error) {
        if (!_disposed) {
          _states.add(ProjectsError('Failed to load project: $error'));
        }
      },
    );
  }

  void _requireActive() {
    if (!_accepting) throw StateError('Projects view model is closed.');
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    if (!_accepting) {
      return Future.error(StateError('Projects view model is closed.'));
    }
    final result = _operations.then((_) => operation());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<Project?> getProject(String id) =>
      _enqueue(() => _repository.getProjectById(id));
  Future<void> addProjects(Project project) =>
      _enqueue(() => _repository.addProject(project));
  Future<void> updateProject(Project project) =>
      _enqueue(() => _repository.updateProject(project));
  Future<void> deleteProject(String id) =>
      _enqueue(() => _repository.deleteProject(id));
  Future<void> updateTask(Task task) =>
      _enqueue(() => _taskRepo.updateTask(task));
  Stream<List<Task>> watchTaskByProject(String projectId) {
    _requireActive();
    return _taskRepo.watchTasksForProject(projectId);
  }

  Stream<List<Task>> watchAllTasks() {
    _requireActive();
    return _taskRepo.watchTasks();
  }

  /// Stops new operations and awaits accepted work before closing its stream.
  Future<void> dispose() => _closing ??= _dispose();
  Future<void> _dispose() async {
    _accepting = false;
    await _operations;
    try {
      await _subscription?.cancel();
    } finally {
      _disposed = true;
      await _states.close();
    }
  }
}
