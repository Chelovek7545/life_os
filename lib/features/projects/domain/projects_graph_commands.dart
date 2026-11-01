import 'package:graph_api/graph_api.dart';
import 'project_model.dart';
import 'projects_api.dart';
import 'projects_graph_contributor.dart';

GraphNodeCommands projectsGraphCommands(
  ProjectsApi projects, {
  required GraphDeleteHandler delete,
}) => GraphNodeCommands(
  kind: ProjectsGraphContributor.kind,
  parentKinds: {'goal', ProjectsGraphContributor.kind},
  create: (request) async {
    final draft = request.draft;
    final project = request.parent.kind == ProjectsGraphContributor.kind
        ? Project.create(
            name: draft.title,
            description: draft.subtitle,
            color: draft.color ?? '#4A90D9',
            parentProjectId: request.parent.id,
          )
        : Project.create(
            name: draft.title,
            description: draft.subtitle,
            color: draft.color ?? '#4A90D9',
            goalId: request.parent.id,
          );
    await projects.addProject(project);
    return project.id;
  },
  update: (request) async {
    final existing = await projects.getProjectById(request.current.id);
    if (existing == null) return;
    await projects.updateProject(
      existing.copyWith(
        name: request.updated.title,
        description: request.updated.subtitle,
        color: request.updated.color,
        updatedAt: DateTime.now(),
      ),
    );
  },
  delete: delete,
);
