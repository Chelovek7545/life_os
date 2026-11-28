import 'package:graph_api/graph_api.dart';
import 'package:projects_api/projects_api.dart';
import 'projects_graph_contributor.dart';

GraphNodeCommands projectsGraphCommands(
  ProjectsApi projects, {
  required GraphDeleteHandler delete,
}) {
  Future<String> create(GraphNodeDraft draft, GraphNodeData? parent) async {
    final isSubproject = parent?.kind == ProjectsGraphContributor.kind;
    final project = Project.create(
      name: draft.title,
      description: draft.subtitle,
      color: draft.color ?? '#4A90D9',
      parentProjectId: isSubproject ? parent?.id : null,
      goalId: isSubproject ? null : parent?.id,
    );
    await projects.addProject(project);
    return project.id;
  }

  return GraphNodeCommands(
    kind: ProjectsGraphContributor.kind,
    parentKinds: {'goal', ProjectsGraphContributor.kind},
    create: (request) => create(request.draft, request.parent),
    createStandalone: (draft) => create(draft, null),
    update: (request) async {
      final existing = await projects.getProjectById(request.current.id);
      if (existing == null) return;
      if (existing.storageRevision != null &&
          request.current.attributes['storageRevision'] !=
              existing.storageRevision) {
        throw StateError('Node changed; reload before saving.');
      }
      await projects.updateProject(
        existing.copyWith(
          name: request.updated.title,
          description: request.updated.subtitle,
          color: request.updated.color,
          dueDate: request.updated.attributes.containsKey('dueDate')
              ? Wrapped(request.updated.attributes['dueDate'] as DateTime?)
              : null,
          isArchived: request.updated.attributes['isArchived'] as bool?,
          updatedAt: DateTime.now(),
        ),
      );
    },
    detach: (request) async {
      final project = await projects.getProjectById(request.target.id);
      if (request.linkType != GraphLinkType.hierarchy ||
          project == null ||
          (project.parentProejectId ?? project.goalId) != request.source.id) {
        throw StateError('Связь проекта уже изменилась.');
      }
      await projects.updateProject(
        project.parentProejectId != null
            ? project.copyWith(parentProejectId: const Wrapped(null))
            : project.copyWith(goalId: const Wrapped(null)),
      );
    },
    delete: delete,
  );
}
