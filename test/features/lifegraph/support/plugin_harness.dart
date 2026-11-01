import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:resources_plugin/resources_plugin.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import '../../../support/memory_graph_sources.dart';
import '../../tasks/support/memory_tasks.dart';

class GraphResourcesHarness {
  final spheres = MemorySpheres();
  final goals = MemoryGoals();
  final projects = MemoryProjectQueries();
  final tasks = MemoryTasks();
  final positions = MemoryPositions();
  final notes = MemoryCanvasNotes();
  final vault = MemoryVault();
  final ui = PluginUiRegistry();
  final contributors = GraphContributorRegistry();
  final cards = GraphNodePresentationRegistry();
  final editors = GraphEditorRegistry();
  final commands = GraphCommandRegistry();
  void Function(Task)? openTask;
  Future<void> Function(Task)? completeTask;
  int completions = 0;
  late final graph = LifeGraphPlugin(
    spheres: spheres,
    goals: goals,
    projects: projects,
    tasks: tasks,
    positions: positions,
    notes: notes,
    vault: vault,
    ui: ui,
    contributors: contributors,
    presentations: cards,
    editors: editors,
    commands: commands,
    dependencies: {'domain.graph', 'source'},
    completeTask: (_) async {
      completions++;
    },
    screen: (_, _, _, open, complete) {
      openTask = open;
      completeTask = complete;
      return const Text('Independent Pulse');
    },
  );
  late final resources = ResourcesPlugin(
    notes: notes,
    vault: vault,
    ui: ui,
    dependencies: {'source'},
    screen: (_, _) => const Text('Independent Library'),
  );
  late final domain = GraphModulePlugin(
    module: GraphModule(
      id: 'domain.graph',
      dependencies: {'source'},
      contributors: [_RootContributor(spheres)],
      commands: [
        GraphNodeCommands(
          kind: 'sphere',
          parentKinds: {},
          update: (_) async {},
        ),
      ],
    ),
    contributors: contributors,
    presentations: cards,
    editors: editors,
    commands: commands,
  );
  late final source = _SourceLifecycle(vault);
  late final host = PluginHost([
    ...graph.plugins,
    ...resources.plugins,
    domain,
    source,
  ]);
  Future<void> dispose() async {
    try {
      await host.stop();
    } catch (_) {}
    await contributors.dispose();
    await commands.dispose();
    cards.dispose();
    editors.dispose();
    ui.dispose();
  }
}

class _RootContributor implements GraphContributor {
  _RootContributor(this.spheres);
  final MemorySpheres spheres;
  @override
  String get id => 'root.nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      spheres.watchAllSpheres().map(
        (items) => [
          for (final sphere in items)
            GraphNodeData(
              id: sphere.id,
              kind: 'sphere',
              title: sphere.name,
              color: sphere.color,
            ),
        ],
      );
}

class _SourceLifecycle implements AppPlugin {
  _SourceLifecycle(this.vault);
  final MemoryVault vault;
  @override
  String get id => 'source';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    vault.stopped = false;
  }

  @override
  Future<void> stop() async {
    vault.stopped = true;
    vault.events.add('source.stop');
  }
}
