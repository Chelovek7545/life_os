import 'package:projects_api/projects_api.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/extensions/project_model_extension.dart';
import 'package:life_os/core/storage/storage_exception.dart';

class ProjectsRepository implements ProjectsApi {
  ProjectsRepository(this._dao);
  final ProjectsDao _dao;

  @override
  Stream<List<Project>> watchAllProjects() => _dao.watchAllProjects();

  @override
  Future<List<Project>> getAllProjects() => _dao.getAllProjects();

  @override
  Future<Project?> getProjectById(String id) =>
      _dao.getProjectById(id).then((v) => v?.toDomain());

  @override
  Future<void> addProject(Project project) async {
    try {
      await _dao.createProject(project.toDrift());
    } catch (error) {
      throw StorageException('Failed to save project.', error);
    }
  }

  @override
  Future<void> updateProject(Project project) async {
    try {
      await _dao.updateProject(project);
    } catch (error) {
      throw StorageException('Failed to update project.', error);
    }
  }

  @override
  Future<void> deleteProject(String id) async {
    try {
      await _dao.deleteProject(id);
    } catch (e) {
      throw StorageException('Failed to delete project.', e);
    }
  }
}
