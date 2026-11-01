import 'project_model.dart';

abstract interface class ProjectsApi {
  Stream<List<Project>> watchAllProjects();
  Future<List<Project>> getAllProjects();
  Future<Project?> getProjectById(String id);
  Future<void> addProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);
}
