import '../domain/graph_deletion.dart';
import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;

class DriftGraphDeletion implements GraphDeletion {
  DriftGraphDeletion(this.database);
  final AppDatabase database;

  @override
  Future<Set<String>> delete(
    GraphNodeType type,
    String id, {
    required bool keepChildren,
  }) => database.transaction(() async {
    if (type == GraphNodeType.external)
      throw UnsupportedError('External nodes use their module commands.');
    final db = database;
    final spheres = <String>{if (type == GraphNodeType.sphere) id};
    final goals = <String>{if (type == GraphNodeType.goal) id};
    final projects = <String>{if (type == GraphNodeType.project) id};
    final tasks = <String>{
      if (type == GraphNodeType.task || type == GraphNodeType.subTask) id,
    };
    if (!keepChildren) {
      if (spheres.isNotEmpty) {
        goals.addAll(
          (await (db.select(
            db.goals,
          )..where((g) => g.sphereId.isIn(spheres))).get()).map((g) => g.id),
        );
      }
      final allProjects = await db.select(db.projects).get();
      final allTasks = await db.select(db.tasks).get();
      var changed = true;
      while (changed) {
        changed = false;
        for (final project in allProjects) {
          if (goals.contains(project.goalId) ||
              projects.contains(project.parentProejectId)) {
            changed = projects.add(project.id) || changed;
          }
        }
        for (final task in allTasks) {
          if (projects.contains(task.projectId) ||
              tasks.contains(task.parentTaskId)) {
            changed = tasks.add(task.id) || changed;
          }
        }
      }
    } else {
      final now = Value(DateTime.now());
      if (spheres.isNotEmpty) {
        await (db.update(db.goals)..where((g) => g.sphereId.isIn(spheres)))
            .write(GoalsCompanion(sphereId: const Value(null), updatedAt: now));
      }
      if (goals.isNotEmpty) {
        await (db.update(
          db.projects,
        )..where((p) => p.goalId.isIn(goals))).write(
          ProjectsCompanion(goalId: const Value(null), updatedAt: now),
        );
      }
      if (projects.isNotEmpty) {
        await (db.update(
          db.projects,
        )..where((p) => p.parentProejectId.isIn(projects))).write(
          ProjectsCompanion(
            parentProejectId: const Value(null),
            updatedAt: now,
          ),
        );
        await (db.update(
          db.tasks,
        )..where((t) => t.projectId.isIn(projects))).write(
          TasksCompanion(projectId: const Value(null), updatedAt: now),
        );
      }
      if (tasks.isNotEmpty) {
        await (db.update(
          db.tasks,
        )..where((t) => t.parentTaskId.isIn(tasks))).write(
          TasksCompanion(parentTaskId: const Value(null), updatedAt: now),
        );
      }
    }
    if (tasks.isNotEmpty) {
      await (db.delete(db.tasks)..where((t) => t.id.isIn(tasks))).go();
    }
    if (projects.isNotEmpty) {
      await (db.delete(db.projects)..where((p) => p.id.isIn(projects))).go();
    }
    if (goals.isNotEmpty) {
      await (db.delete(db.goals)..where((g) => g.id.isIn(goals))).go();
    }
    if (spheres.isNotEmpty) {
      await (db.delete(db.spheres)..where((s) => s.id.isIn(spheres))).go();
    }
    return {...spheres, ...goals, ...projects, ...tasks};
  });
}
