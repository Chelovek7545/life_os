import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import '../../../support/test_app.dart';
import '../support/editable_graph_module.dart';

class CustomContributor implements GraphContributor {
  @override
  String get id => 'sample.nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) => Stream.value([
    GraphNodeData(
      id: 'sample:entry',
      kind: 'sample.entry',
      title: 'Plugin entry',
      color: '#123456',
      parentId: scope.rootId,
      attributes: {'value': 42},
    ),
  ]);
}

GraphModule customModule() => GraphModule(
  id: 'sample.graph',
  dependencies: {'spheres.graph'},
  contributors: [CustomContributor()],
  presentations: [
    GraphNodePresentation(
      kind: 'sample.entry',
      size: const Size(210, 110),
      builder: (_, node, interaction) => SizedBox.expand(
        key: const ValueKey('sample_card'),
        child: ColoredBox(
          color: Colors.blue,
          child: Center(
            child: Text('Custom card: ${node.attributes['value']}'),
          ),
        ),
      ),
    ),
  ],
);

class FailingCancellationContributor extends CustomContributor {
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      Stream.multi((listener) {
        listener.add([
          GraphNodeData(
            id: 'sample:entry',
            kind: 'sample.entry',
            title: 'Plugin entry',
            color: '#123456',
            parentId: scope.rootId,
          ),
        ]);
        listener.onCancel = () async => throw StateError('Cancellation failed');
      });
}

void main() {
  test(
    'graph cancellation failure still flushes notes and releases the view model',
    () async {
      final app = await createTestApp(
        enableObsidian: false,
        graphModules: [
          GraphModule(
            id: 'sample.graph',
            dependencies: {'spheres.graph'},
            contributors: [FailingCancellationContributor()],
          ),
        ],
      );
      addTearDown(app.dispose);
      final sphere = Sphere.create(name: 'Root');
      await app.spheresRepository.addSphere(sphere);
      final vm = await app.pulseScreenViewModel.openGraph(sphere.id);
      await vm.graphStream.firstWhere((nodes) => nodes.length == 2);
      await vm.createNoteWithText(title: '', text: 'Pending note');
      await expectLater(vm.dispose(), throwsStateError);
      expect(
        (await app.graphNotesRepository.loadNotes(sphere.id))!.single.text,
        'Pending note',
      );
      // The failed view model must be removed from the app's open graphs.
      await app.dispose();
    },
  );

  testWidgets(
    'new module nodes use their own card and registered size in the graph screen',
    (tester) async {
      final app = (await tester.runAsync(
        () => createTestApp(
          enableObsidian: false,
          graphModules: [customModule()],
        ),
      ))!;
      final sphere = Sphere.create(name: 'Root');
      await tester.runAsync(() => app.spheresRepository.addSphere(sphere));
      final vm = (await tester.runAsync(
        () => app.pulseScreenViewModel.openGraph(sphere.id),
      ))!;
      await tester.runAsync(
        () => vm.graphStream.firstWhere((nodes) => nodes.length == 2),
      );
      expect(
        vm.graph.firstWhere((node) => node.id == 'sample:entry').size,
        const Size(210, 110),
      );
      await tester.pumpWidget(
        MaterialApp(home: LifeGraphScreen(viewModel: vm)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Custom card: 42'), findsOneWidget);
      final node = vm.nodeById('sample:entry')!;
      await tester.runAsync(() async {
        await expectLater(
          vm.updateNode(node.copyWith(title: 'Unsafe edit')),
          throwsUnsupportedError,
        );
        await expectLater(
          vm.deleteNode(node.id, keepChildren: false),
          throwsUnsupportedError,
        );
      });
      await disposeTestApp(tester, app);
    },
  );

  test(
    'presentation registration rolls back when contributor registration fails',
    () async {
      final registry = GraphContributorRegistry();
      final presentations = GraphNodePresentationRegistry();
      final editors = GraphEditorRegistry();
      final commands = GraphCommandRegistry();
      registry.register('existing', [CustomContributor()]);
      // Use a module without dependencies because this test only supplies that module.
      final isolated = GraphModule(
        id: 'sample.graph',
        contributors: [CustomContributor()],
        presentations: customModule().presentations,
        editors: [
          GraphNodeEditor(
            kind: 'sample.entry',
            builder: (_, _) => const SizedBox(),
          ),
        ],
        commands: [
          GraphNodeCommands(kind: 'sample.entry', update: (_) async {}),
        ],
      );
      final isolatedHost = PluginHost([
        GraphModulePlugin(
          module: isolated,
          contributors: registry,
          presentations: presentations,
          editors: editors,
          commands: commands,
        ),
      ]);
      await expectLater(
        isolatedHost.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(presentations.lookup('sample.entry'), isNull);
      expect(editors.hasEditor('sample.entry'), isFalse);
      expect(commands.canUpdate('sample.entry'), isFalse);
      expect(registry.contributors.single.id, 'sample.nodes');
      await registry.dispose();
      await commands.dispose();
      presentations.dispose();
      editors.dispose();
    },
  );

  test(
    'stopping a module drains commands before releasing its data source and UI',
    () async {
      final feature = EditableGraphModule()..createGate = Completer<void>();
      final registry = GraphContributorRegistry();
      final commands = GraphCommandRegistry();
      final presentations = GraphNodePresentationRegistry();
      final editors = GraphEditorRegistry();
      final spec = feature.module;
      final host = PluginHost([
        GraphModulePlugin(
          module: GraphModule(
            id: spec.id,
            contributors: spec.contributors,
            presentations: spec.presentations,
            commands: spec.commands,
          ),
          contributors: registry,
          commands: commands,
          presentations: presentations,
          editors: editors,
        ),
      ]);
      await host.start();
      const scope = GraphScope(rootId: 'root', rootKind: 'sphere');
      final subscription = registry.contributors.single
          .watch(scope)
          .listen((_) {});
      final creating = commands.create(
        GraphCreateRequest(
          scope: scope,
          parent: GraphNodeData(
            id: 'root',
            kind: 'sphere',
            title: 'Root',
            color: '#123456',
          ),
          draft: GraphNodeDraft(kind: 'editable.entry', title: 'Pending'),
        ),
      );
      await feature.createEntered.future;
      var stopped = false;
      final stopping = host.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(commands.canCreate('editable.entry', 'sphere'), isFalse);
      expect(stopped, isFalse);
      expect(feature.listeners, 1);
      expect(presentations.lookup('editable.entry'), isNotNull);
      feature.createGate!.complete();
      await creating;
      await stopping;
      expect(feature.listeners, 0);
      expect(presentations.lookup('editable.entry'), isNull);
      await subscription.cancel();
      await commands.dispose();
      await registry.dispose();
      presentations.dispose();
      editors.dispose();
      await feature.changes.close();
    },
  );
  test(
    'command registration failure rolls back UI and preserves the previous command owner',
    () async {
      final contributors = GraphContributorRegistry();
      final commands = GraphCommandRegistry();
      final presentations = GraphNodePresentationRegistry();
      final editors = GraphEditorRegistry();
      commands.register('previous', [
        GraphNodeCommands(kind: 'sample.entry', update: (_) async {}),
      ]);
      final host = PluginHost([
        GraphModulePlugin(
          module: GraphModule(
            id: 'sample.graph',
            contributors: [CustomContributor()],
            presentations: customModule().presentations,
            commands: [
              GraphNodeCommands(kind: 'sample.entry', update: (_) async {}),
            ],
          ),
          contributors: contributors,
          commands: commands,
          presentations: presentations,
          editors: editors,
        ),
      ]);
      await expectLater(host.start(), throwsA(isA<PluginLifecycleException>()));
      expect(contributors.contributors, isEmpty);
      expect(presentations.lookup('sample.entry'), isNull);
      expect(commands.canUpdate('sample.entry'), isTrue);
      await commands.dispose();
      await contributors.dispose();
      presentations.dispose();
      editors.dispose();
    },
  );
}
