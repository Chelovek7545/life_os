import 'package:drift/drift.dart';
import 'package:projects_api/projects_api.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/task_mutation_journal.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'extensions/project_model_extension.dart';
part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  ProjectsDao(super.db, {this.journal});
  final TaskMutationJournal? journal;
  Future<T> _write<T>(
    String id,
    Future<T> Function() write, {
    String? expectedRevision,
    bool requireExpected = false,
    bool createOnly = false,
  }) =>
      journal?.trackEntity(
        'project',
        id,
        write,
        expectedRevision: expectedRevision,
        requireExpected: requireExpected,
        createOnly: createOnly,
      ) ??
      transaction(write);
  Future<Project> observeProject(Project p) async =>
      (await _observeAll([p])).single;
  Future<List<Project>> _observeAll(List<Project> projects) async {
    if (journal == null || projects.isEmpty) return projects;
    final payloads = {
      for (final p in projects)
        'project/${p.id}': HierarchySyncCodec.project(p),
    };
    final versions = await journal!.observedRevisions(payloads);
    return [
      for (final p in projects)
        HierarchySyncCodec.decodeProject(
          payloads['project/${p.id}']!,
          storageRevision: versions['project/${p.id}'],
        ),
    ];
  }

  Future<void> createProject(ProjectsCompanion project) async {
    await _write(
      project.id.value,
      () => into(projects).insert(project),
      createOnly: true,
    );
  }

  Future<List<Project>> getAllProjects() async => _observeAll(
    (await select(projects).get()).map((r) => r.toDomain()).toList(),
  );
  Future<ProjectModel?> getProjectById(String id) =>
      (select(projects)..where((p) => p.id.equals(id))).getSingleOrNull();
  Stream<List<Project>> watchAllProjects() => select(projects).watch().asyncMap(
    (rows) => _observeAll(rows.map((r) => r.toDomain()).toList()),
  );
  Future<void> updateProject(Project project) async {
    await _write(
      project.id,
      () => update(
        projects,
      ).replace(project.copyWith(updatedAt: DateTime.now()).toDrift()),
      expectedRevision: project.storageRevision,
      requireExpected: true,
    );
  }

  Future<void> updateProjectName(String id, String newName) async {
    await _write(
      id,
      () => (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(
          name: Value(newName),
          updatedAt: Value(DateTime.now()),
        ),
      ),
    );
  }

  Future<void> archiveProject(String id) async {
    await _write(
      id,
      () => (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(
          isArchived: const Value(true),
          updatedAt: Value(DateTime.now()),
        ),
      ),
    );
  }

  Future<void> unarchiveProject(String id) async {
    await _write(
      id,
      () => (update(projects)..where((p) => p.id.equals(id))).write(
        ProjectsCompanion(
          isArchived: const Value(false),
          updatedAt: Value(DateTime.now()),
        ),
      ),
    );
  }

  Future<void> deleteProject(String id) async {
    await _write(
      id,
      () => (delete(projects)..where((p) => p.id.equals(id))).go(),
    );
  }
}
