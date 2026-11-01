import 'dart:async';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:rxdart/rxdart.dart';

class ProjectSummary {
  const ProjectSummary({
    required this.project,
    required this.totalTasks,
    required this.completedTasks,
  });
  final Project project;
  final int totalTasks;
  final int completedTasks;
  double get progress => totalTasks == 0 ? 0 : completedTasks / totalTasks;
}

class ProjectsPanelState {
  ProjectsPanelState({
    List<ProjectSummary> projects = const [],
    this.isLoading = false,
    this.error,
  }) : projects = List.unmodifiable(projects);
  final List<ProjectSummary> projects;
  final bool isLoading;
  final String? error;
}

class ProjectsPanelModel {
  ProjectsPanelModel({
    required this._projects,
    required this._tasks,
    required this._date,
  });
  final ProjectsQueries _projects;
  final TaskQueries _tasks;
  DateTime _date;
  DateTime get date => _date;
  bool _onlyForDate = false;
  bool get onlyForDate => _onlyForDate;
  final _states = BehaviorSubject<ProjectsPanelState>.seeded(
    ProjectsPanelState(isLoading: true),
  );
  Stream<ProjectsPanelState> get state => _states.stream;
  ProjectsPanelState get currentState => _states.value;
  List<Project> _projectSnapshot = const [];
  List<Task> _taskSnapshot = const [];
  StreamSubscription<void>? _subscription;
  bool _started = false;
  bool _disposed = false;
  Future<void>? _closing;
  void initialize() {
    if (_disposed) throw StateError('Projects panel is closed.');
    if (_started) return;
    _started = true;
    _subscription =
        Rx.combineLatest2<List<Project>, List<Task>, void>(
          _projects.watchAllProjects(),
          _tasks.watchTasks(),
          (projects, tasks) {
            _projectSnapshot = List.unmodifiable(projects);
            _taskSnapshot = List.unmodifiable(tasks);
            _emit();
          },
        ).listen(
          (_) {},
          onError: (Object error) {
            if (!_disposed) {
              _states.add(ProjectsPanelState(error: error.toString()));
            }
          },
        );
  }

  void selectDate(DateTime value) {
    if (_disposed) return;
    _date = value;
    _emit();
  }

  void setOnlyForDate(bool value) {
    if (_disposed) return;
    _onlyForDate = value;
    _emit();
  }

  void _emit() {
    if (_disposed) return;
    final counts = <String, (int, int)>{};
    final dated = <String>{};
    for (final task in _taskSnapshot) {
      final id = task.projectId;
      if (id == null) continue;
      final old = counts[id] ?? (0, 0);
      counts[id] = (old.$1 + 1, old.$2 + (task.isCompleted ? 1 : 0));
      final day = task.startsAt ?? task.dueDate;
      if (day != null &&
          day.year == _date.year &&
          day.month == _date.month &&
          day.day == _date.day) {
        dated.add(id);
      }
    }
    _states.add(
      ProjectsPanelState(
        projects: [
          for (final project in _projectSnapshot)
            if (!project.isArchived &&
                (!_onlyForDate || dated.contains(project.id)))
              ProjectSummary(
                project: project,
                totalTasks: counts[project.id]?.$1 ?? 0,
                completedTasks: counts[project.id]?.$2 ?? 0,
              ),
        ],
      ),
    );
  }

  Future<void> dispose() => _closing ??= _dispose();
  Future<void> _dispose() async {
    _disposed = true;
    try {
      await _subscription?.cancel();
    } finally {
      await _states.close();
    }
  }
}
