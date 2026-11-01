import 'project.dart';

abstract interface class ProjectsQueries {
  Stream<List<Project>> watchAllProjects();
  Future<List<Project>> getAllProjects();
  Future<Project?> getProjectById(String id);
}

abstract interface class ProjectsCommands {
  Future<void> addProject(Project project);
  Future<void> updateProject(Project project);
  Future<void> deleteProject(String id);
}

abstract interface class ProjectsApi
    implements ProjectsQueries, ProjectsCommands {}
