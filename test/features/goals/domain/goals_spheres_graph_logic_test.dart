import 'package:test/test.dart';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_plugin/goals_logic.dart';
import 'package:spheres_plugin/spheres_logic.dart';
import 'package:graph_api/graph_api.dart';
import '../support/memory_goals_spheres.dart';
import '../support/graph_fixture.dart';

void main() {
  test('contributors project only the selected sphere and its goals', () async {
    final spheres = MemorySpheres();
    final goals = MemoryGoals();
    final sphere = Sphere.create(name: 'Health').copyWith(id: scope.rootId);
    spheres.items[sphere.id] = sphere;
    final other = Sphere.create(name: 'Work');
    spheres.items[other.id] = other;
    final goal = Goal.create(
      name: 'Run',
      sphereId: sphere.id,
      description: 'Daily',
    );
    goals.items[goal.id] = goal;
    final foreign = Goal.create(name: 'Ship', sphereId: other.id);
    goals.items[foreign.id] = foreign;
    final roots = await SpheresGraphContributor(spheres).watch(scope).first;
    final children = await GoalsGraphContributor(goals).watch(scope).first;
    expect(roots.single.id, sphere.id);
    expect(roots.single.parentId, isNull);
    expect(children.single.id, goal.id);
    expect(children.single.parentId, sphere.id);
    expect(children.single.subtitle, 'Daily');
    expect(spheres.listeners, isEmpty);
    expect(goals.listeners, isEmpty);
  });

  test(
    'goal creation validates the parent and preserves established defaults',
    () async {
      final goals = MemoryGoals();
      final registry = GraphCommandRegistry();
      addTearDown(registry.dispose);
      registry.register('goals', [
        goalsGraphCommands(goals, delete: (_) async => {}),
      ]);
      final draft = GraphNodeDraft(
        kind: 'goal',
        title: 'Run',
        subtitle: 'Daily',
      );
      await expectLater(
        registry.create(
          GraphCreateRequest(
            scope: scope,
            parent: node('wrong', 'project'),
            draft: draft,
          ),
        ),
        throwsUnsupportedError,
      );
      expect(goals.items, isEmpty);
      final id = await registry.create(
        GraphCreateRequest(
          scope: scope,
          parent: node('sphere', 'sphere'),
          draft: draft,
        ),
      );
      expect(goals.items[id]!.sphereId, 'sphere');
      expect(goals.items[id]!.description, 'Daily');
      expect(goals.items[id]!.color, '#FF5C00');
    },
  );

  test(
    'goal edits retain the latest due date and ignore missing entities',
    () async {
      final goals = MemoryGoals();
      final goal = Goal.create(
        name: 'Before',
        sphereId: 'sphere',
        dueDate: DateTime(2030),
      );
      goals.items[goal.id] = goal;
      final registry = GraphCommandRegistry();
      addTearDown(registry.dispose);
      registry.register('goals', [
        goalsGraphCommands(goals, delete: (_) async => {}),
      ]);
      final current = node(goal.id, 'goal', parent: 'sphere');
      final request = GraphUpdateRequest(
        scope: scope,
        current: current,
        updated: current,
      );
      await registry.update(request);
      expect(goals.items[goal.id]!.name, 'Edited');
      expect(goals.items[goal.id]!.dueDate, goal.dueDate);
      expect(goals.items[goal.id]!.createdAt, goal.createdAt);
      goals.items.clear();
      await registry.update(request);
      expect(goals.items, isEmpty);
    },
  );

  test(
    'sphere edits preserve identity and creation time without recreating deleted data',
    () async {
      final spheres = MemorySpheres();
      final sphere = Sphere.create(name: 'Before');
      spheres.items[sphere.id] = sphere;
      final registry = GraphCommandRegistry();
      addTearDown(registry.dispose);
      registry.register('spheres', [
        spheresGraphCommands(spheres, delete: (_) async => {}),
      ]);
      final current = node(sphere.id, 'sphere');
      final request = GraphUpdateRequest(
        scope: scope,
        current: current,
        updated: current,
      );
      await registry.update(request);
      expect(spheres.items[sphere.id]!.name, 'Edited');
      expect(spheres.items[sphere.id]!.createdAt, sphere.createdAt);
      spheres.items.clear();
      await registry.update(request);
      expect(spheres.items, isEmpty);
    },
  );

  test(
    'both modules forward deletion policy and transaction results unchanged',
    () async {
      final received = <GraphDeleteRequest>[];
      Future<Set<String>> delete(GraphDeleteRequest request) async {
        received.add(request);
        return {request.node.id, 'nested'};
      }

      final registry = GraphCommandRegistry();
      addTearDown(registry.dispose);
      registry.register('spheres', [
        spheresGraphCommands(MemorySpheres(), delete: delete),
      ]);
      registry.register('goals', [
        goalsGraphCommands(MemoryGoals(), delete: delete),
      ]);
      for (final kind in ['sphere', 'goal']) {
        final request = GraphDeleteRequest(
          scope: scope,
          node: node(kind, kind),
          keepChildren: kind == 'sphere',
        );
        expect(await registry.delete(request), {kind, 'nested'});
        expect(received.last, same(request));
      }
    },
  );
}
