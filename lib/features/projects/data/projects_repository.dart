import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/projects/data/extensions/project_model_extension.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';

class ProjectsRepository {
  ProjectsRepository(this._dao);
  final ProjectsDao _dao;

  Stream<List<Project>> watchAllProjects() => _dao.watchAllProjects();

  Future<List<Project>> getAllProjects() => _dao.getAllProjects();

  Future<Project?> getProjectById(String id) =>
      _dao.getProjectById(id).then((v) => v?.toDomain());

  Future<void> addProject(Project project) async {
    try {
      await _dao.createProject(project.toDrift());
    } catch (error) {
      throw StorageException('Failed to save task.', error);
    }
  }

  Future<void> updateProject(Project project) async {
    try {
      await _dao.updateProject(project);
    } catch (error) {
      throw StorageException('Failed to update project.', error);
    }
  }

  Future<void> deleteProject(String id) async {
    try {
      await _dao.deleteProject(id);
    } catch (e) {
      print(e);
    }
  }
}
