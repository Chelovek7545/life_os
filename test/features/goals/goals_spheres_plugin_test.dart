import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goals_api/goals_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_plugin/goals_plugin.dart';
import 'package:spheres_plugin/spheres_plugin.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'support/memory_goals_spheres.dart';
import 'support/graph_fixture.dart';

class Harness {
  final goals = MemoryGoals();
  final spheres = MemorySpheres();
  final sources = GraphContributorRegistry();
  final cards = GraphNodePresentationRegistry();
  final editors = GraphEditorRegistry();
  final commands = GraphCommandRegistry();
  late final sphere = Sphere.create(name: 'Health').copyWith(id: scope.rootId);
  late final goal = Goal.create(name: 'Run', sphereId: sphere.id);
  late final spherePlugin = SpheresPlugin(
    spheres: spheres,
    contributors: sources,
    presentations: cards,
    editors: editors,
    commands: commands,
    visuals: SpheresUiBindings(
      nodeCard: (_, node, _) => Text(node.title),
      nodeSize: const Size(200, 120),
      editor: (_, _) => const SizedBox(),
    ),
    delete: (request) async {
      await spheres.deleteSphere(request.node.id);
      return {request.node.id};
    },
  );
  late final goalPlugin = GoalsPlugin(
    goals: goals,
    contributors: sources,
    presentations: cards,
    editors: editors,
    commands: commands,
    visuals: GoalsUiBindings(
      nodeCard: (_, node, _) => Text(node.title),
      nodeSize: const Size(180, 100),
      editor: (_, _) => const SizedBox(),
      createForm: (_, _) => const SizedBox(),
    ),
    delete: (request) async {
      await goals.deleteGoal(request.node.id);
      return {request.node.id};
    },
  );
  // Deliberately reversed to exercise declared dependencies.
  late final host = PluginHost([
    ...goalPlugin.plugins,
    ...spherePlugin.plugins,
  ]);
  void seed() {
    spheres.items[sphere.id] = sphere;
    goals.items[goal.id] = goal;
  }

  Future<void> dispose() async {
    goals.failCancel = false;
    spheres.failCancel = false;
    await host.stop();
    await sources.dispose();
    await commands.dispose();
    editors.dispose();
    cards.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'functional modules run with only public ports and reject a missing sphere dependency',
    () async {
      final h = Harness()..seed();
      addTearDown(h.dispose);
      expect(() => PluginHost(h.goalPlugin.plugins), throwsArgumentError);
      await h.host.start();
      await h.host.start();
      expect(h.sources.contributors.map((source) => source.id), [
        'spheres.nodes',
        'goals.nodes',
      ]);
      expect(h.cards.sizeFor('goal'), const Size(180, 100));
      expect(h.editors.hasEditor('sphere'), isTrue);
      expect(h.editors.hasEditor('goal'), isTrue);
      expect(h.editors.childActions('sphere').single.id, 'goals.create');
      expect(h.editors.childActions('goal'), isEmpty);
      final id = await h.commands.create(
        GraphCreateRequest(
          scope: scope,
          parent: node(h.sphere.id, 'sphere'),
          draft: GraphNodeDraft(kind: 'goal', title: 'Independent'),
        ),
      );
      expect(h.goals.items[id]!.name, 'Independent');
      await h.host.stop();
      await h.host.stop();
      expect(h.sources.contributors, isEmpty);
      expect(h.commands.canUpdate('sphere'), isFalse);
      expect(h.cards.lookup('goal'), isNull);
      expect(h.editors.childActions('sphere'), isEmpty);
    },
  );

  test(
    'stop drains accepted goal writes before removing sphere registrations',
    () async {
      final h = Harness()..seed();
      addTearDown(h.dispose);
      await h.host.start();
      final subscriptions = [
        for (final source in h.sources.contributors)
          source.watch(scope).listen((_) {}),
      ];
      await Future<void>.delayed(Duration.zero);
      h.goals.entered = Completer<void>();
      h.goals.gate = Completer<void>();
      final current = node(h.goal.id, 'goal', parent: h.sphere.id);
      final writing = h.commands.update(
        GraphUpdateRequest(scope: scope, current: current, updated: current),
      );
      await h.goals.entered!.future;
      var done = false;
      final closing = h.host.stop().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(h.editors.hasEditor('goal'), isFalse);
      expect(h.cards.lookup('sphere'), isNotNull);
      expect(h.commands.canUpdate('goal'), isFalse);
      await expectLater(
        h.commands.update(
          GraphUpdateRequest(scope: scope, current: current, updated: current),
        ),
        throwsUnsupportedError,
      );
      h.goals.gate!.complete();
      await writing;
      await closing;
      expect(h.goals.items[h.goal.id]!.name, 'Edited');
      expect(h.goals.listeners, isEmpty);
      expect(h.spheres.listeners, isEmpty);
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );

  for (final collision in [
    'presentation',
    'commands',
    'editors',
    'contributors',
  ]) {
    test(
      'a goal $collision collision rolls back all owned registrations and allows retry',
      () async {
        final h = Harness()..seed();
        addTearDown(h.dispose);
        switch (collision) {
          case 'presentation':
            h.cards.register('existing', [
              GraphNodePresentation(
                kind: 'goal',
                size: const Size(90, 90),
                builder: (_, _, _) => const SizedBox(),
              ),
            ]);
          case 'commands':
            h.commands.register('existing', [
              GraphNodeCommands(kind: 'goal', update: (_) async {}),
            ]);
          case 'editors':
            h.editors.register(
              'existing',
              editors: [
                GraphNodeEditor(
                  kind: 'goal',
                  builder: (_, _) => const SizedBox(),
                ),
              ],
            );
          case 'contributors':
            h.sources.register('existing', [GoalsGraphContributor(h.goals)]);
        }
        await expectLater(
          h.host.start(),
          throwsA(isA<PluginLifecycleException>()),
        );
        expect(h.cards.lookup('sphere'), isNull);
        expect(h.commands.canUpdate('sphere'), isFalse);
        expect(h.editors.hasEditor('sphere'), isFalse);
        expect(h.cards.lookup('goal') != null, collision == 'presentation');
        expect(h.commands.canUpdate('goal'), collision == 'commands');
        expect(h.editors.hasEditor('goal'), collision == 'editors');
        expect(
          h.sources.contributors.length,
          collision == 'contributors' ? 1 : 0,
        );
        h.cards.unregister('existing');
        await h.commands.unregister('existing');
        h.editors.unregister('existing');
        await h.sources.unregister('existing');
        await h.host.start();
        expect(h.sources.contributors, hasLength(2));
      },
    );
  }

  test(
    'old contributor leases and command guards stay revoked after restart',
    () async {
      final h = Harness()..seed();
      addTearDown(h.dispose);
      await h.host.start();
      final old = h.sources.contributors.last;
      final guard = h.commands.guardFor('goal');
      final stream = old.watch(scope);
      final subscription = stream.listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(h.goals.listeners, hasLength(1));
      await h.host.stop();
      expect(h.goals.listeners, isEmpty);
      await h.host.start();
      expect(guard(), isFalse);
      expect(await old.watch(scope).first, isEmpty);
      expect(
        (await h.sources.contributors.last.watch(scope).first).single.id,
        h.goal.id,
      );
      await subscription.cancel();
    },
  );

  test(
    'source cancellation failure still releases peers and registrations',
    () async {
      final h = Harness()..seed();
      addTearDown(h.dispose);
      await h.host.start();
      final errors = <Object>[];
      final subscriptions = [
        for (final source in h.sources.contributors)
          source.watch(scope).listen((_) {}, onError: errors.add),
      ];
      await Future<void>.delayed(Duration.zero);
      h.goals.failCancel = true;
      await expectLater(
        h.host.stop(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.goals.listeners, isEmpty);
      expect(h.spheres.listeners, isEmpty);
      expect(h.sources.contributors, isEmpty);
      expect(h.commands.canUpdate('goal'), isFalse);
      expect(h.cards.lookup('goal'), isNull);
      expect(h.cards.lookup('sphere'), isNull);
      expect(h.editors.hasEditor('goal'), isFalse);
      expect(errors, isNotEmpty);
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );
}
