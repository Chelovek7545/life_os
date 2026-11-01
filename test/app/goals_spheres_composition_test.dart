import 'package:flutter_test/flutter_test.dart';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:graph_api/graph_api.dart';
import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final kind in ['goal', 'sphere']) {
    for (final keepChildren in [true, false]) {
      test(
        '$kind plugin preserves SQLite deletion policy, keepChildren=$keepChildren',
        () async {
          final app = await createTestApp(enableObsidian: false);
          addTearDown(app.dispose);
          final sphere = Sphere.create(name: 'Test sphere');
          final foreign = Sphere.create(name: 'Other sphere');
          await app.spheresRepository.addSphere(sphere);
          await app.spheresRepository.addSphere(foreign);
          final scope = GraphScope(rootId: sphere.id, rootKind: 'sphere');
          final root = GraphNodeData(
            id: sphere.id,
            kind: 'sphere',
            title: sphere.name,
            color: sphere.color,
          );
          final goalId = await app.graphCommands.create(
            GraphCreateRequest(
              scope: scope,
              parent: root,
              draft: GraphNodeDraft(kind: 'goal', title: 'Test goal'),
            ),
          );
          final goal = GraphNodeData(
            id: goalId,
            kind: 'goal',
            title: 'Test goal',
            color: '#FF5C00',
            parentId: sphere.id,
          );
          final project = Project.create(name: 'Test project', goalId: goalId);
          final nested = Project.create(
            name: 'Nested project',
            parentProjectId: project.id,
          );
          await app.projectsRepository.addProject(project);
          await app.projectsRepository.addProject(nested);
          final task = Task.blank().copyWith(projectId: Wrapped(nested.id));
          await app.tasksRepository.addTask(task);
          final log = WorkLog.blank(task.id);
          await app.workLogsRepository.addWorkLog(log);
          final unrelated = Goal.create(
            name: 'Unrelated',
            sphereId: foreign.id,
          );
          await app.goalsRepository.addGoal(unrelated);
          final graph = await app.graphBuilder
              .watchGraph(sphere.id)
              .firstWhere((nodes) => nodes.any((node) => node.id == task.id));
          expect(graph.map((node) => node.id).toSet(), {
            sphere.id,
            goalId,
            project.id,
            nested.id,
            task.id,
          });
          // Restart the real plugin graph before using its public commands.
          await app.plugins.stop();
          await app.plugins.start();
          final target = kind == 'sphere' ? root : goal;
          final removed = await app.graphCommands.delete(
            GraphDeleteRequest(
              scope: scope,
              node: target,
              keepChildren: keepChildren,
            ),
          );
          expect(removed.contains(target.id), isTrue);
          expect(await app.goalsRepository.getGoal(unrelated.id), isNotNull);
          expect(await app.spheresRepository.getSphere(foreign.id), isNotNull);
          expect(
            await app.projectsRepository.getProjectById(project.id) != null,
            keepChildren,
          );
          expect(
            await app.tasksRepository.getById(task.id) != null,
            keepChildren,
          );
          expect(
            await app.workLogsRepository.getById(log.id) != null,
            keepChildren,
          );
          if (keepChildren && kind == 'goal') {
            expect(
              (await app.projectsRepository.getProjectById(project.id))!.goalId,
              isNull,
            );
          }
          if (keepChildren && kind == 'sphere') {
            final row = await (app.database.select(
              app.database.goals,
            )..where((row) => row.id.equals(goalId))).getSingle();
            expect(row.sphereId, isNull);
          }
          if (!keepChildren) {
            expect(
              removed,
              containsAll([goalId, project.id, nested.id, task.id]),
            );
          }
          expect(app.navigation.selectedId, 'pulse');
        },
      );
    }
  }
}
