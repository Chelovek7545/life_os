import 'dart:async';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/projects/presentation/projects_state.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:rxdart/rxdart.dart';

class ProjectsViewModel {
  final ProjectsRepository _repository;
  final TasksRepository _taskRepo;

  ProjectsViewModel({required this._repository, required this._taskRepo});

  final BehaviorSubject<ProjectsScreenState> _uiStateController =
      BehaviorSubject<ProjectsScreenState>.seeded(const ProjectsLoading());
  Stream<ProjectsScreenState> get state => _uiStateController.stream;

  StreamSubscription<List<Project>>? _projectsSubscription;
  //Stream<List<Project>> watchProjects() => _taskSubscription.;

  Future<Project?> getProject(String id) async =>
      await _repository.getProjectById(id);

  List<Project> _projects = [];

  void initialize() {
    _projectsSubscription = _repository.watchAllProjects().listen(
      _onProjectsUpdated,
      onError: (Object error) {
        _uiStateController.add(ProjectsError('Failed to load project: $error'));
      },
    );
  }



  //FOR TASKS
  Stream<List<Task>> watchTaskByProject(String projectId){
    return _taskRepo.watchTasksForProject(projectId);
  } 

  Future<void> updateTask(Task task) async {
    await _taskRepo.updateTask(task);
  }  





  Future<void> addProjects(Project project) async {
    // final projectWithId = project.copyWith(
    //   //id: id,
    //   createdAt: DateTime.now(),
    //   updatedAt: DateTime.now(),
    // );
    await _repository.addProject(project);
    await _emitUiState();
  }

  Future<void> deleteProject(String id) async {
    await _repository.deleteProject(id);
    await _emitUiState();
  }

  void _onProjectsUpdated(List<Project> projects) {
    _projects = projects;
    _emitUiState();
  }

  Future<void> _emitUiState() async {
    _uiStateController.add(
      ProjectsLoaded(
        curProject: _projects.isNotEmpty ? _projects.first : null,
        projects: _projects,
      ),
    );
  }

  void dispose() {
    _projectsSubscription?.cancel();
    _uiStateController.close();
  }
}
