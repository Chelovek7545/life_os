import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:rxdart/rxdart.dart';

class TaskWithProject {
  final Task task;
  final Project? project;
  TaskWithProject({required this.task, this.project});
}

class GetTasksWithProjectsUseCase {
  GetTasksWithProjectsUseCase(this._tasks, this._projects);
  final TaskQueries _tasks;
  final ProjectsQueries _projects;

  Stream<List<TaskWithProject>> call() => Rx.combineLatest2(
    _tasks.watchTasks(),
    _projects.watchAllProjects(),
    _join,
  );

  Future<List<TaskWithProject>> getTasksWithProjects() async =>
      _join(await _tasks.getAllTasks(), await _projects.getAllProjects());

  List<TaskWithProject> _join(List<Task> tasks, List<Project> projects) {
    final byId = {for (final project in projects) project.id: project};
    return tasks
        .map(
          (task) => TaskWithProject(task: task, project: byId[task.projectId]),
        )
        .toList(growable: false);
  }
}
