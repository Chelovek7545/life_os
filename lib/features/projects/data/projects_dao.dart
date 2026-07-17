import 'package:drift/drift.dart';
import '../domain/project_model.dart';
import 'package:life_os/core/database/database.dart';
import 'extensions/project_model_extension.dart';

part 'projects_dao.g.dart';

@DriftAccessor(tables: [Projects])
class ProjectsDao extends DatabaseAccessor<AppDatabase>
    with _$ProjectsDaoMixin {
  ProjectsDao(AppDatabase db) : super(db);

  // =============== CREATE ===============

  Future<void> createProject(ProjectsCompanion project) async {
    await into(projects).insert(project);
  }

  // =============== READ ===============

  Future<List<Project>> getAllProjects() async {
    final dataList = await select(projects).get();
    return dataList.map((data) => data.toDomain()).toList();
  }

  // Future<List<Project>> getActiveProjects() async {
  //   final dataList = await (select(projects)
  //     ..where((p) => p.isArchived.equals(false))
  //     ..orderBy([(p) => OrderingTerm(expression: p.name)]))
  //     .get();
  //   return dataList.map((data) => Project.fromDrift(data)).toList();
  // }

  Future<ProjectModel?> getProjectById(String id) async {
    try {
      final data = await (select(
        projects,
      )..where((p) => p.id.equals(id))).getSingle();
      return data;
    } catch (e) {
      return null;
    }
  }

  // Future<List<Project>> searchProjects(String query) async {
  //   final dataList = await (select(projects)
  //     ..where((p) => p.name.like('%$query%'))
  //   ).get();
  //   return dataList.map((data) => data.toDomain()).toList();
  // }

  Stream<List<Project>> watchAllProjects() {
    return (select(projects)).watch().map(
      (dataList) => dataList.map((data) => data.toDomain()).toList(),
    );
  }

  // Stream<List<Project>> watchActiveProjects() {
  //   return (select(projects)..where((p) => p.isArchived.equals(false)))
  //     .watch()
  //     .map((dataList) => dataList.map((data) => data.toDomain()).toList());
  // }

  // =============== UPDATE ===============

  Future<void> updateProject(Project project) async {
    await update(
      projects,
    ).replace(project.copyWith(updatedAt: DateTime.now()).toDrift());
  }

  Future<void> updateProjectName(String id, String newName) async {
    await (update(projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(name: Value(newName), updatedAt: Value(DateTime.now())),
    );
  }

  Future<void> archiveProject(String id) async {
    await (update(projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> unarchiveProject(String id) async {
    await (update(projects)..where((p) => p.id.equals(id))).write(
      ProjectsCompanion(
        isArchived: const Value(false),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // =============== DELETE ===============

  Future<void> deleteProject(String id) async {
    await (delete(projects)..where((p) => p.id.equals(id))).go();
  }

  // Future<void> deleteAllArchived() async {
  //   await (delete(projects)..where((p) => p.isArchived.equals(true))).go();
  // }

  // =============== STATS ===============

  // Future<int> getProjectTaskCount(String projectId) async {
  //   final count = await (selectOnly(tasks)
  //     ..addColumns([tasks.id.count()])
  //     ..where(tasks.projectId.equals(projectId))
  //   ).getSingle();
  //   return count.read(tasks.id.count()) ?? 0;
  // }

  // Future<Map<Project, int>> getProjectsWithTaskCount() async {
  //   final projects = await getActiveProjects();
  //   final Map<Project, int> result = {};

  //   for (var project in projects) {
  //     result[project] = await getProjectTaskCount(project.id);
  //   }

  //   return result;
  // }
}
