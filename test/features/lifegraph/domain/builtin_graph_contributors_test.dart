import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import '../../../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'built-in modules preserve IDs, relationships, status and task colors',
    () async {
      final app = await createTestApp(enableObsidian: false);
      try {
        final sphere = Sphere.create(name: 'Main');
        final other = Sphere.create(name: 'Other');
        await app.spheresRepository.addSphere(sphere);
        await app.spheresRepository.addSphere(other);
        final goal = Goal.create(name: 'Goal', sphereId: sphere.id);
        final otherGoal = Goal.create(name: 'Other goal', sphereId: other.id);
        await app.goalsRepository.addGoal(goal);
        await app.goalsRepository.addGoal(otherGoal);
        final project = Project.create(name: 'Root project', goalId: goal.id);
        final child = Project.create(
          name: 'Child',
          parentProjectId: project.id,
        );
        final leaf = Project.create(
          name: 'Leaf',
          parentProjectId: child.id,
          color: '#123ABC',
        );
        final outside = Project.create(name: 'Outside', goalId: otherGoal.id);
        // Intentionally reverse the parent order.
        for (final item in [leaf, child, project, outside]) {
          await app.projectsRepository.addProject(item);
        }
        final task = Task.blank().copyWith(
          title: 'Task',
          projectId: Wrapped(leaf.id),
          status: TaskStatus.inProgress,
        );
        final subtask = Task.blank().copyWith(
          title: 'Subtask',
          parentTaskId: Wrapped(task.id),
        );
        final nested = Task.blank().copyWith(
          title: 'Deep task',
          parentTaskId: Wrapped(subtask.id),
        );
        final detached = Task.blank();
        for (final item in [nested, subtask, task, detached]) {
          await app.tasksRepository.addTask(item);
        }
        final graph = await app.graphBuilder.watchGraph(sphere.id).first;
        expect(graph.map((node) => node.id).toSet(), {
          sphere.id,
          goal.id,
          project.id,
          child.id,
          leaf.id,
          task.id,
          subtask.id,
          nested.id,
        });
        final byId = {for (final node in graph) node.id: node};
        expect(byId[leaf.id]!.parentId, child.id);
        expect(byId[task.id]!.color, leaf.color);
        expect(byId[subtask.id]!.color, '#CCC2DC');
        expect(
          GraphNode.fromData(byId[task.id]!).taskStatus,
          TaskStatus.inProgress,
        );
        expect(byId[nested.id]!.parentId, subtask.id);
        await app.graphPositionsRepository.savePositions(sphere.id, {
          leaf.id: const GraphPoint(220, 330),
        });
        final vm = await app.pulseScreenViewModel.openGraph(sphere.id);
        final displayed = await vm.graphStream.firstWhere(
          (nodes) => nodes.length == graph.length,
        );
        expect(
          displayed.firstWhere((node) => node.id == leaf.id).position,
          const Offset(220, 330),
        );
        expect(
          displayed.firstWhere((node) => node.id == task.id).size,
          const Size(160, 120),
        );
        await vm.dispose();
        await app.spheresRepository.deleteSphere(sphere.id);
        expect(await app.graphBuilder.watchGraph(sphere.id).first, isEmpty);
      } finally {
        await app.dispose();
      }
    },
  );

  test(
    'graph edits keep non-visible entity fields and nested project ownership',
    () async {
      final app = await createTestApp(enableObsidian: false);
      try {
        final created = DateTime(2025, 1, 2);
        final due = DateTime(2030, 2, 3);
        final sphere = Sphere.create(name: 'Main').copyWith(createdAt: created);
        await app.spheresRepository.addSphere(sphere);
        final goal = Goal.create(
          name: 'Goal',
          sphereId: sphere.id,
          dueDate: due,
        ).copyWith(createdAt: created);
        await app.goalsRepository.addGoal(goal);
        final root = Project.create(name: 'Root', goalId: goal.id);
        final child = Project.create(
          name: 'Child',
          parentProjectId: root.id,
        ).copyWith(createdAt: created, dueDate: Wrapped(due), isArchived: true);
        await app.projectsRepository.addProject(root);
        await app.projectsRepository.addProject(child);
        final task = Task.blank().copyWith(
          projectId: Wrapped(child.id),
          dueDate: Wrapped(due),
          tags: [const Tag(id: 1, name: 'keep', colorHex: 0xFF9E9E9E)],
        );
        await app.tasksRepository.addTask(task);
        final vm = await app.pulseScreenViewModel.openGraph(sphere.id);
        await vm.graphStream.firstWhere((nodes) => nodes.length == 5);
        await vm.updateNode(
          vm.nodeById(sphere.id)!.copyWith(title: 'New sphere'),
        );
        await vm.updateNode(vm.nodeById(goal.id)!.copyWith(title: 'New goal'));
        await vm.updateNode(
          vm.nodeById(child.id)!.copyWith(title: 'New child'),
        );
        await vm.updateNode(
          vm
              .nodeById(task.id)!
              .copyWith(title: 'New task', taskStatus: TaskStatus.done),
        );
        final savedSphere = (await app.spheresRepository.getSphere(sphere.id))!;
        final savedGoal = (await app.goalsRepository.getGoal(goal.id))!;
        final savedChild = (await app.projectsRepository.getProjectById(
          child.id,
        ))!;
        final savedTask = (await app.tasksRepository.getById(task.id))!;
        expect(savedSphere.createdAt, created);
        expect(savedGoal.createdAt, created);
        expect(savedGoal.dueDate, due);
        expect(savedChild.parentProejectId, root.id);
        expect(savedChild.goalId, isNull);
        expect(savedChild.dueDate, due);
        expect(savedChild.createdAt, created);
        expect(savedChild.isArchived, isTrue);
        expect(savedTask.title, 'New task');
        expect(savedTask.status, TaskStatus.done);
        expect(savedTask.tags.single.name, 'keep');
        expect(savedTask.dueDate, due);
        await vm.dispose();
      } finally {
        await app.dispose();
      }
    },
  );
}
