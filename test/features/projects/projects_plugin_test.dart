import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:projects_api/projects_api.dart';
import 'package:projects_plugin/projects_plugin.dart';
import 'package:tasks_api/tasks_api.dart';
import '../../support/test_app.dart';

class MemoryProjects implements ProjectsApi {
  final items = <String, Project>{};
  final listeners = <MultiStreamController<List<Project>>>{};
  int watches = 0;
  Completer<void>? writeGate;
  Completer<void>? entered;
  bool failWrite = false;
  bool failCancel = false;
  bool failWatch = false;
  @override
  Stream<List<Project>> watchAllProjects() {
    if (failWatch) throw StateError('Cannot open project source');
    return Stream.multi((listener) {
      watches++;
      listeners.add(listener);
      listener.add(items.values.toList());
      listener.onCancel = () async {
        listeners.remove(listener);
        if (failCancel) throw StateError('Cancel failed');
      };
    });
  }

  void emit(List<Project> snapshot) {
    for (final listener in listeners) {
      listener.add(snapshot);
    }
  }

  @override
  Future<List<Project>> getAllProjects() async => items.values.toList();
  @override
  Future<Project?> getProjectById(String id) async => items[id];
  Future<void> _write(void Function() action) async {
    if (entered case final entered? when !entered.isCompleted) {
      entered.complete();
    }
    await writeGate?.future;
    if (failWrite) {
      failWrite = false;
      throw StateError('Write failed');
    }
    action();
    emit(items.values.toList());
  }

  @override
  Future<void> addProject(Project project) =>
      _write(() => items[project.id] = project);
  @override
  Future<void> updateProject(Project project) =>
      _write(() => items[project.id] = project);
  @override
  Future<void> deleteProject(String id) => _write(() => items.remove(id));
}

class EmptyTasks extends Fake implements TasksApi {
  @override
  Stream<List<Task>> watchTasks() => Stream.value([]);
  @override
  Stream<List<Task>> watchTasksForProject(String projectId) => Stream.value([]);
}

class Harness {
  final store = MemoryProjects();
  final contributors = GraphContributorRegistry();
  final cards = GraphNodePresentationRegistry();
  final editors = GraphEditorRegistry();
  final commands = GraphCommandRegistry();
  final ui = PluginUiRegistry();
  late final module = ProjectsPlugin(
    projects: store,
    tasks: EmptyTasks(),
    contributors: contributors,
    presentations: cards,
    editors: editors,
    commands: commands,
    ui: ui,
    delete: (request) async {
      await store.deleteProject(request.node.id);
      return {request.node.id};
    },
    visuals: ProjectsUiBindings(
      screen: (_, _) => const Text('Independent project screen'),
      nodeCard: (_, node, _) => Text(node.title),
      nodeSize: const Size(180, 120),
      editor: (_, _) => const SizedBox(),
      createForm: (_, _) => const SizedBox(),
    ),
  );
  late final host = PluginHost([
    UiModule(id: 'goals.graph'),
    ...module.plugins,
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

GraphNodeData graphNode(
  String id,
  String kind, {
  String? parent,
  String title = 'Node',
}) => GraphNodeData(
  id: id,
  kind: kind,
  title: title,
  color: '#123456',
  parentId: parent,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const scope = GraphScope(rootId: 'sphere', rootKind: 'sphere');
  testWidgets(
    'registered project screen renders with supplied UI ports alone',
    (tester) async {
      final h = Harness();
      await h.host.start();
      final navigation = PluginNavigationController(h.ui);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PluginScreenDeck(navigation: navigation)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Independent project screen'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      await h.dispose();
    },
  );
  test(
    'module runs with API ports and supplied views without application classes',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.host.start();
      expect(h.store.listeners, hasLength(1));
      expect(h.ui.screens.single.id, 'projects');
      final id = await h.commands.create(
        GraphCreateRequest(
          scope: scope,
          parent: graphNode('goal', 'goal'),
          draft: GraphNodeDraft(kind: 'project', title: 'Root'),
        ),
      );
      final nested = await h.commands.create(
        GraphCreateRequest(
          scope: scope,
          parent: graphNode(id, 'project'),
          draft: GraphNodeDraft(kind: 'project', title: 'Nested'),
        ),
      );
      expect(h.store.items[nested]!.parentProejectId, id);
      final snapshot = await h.contributors.contributors.single
          .watch(scope)
          .first;
      final current = snapshot.firstWhere((node) => node.id == nested);
      await h.commands.update(
        GraphUpdateRequest(
          scope: scope,
          current: current,
          updated: graphNode(nested, 'project', parent: id, title: 'Renamed'),
        ),
      );
      expect(h.store.items[nested]!.name, 'Renamed');
      expect(h.store.items[nested]!.parentProejectId, id);
      await h.commands.delete(
        GraphDeleteRequest(scope: scope, node: current, keepChildren: false),
      );
      expect(h.store.items.containsKey(nested), isFalse);
    },
  );

  test(
    'stop and restart create a fresh screen model and preserve stored projects',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.host.start();
      final first = h.module.viewModel;
      final project = Project.create(name: 'Persisted');
      await first.addProjects(project);
      await h.host.stop();
      expect(h.store.listeners, isEmpty);
      expect(h.ui.screens, isEmpty);
      expect(h.commands.canUpdate('project'), isFalse);
      expect(h.cards.lookup('project'), isNull);
      expect(() => h.module.viewModel, throwsStateError);
      await expectLater(
        first.addProjects(Project.create(name: 'Too late')),
        throwsStateError,
      );
      await h.host.start();
      final second = h.module.viewModel;
      expect(identical(first, second), isFalse);
      final state =
          await second.state.firstWhere((state) => state is ProjectsLoaded)
              as ProjectsLoaded;
      expect(state.projects.single.id, project.id);
      expect(h.store.listeners, hasLength(1));
    },
  );

  test(
    'screen shutdown waits for accepted writes before releasing registrations',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.host.start();
      final vm = h.module.viewModel;
      h.store.writeGate = Completer<void>();
      h.store.entered = Completer<void>();
      final project = Project.create(name: 'Pending');
      final saving = vm.addProjects(project);
      await h.store.entered!.future;
      var done = false;
      final stopping = h.host.stop().then((_) => done = true);
      await Future<void>.delayed(Duration.zero);
      expect(done, isFalse);
      expect(h.ui.screens, isEmpty);
      await expectLater(
        vm.addProjects(Project.create(name: 'Rejected')),
        throwsStateError,
      );
      h.store.writeGate!.complete();
      await saving;
      await stopping;
      expect(h.store.items[project.id]!.name, 'Pending');
      expect(h.store.listeners, isEmpty);
    },
  );

  test(
    'initialization is idempotent and published snapshots do not share mutable lists',
    () async {
      final store = MemoryProjects();
      final vm = ProjectsViewModel(repository: store, taskRepo: EmptyTasks());
      addTearDown(vm.dispose);
      vm.initialize();
      vm.initialize();
      expect(store.watches, 1);
      final project = Project.create(name: 'Snapshot');
      final mutable = [project];
      store.emit(mutable);
      final state =
          await vm.state.firstWhere(
                (value) => value is ProjectsLoaded && value.projects.isNotEmpty,
              )
              as ProjectsLoaded;
      mutable.clear();
      expect(state.projects.single.id, project.id);
      expect(() => state.projects.clear(), throwsUnsupportedError);
    },
  );

  test(
    'failed writes do not poison subsequent operations or cleanup',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.host.start();
      h.store.failWrite = true;
      await expectLater(
        h.module.viewModel.addProjects(Project.create(name: 'Failed')),
        throwsStateError,
      );
      final next = Project.create(name: 'Retry');
      await h.module.viewModel.addProjects(next);
      expect(h.store.items.keys, [next.id]);
      await h.host.stop();
      expect(h.store.listeners, isEmpty);
    },
  );

  test(
    'failed screen registration closes its model and rolls back graph contributions',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      h.ui.register(
        'existing',
        screens: [
          PluginScreenContribution(
            id: 'projects',
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
      expect(h.store.watches, 1);
      expect(h.store.listeners, isEmpty);
      expect(h.ui.screens.single.label, 'Existing');
      expect(h.contributors.contributors, isEmpty);
      expect(h.cards.lookup('project'), isNull);
      expect(h.editors.hasEditor('project'), isFalse);
      expect(h.commands.canUpdate('project'), isFalse);
      expect(() => h.module.viewModel, throwsStateError);
    },
  );

  test(
    'a source startup failure releases the partial model and permits a clean retry',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      h.store.failWatch = true;
      await expectLater(
        h.host.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(() => h.module.viewModel, throwsStateError);
      expect(h.ui.screens, isEmpty);
      expect(h.contributors.contributors, isEmpty);
      expect(h.commands.canUpdate('project'), isFalse);
      h.store.failWatch = false;
      await h.host.start();
      expect(h.ui.screens.single.id, 'projects');
      expect(h.store.listeners, hasLength(1));
    },
  );

  test(
    'a cancellation failure still clears screen, model and graph registrations',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      await h.host.start();
      final vm = h.module.viewModel;
      h.store.failCancel = true;
      await expectLater(
        h.host.stop(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.store.listeners, isEmpty);
      expect(h.ui.screens, isEmpty);
      expect(h.contributors.contributors, isEmpty);
      expect(h.editors.hasEditor('project'), isFalse);
      expect(h.commands.canUpdate('project'), isFalse);
      await expectLater(vm.deleteProject('any'), throwsStateError);
    },
  );

  test(
    'application composition delegates project model lifecycle to the plugin',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final first = app.projectViewModel;
      final project = Project.create(name: 'SQLite record');
      await first.addProjects(project);
      await app.plugins.stop();
      expect(() => app.projectViewModel, throwsStateError);
      await app.plugins.start();
      final second = app.projectViewModel;
      expect(identical(first, second), isFalse);
      expect((await second.getProject(project.id))!.name, project.name);
      expect(app.navigation.selectedId, 'pulse');
    },
  );
}
