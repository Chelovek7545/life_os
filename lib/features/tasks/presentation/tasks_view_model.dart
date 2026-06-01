import 'dart:async';

import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:rxdart/rxdart.dart';

class TasksViewModel {
  final TasksRepository _repository;

  TasksViewModel(this._repository);

  final BehaviorSubject<TaskScreenState> _uiStateController =
      BehaviorSubject<TaskScreenState>.seeded(const TasksLoading());
  Stream<TaskScreenState> get state => _uiStateController.stream;

  StreamSubscription<List<Task>>? _taskSubscription;
  //Stream<List<Task>> watchTasks() => _taskSubscription.;

  Future<Task?> getTask(String id) async => await _repository.getById(id);

  List<Task> _tasks = [];

  void initialize() {
    _taskSubscription = _repository.watchTasks().listen(
      _onTasksUpdated,
      onError: (Object error) {
        _uiStateController.add(TasksError('Failed to load tasks: $error'));
      },
    );
    
  }

  void _onTasksUpdated(List<Task> tasks) {
    _tasks = tasks;
    _emitUiState();
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task);
    await _emitUiState();
  }

  Future<void> toggleTask(Task task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await updateTask(updated);
  }

  Future<void> addTask(Task task) async {
    await _repository.addTask(task);
    await _emitUiState();
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
    await _emitUiState();
  }

  Future<void> _emitUiState() async {
    if (_tasks.isEmpty) {
      _uiStateController.add(TasksEmpty());
      return;
    }

    _uiStateController.add(TasksLoaded(curTask: _tasks[0], tasks: _tasks));
  }

  void dispose() {
    _taskSubscription?.cancel();
    _uiStateController.close();
  }
}
