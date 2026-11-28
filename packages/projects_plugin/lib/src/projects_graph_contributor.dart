import 'package:graph_api/graph_api.dart';
import 'package:projects_api/projects_api.dart';

class ProjectsGraphContributor implements GraphContributor {
  ProjectsGraphContributor(this.projects);
  static const kind = 'project';
  final ProjectsQueries projects;
  @override
  String get id => 'projects.nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      projects.watchAllProjects().map(
        (values) => [
          for (final project in values)
            GraphNodeData(
              id: project.id,
              kind: kind,
              title: project.name,
              subtitle: project.description,
              color: project.color,
              attributes: {
                'dueDate': ?project.dueDate,
                if (scope.isCanvas) 'isArchived': project.isArchived,
                if (project.storageRevision != null)
                  'storageRevision': project.storageRevision,
              },
              parentId: project.parentProejectId ?? project.goalId,
            ),
        ],
      );
}
