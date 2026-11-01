import 'dart:async';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:rxdart/rxdart.dart';
import 'get_tasks_with_projects_use_case.dart';
import 'task_filter_config.dart';
import 'task_state.dart';
import 'package:plugin_runtime/owned_streams.dart';

class TasksUiFlags {
  const TasksUiFlags({this.isFormVisible = false, this.isEventMode = false});
  final bool isFormVisible;
  final bool isEventMode;
  TasksUiFlags copyWith({bool? isFormVisible, bool? isEventMode}) =>
      TasksUiFlags(
        isFormVisible: isFormVisible ?? this.isFormVisible,
        isEventMode: isEventMode ?? this.isEventMode,
      );
}

class TasksViewModel {
  TasksViewModel(this._repository, this._useCase, this._projects);
  final TasksApi _repository;
  final GetTasksWithProjectsUseCase _useCase;
  final ProjectsQueries _projects;
  final _states = BehaviorSubject<TaskScreenState>.seeded(const TasksLoading());
  final _flags = BehaviorSubject<TasksUiFlags>.seeded(const TasksUiFlags());
  final _filters = BehaviorSubject<TaskFilterConfig>.seeded(
    TaskFilterConfig(anchorDate: DateTime.now()),
  );
  final _queries = OwnedStreams();
  final _selected = <Task>[];
  List<Task> get selectedTasks => List.unmodifiable(_selected);
  Stream<TaskScreenState> get state => _states.stream;
  Stream<TasksUiFlags> get uiFlags => _flags.stream;
  TasksUiFlags get currentUiFlags => _flags.value;
  Stream<TaskFilterConfig> get currentFilter => _filters.stream;
  TaskFilterConfig get currentFilterValue => _filters.value;
  TaskWithProject? activeTaskWithProject;
  Task draftTask = Task.blank();
  bool shouldRenderForm = false;
  bool isEventMode = false;
  StreamSubscription<void>? _subscription;
  bool _initialized = false;
  bool _accepting = true;
  bool get isActive => _accepting;
  bool _disposed = false;
  Future<void> _operations = Future.value();
  Future<void>? _closing;

  void initialize() {
    if (!_accepting) throw StateError('Tasks view model is closed.');
    if (_initialized) return;
    _initialized = true;
    _subscription =
        Rx.combineLatest2<List<TaskWithProject>, TaskFilterConfig, void>(
          _useCase.call(),
          _filters.stream,
          _emit,
        ).listen(
          (_) {},
          onError: (Object error) {
            if (!_disposed) {
              _states.add(TasksError('Failed to load tasks: $error'));
            }
          },
        );
  }

  Future<T> _enqueue<T>(Future<T> Function() action) {
    if (!_accepting) {
      return Future.error(StateError('Tasks view model is closed.'));
    }
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void showForm() {
    if (!_accepting) return;
    shouldRenderForm = true;
    _flags.add(currentUiFlags.copyWith(isFormVisible: true));
  }

  void hideForm() {
    if (!_accepting) return;
    _flags.add(currentUiFlags.copyWith(isFormVisible: false));
    draftTask = Task.blank();
  }

  void disableForm() {
    if (!_accepting) return;
    shouldRenderForm = false;
    activeTaskWithProject = null;
  }

  void toggleEventMode() {
    if (_accepting) {
      _flags.add(
        currentUiFlags.copyWith(isEventMode: !currentUiFlags.isEventMode),
      );
    }
  }

  void updateFilter(TaskFilterConfig Function(TaskFilterConfig) updater) {
    if (_accepting) _filters.add(updater(_filters.value));
  }

  void resetFilters() =>
      updateFilter((old) => TaskFilterConfig(anchorDate: old.anchorDate));

  void _emit(List<TaskWithProject> tasks, TaskFilterConfig filter) {
    if (_disposed) return;
    final scheduled = <TaskWithProject>[];
    final unscheduled = <TaskWithProject>[];
    final anchor = DateTime(
      filter.anchorDate.year,
      filter.anchorDate.month,
      filter.anchorDate.day,
    );
    final week = DateTime(
      anchor.year,
      anchor.month,
      anchor.day - anchor.weekday + 1,
    );
    final weekEnd = DateTime(week.year, week.month, week.day + 7);
    for (final item in tasks) {
      final task = item.task;
      if (task.startsAt case final starts?) {
        final day = DateTime(starts.year, starts.month, starts.day);
        final matches = switch (filter.period) {
          DatePeriod.day => day == anchor,
          DatePeriod.week => !day.isBefore(week) && day.isBefore(weekEnd),
          DatePeriod.month =>
            day.year == anchor.year && day.month == anchor.month,
          DatePeriod.year => day.year == anchor.year,
        };
        if (!matches) continue;
      }
      if (filter.projectIds.isNotEmpty &&
          !filter.projectIds.contains(task.projectId)) {
        continue;
      }
      if (filter.tagIds.isNotEmpty &&
          !task.tags.any((tag) => filter.tagIds.contains(tag.id))) {
        continue;
      }
      if (filter.showCompleted != null &&
          task.isCompleted != filter.showCompleted) {
        continue;
      }
      (task.startsAt == null ? unscheduled : scheduled).add(item);
    }
    if (scheduled.isEmpty && unscheduled.isEmpty && _selected.isEmpty) {
      _states.add(const TasksEmpty());
    } else {
      _states.add(
        TasksLoaded(
          tasks: scheduled,
          unscheduledTasks: unscheduled,
          selectedTasks: _selected,
          curTask: scheduled.isEmpty ? null : scheduled.first.task,
        ),
      );
    }
  }

  void clearTaskSelection() {
    if (!_accepting) return;
    _selected.clear();
    _emitSelection();
  }

  void toggleTaskSelection(Task task) {
    if (!_accepting) return;
    _selected.any((item) => item.id == task.id)
        ? _selected.removeWhere((item) => item.id == task.id)
        : _selected.add(task);
    _emitSelection();
  }

  void _emitSelection() {
    if (_states.value case final TasksLoaded current) {
      _states.add(
        TasksLoaded(
          tasks: current.tasks,
          unscheduledTasks: current.unscheduledTasks,
          selectedTasks: _selected,
          curTask: current.curTask,
        ),
      );
    }
  }

  void startEditingTask(TaskWithProject item) {
    if (!_accepting) return;
    activeTaskWithProject = item;
    draftTask = item.task;
  }

  void openTaskInEditor(Task task) {
    if (!_accepting) return;
    if (task.startsAt case final starts?) {
      updateFilter(
        (old) => old.copyWith(
          period: DatePeriod.day,
          anchorDate: DateTime(starts.year, starts.month, starts.day),
        ),
      );
    }
    startEditingTask(TaskWithProject(task: task));
    showForm();
  }

  Future<Task?> getTask(String id) => _enqueue(() => _repository.getById(id));
  Stream<List<Task>> watchAllTasks() => _queries.watch(_repository.watchTasks);
  Stream<List<Project>> watchProjects() =>
      _queries.watch(_projects.watchAllProjects);
  Future<void> addTask(Task task) => _enqueue(
    () => _repository.addTask(task.copyWith(createdAt: DateTime.now())),
  );
  Future<void> updateTask(Task task) =>
      _enqueue(() => _repository.updateTask(task));
  Future<void> toggleTask(Task task) => _enqueue(() async {
    final current = await _repository.getById(task.id);
    if (current == null) return;
    await _repository.updateTask(
      current.copyWith(
        status: task.isCompleted ? TaskStatus.inProgress : TaskStatus.done,
        updatedAt: DateTime.now(),
      ),
    );
  });
  Future<void> deleteTask(String id) =>
      _enqueue(() => _repository.deleteTask(id));
  Future<void> deleteSelectedTask() {
    final targets = selectedTasks;
    return _enqueue(() async {
      for (final task in targets) {
        await _repository.deleteTask(task.id);
      }
    });
  }

  Future<void> markSelectedAsDone() {
    final targets = selectedTasks;
    return _enqueue(() async {
      for (final task in targets) {
        await _repository.updateTask(
          task.copyWith(status: TaskStatus.done, updatedAt: DateTime.now()),
        );
      }
    });
  }

  void stopAccepting() {
    _accepting = false;
    _queries.stopAccepting();
  }

  Future<void> dispose() => _closing ??= _dispose();
  Future<void> _dispose() async {
    stopAccepting();
    await _operations;
    _disposed = true;
    try {
      await _subscription?.cancel();
    } finally {
      await Future.wait([
        _queries.close(),
        _states.close(),
        _flags.close(),
        _filters.close(),
      ]);
    }
  }
}
