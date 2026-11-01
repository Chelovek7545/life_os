import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import '../../support/test_app.dart';
import 'support/plugin_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'independent graph plugin owns immutable Pulse snapshots and graph sessions',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await h.spheres.addSphere(sphere);
      await h.host.start();
      final pulse = h.graph.viewModel;
      await pulse.initialize();
      await pulse.spheresStream.firstWhere((items) => items.isNotEmpty);
      expect(h.spheres.source.listeners, hasLength(1));
      expect(h.goals.source.listeners, hasLength(1));
      expect(() => pulse.spheres.clear(), throwsUnsupportedError);
      final graph = await pulse.openGraph(sphere.id);
      await graph.graphStream.firstWhere((items) => items.isNotEmpty);
      final preview = pulse.graphBuilder.watchGraph(sphere.id).listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await h.host.stop();
      expect(h.spheres.source.listeners, isEmpty);
      expect(h.goals.source.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.tasks.listeners, isEmpty);
      await expectLater(graph.createNote(), throwsStateError);
      await expectLater(pulse.openGraph(sphere.id), throwsStateError);
      expect(() => pulse.graphBuilder.watchGraph(sphere.id), throwsStateError);
      await preview.cancel();
      await h.host.start();
      expect(h.graph.viewModel, isNot(same(pulse)));
      expect(h.ui.screens.map((screen) => screen.id), ['pulse', 'resources']);
    },
  );

  test(
    'closing flushes linked notes before graph commands or the vault stop',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await h.spheres.addSphere(sphere);
      await h.host.start();
      h.vault.files['linked.md'] = 'Original';
      final graph = await h.graph.viewModel.openGraph(sphere.id);
      await graph.createNoteWithText(
        title: 'Linked',
        text: '',
        obsidianPath: 'linked.md',
      );
      await graph.updateNoteText(graph.notes.single.id, 'Latest text');
      h.vault.writeGate = Completer<void>();
      h.vault.writeEntered = Completer<void>();
      var stopped = false;
      final closing = h.host.stop().then((_) => stopped = true);
      await h.vault.writeEntered!.future;
      expect(stopped, isFalse);
      expect(h.vault.stopped, isFalse);
      expect(h.commands.canUpdate('sphere'), isTrue);
      await expectLater(
        graph.updateNoteText(graph.notes.single.id, 'Stale'),
        throwsStateError,
      );
      h.vault.writeGate!.complete();
      await closing;
      expect(h.vault.files['linked.md'], 'Latest text');
      expect(h.notes.values[sphere.id]!.single.text, 'Latest text');
      expect(h.vault.events, ['write:linked.md', 'source.stop']);
      expect(h.commands.canUpdate('sphere'), isFalse);
    },
  );

  test(
    'an accepted graph open finishes before shutdown and is then released',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await h.spheres.addSphere(sphere);
      await h.host.start();
      final pulse = h.graph.viewModel;
      h.positions.loadGate = Completer<void>();
      h.positions.loadEntered = Completer<void>();
      final opening = pulse.openGraph(sphere.id);
      await h.positions.loadEntered!.future;
      var stopped = false;
      final closing = h.host.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      await expectLater(pulse.createSphere(name: 'Stale'), throwsStateError);
      h.positions.loadGate!.complete();
      final graph = await opening;
      await closing;
      await expectLater(graph.createNote(), throwsStateError);
      expect(h.spheres.source.listeners, isEmpty);
    },
  );

  test(
    'a failed graph open releases its listeners and allows another graph',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await h.spheres.addSphere(sphere);
      await h.host.start();
      h.positions.failLoad = true;
      await expectLater(
        h.graph.viewModel.openGraph(sphere.id),
        throwsStateError,
      );
      h.positions.failLoad = false;
      final graph = await h.graph.viewModel.openGraph(sphere.id);
      await graph.createNote();
      await h.host.stop();
      expect(h.notes.values[sphere.id], hasLength(1));
      expect(h.spheres.source.listeners, isEmpty);
    },
  );

  test(
    'partial startup and screen collisions roll back every owned source',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      h.tasks.failWatch = true;
      await expectLater(
        h.host.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.spheres.source.listeners, isEmpty);
      expect(h.goals.source.listeners, isEmpty);
      expect(() => h.graph.viewModel, throwsStateError);
      h.tasks.failWatch = false;
      h.ui.register(
        'existing',
        screens: [
          PluginScreenContribution(
            id: 'pulse',
            label: 'Existing',
            icon: Icons.home,
            builder: (_, _) => const SizedBox(),
          ),
        ],
      );
      await expectLater(
        h.host.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.ui.screens.single.label, 'Existing');
      expect(h.spheres.source.listeners, isEmpty);
      expect(h.tasks.listeners, isEmpty);
      h.ui.unregister('existing');
      await h.host.start();
      expect(h.ui.screens.first.id, 'pulse');
    },
  );

  test(
    'a cancellation failure still flushes notes and releases all other sources',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await h.spheres.addSphere(sphere);
      await h.host.start();
      final graph = await h.graph.viewModel.openGraph(sphere.id);
      await graph.createNoteWithText(
        title: '',
        text: 'Saved despite cancellation error',
      );
      h.goals.source.failCancel = true;
      await expectLater(
        h.host.stop(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(
        h.notes.values[sphere.id]!.single.text,
        'Saved despite cancellation error',
      );
      expect(h.spheres.source.listeners, isEmpty);
      expect(h.goals.source.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.tasks.listeners, isEmpty);
      expect(h.notes.source.listeners, isEmpty);
      expect(h.vault.source.listeners, isEmpty);
      expect(h.vault.stopped, isTrue);
    },
  );

  test(
    'failed note saving reports shutdown failure and still releases sources',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await h.spheres.addSphere(sphere);
      await h.host.start();
      final graph = await h.graph.viewModel.openGraph(sphere.id);
      await graph.createNote();
      h.notes.failWrite = true;
      await expectLater(
        h.host.stop(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.ui.screens, isEmpty);
      expect(h.spheres.source.listeners, isEmpty);
      expect(h.tasks.listeners, isEmpty);
      expect(h.vault.stopped, isTrue);
    },
  );

  test(
    'version one coordinate snapshots keep their keys and JSON shape',
    () async {
      SharedPreferences.setMockInitialValues({
        'graph_positions.scope': '{"v":1,"entities":{"node":{"x":12,"y":34}}}',
        'life_graph.last_sphere': 'scope',
      });
      final store = GraphPositionsRepository();
      expect(
        (await store.loadPositions('scope'))!['node'],
        const GraphPoint(12, 34),
      );
      expect(await store.loadLastSphereId(), 'scope');
      await store.savePositions('scope', {'node': const GraphPoint(56, 78)});
      final prefs = await SharedPreferences.getInstance();
      expect(jsonDecode(prefs.getString('graph_positions.scope')!), {
        'v': 1,
        'entities': {
          'node': {'x': 56, 'y': 78},
        },
      });
    },
  );

  test(
    'application restart preserves notes, coordinates and Pulse selection',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await app.spheresRepository.addSphere(sphere);
      final firstPulse = app.pulseScreenViewModel;
      final firstResources = app.resourcesViewModel;
      final graph = await firstPulse.openGraph(sphere.id);
      await graph.graphStream.firstWhere((items) => items.isNotEmpty);
      graph.commitMove(sphere.id, 500, 600);
      await graph.createNoteWithText(title: '', text: 'Persisted');
      await app.plugins.stop();
      expect(() => app.pulseScreenViewModel, throwsStateError);
      expect(() => app.resourcesViewModel, throwsStateError);
      await app.plugins.start();
      final second = await app.pulseScreenViewModel.openGraph(sphere.id);
      final nodes = await second.graphStream.firstWhere(
        (items) => items.isNotEmpty,
      );
      expect(nodes.single.position, const Offset(500, 600));
      expect(second.notes.single.text, 'Persisted');
      expect(app.resourcesViewModel.getAllNotes().single.text, 'Persisted');
      expect(app.pulseScreenViewModel, isNot(same(firstPulse)));
      expect(app.resourcesViewModel, isNot(same(firstResources)));
      expect(app.navigation.selectedId, 'pulse');
      await expectLater(
        firstResources.updateNoteContent('old', 'stale'),
        throwsStateError,
      );
    },
  );

  test(
    'accepted note edits drain on stop and stale gestures cannot alter the saved snapshot',
    () async {
      final h = GraphResourcesHarness();
      addTearDown(h.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await h.spheres.addSphere(sphere);
      await h.host.start();
      final graph = await h.graph.viewModel.openGraph(sphere.id);
      await graph.createNote();
      final id = graph.notes.single.id;
      final edits = [
        for (var i = 0; i < 5; i++) graph.updateNoteText(id, 'Edit $i'),
      ];
      await Future.wait([...edits, h.host.stop()]);
      graph.commitNoteMove(id, 40, 40);
      graph.commitNoteResize(id, 800, 800);
      expect(h.notes.values[sphere.id]!.single.text, 'Edit 4');
      expect(h.notes.values[sphere.id]!.single.x, 2000);
      expect(h.notes.values[sphere.id]!.single.width, 212);
    },
  );

  testWidgets(
    'independent Pulse and Library render and stale screen actions stay inactive',
    (tester) async {
      final h = GraphResourcesHarness();
      await h.host.start();
      h.ui.register(
        'target',
        screens: [
          PluginScreenContribution(
            id: 'tasks',
            label: 'Tasks',
            icon: Icons.list,
            order: 10,
            builder: (_, _) => const Text('Target'),
          ),
        ],
      );
      final navigation = PluginNavigationController(h.ui);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PluginScreenDeck(navigation: navigation)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Independent Pulse'), findsOneWidget);
      final oldOpen = h.openTask!;
      final oldComplete = h.completeTask!;
      navigation.open('resources');
      await tester.pumpAndSettle();
      expect(find.text('Independent Library'), findsOneWidget);
      Future<void> lifecycle(Future<void> Function() action) async {
        var done = false;
        final operation = action().whenComplete(() => done = true);
        for (var i = 0; i < 50 && !done; i++) {
          await tester.pump(const Duration(milliseconds: 16));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(done, isTrue);
        await operation;
      }

      await lifecycle(h.host.stop);
      await lifecycle(h.host.start);
      navigation.open('pulse');
      await tester.pumpAndSettle();
      oldOpen(Task.blank());
      await oldComplete(Task.blank());
      expect(navigation.selectedId, 'pulse');
      expect(h.completions, 0);
      await h.completeTask!(Task.blank());
      expect(h.completions, 1);
      h.openTask!(Task.blank());
      expect(navigation.selectedId, 'tasks');
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      await lifecycle(h.dispose);
    },
  );
  test(
    'application restarts graph and resources with the real Obsidian adapter enabled',
    () async {
      final app = await createTestApp(enableObsidian: true);
      addTearDown(app.dispose);
      final sphere = Sphere.create(name: 'Scope');
      await app.spheresRepository.addSphere(sphere);
      final graph = await app.pulseScreenViewModel.openGraph(sphere.id);
      await graph.createNoteWithText(title: '', text: 'Local cached text');
      await app.plugins.stop();
      await app.plugins.start();
      expect(app.plugins.states['obsidian'], PluginState.active);
      expect(app.resourcesViewModel.hasVault, isTrue);
      expect(
        app.resourcesViewModel.getAllNotes().single.text,
        'Local cached text',
      );
      final reopened = await app.pulseScreenViewModel.openGraph(sphere.id);
      expect(reopened.notes.single.text, 'Local cached text');
    },
  );
  test('explicit save waits for previously accepted note edits', () async {
    final h = GraphResourcesHarness();
    addTearDown(h.dispose);
    final sphere = Sphere.create(name: 'Scope');
    await h.spheres.addSphere(sphere);
    await h.host.start();
    final graph = await h.graph.viewModel.openGraph(sphere.id);
    await graph.createNote();
    final editing = graph.updateNoteText(
      graph.notes.single.id,
      'Last typed text',
    );
    await graph.flush();
    await editing;
    expect(h.notes.values[sphere.id]!.single.text, 'Last typed text');
  });
}
