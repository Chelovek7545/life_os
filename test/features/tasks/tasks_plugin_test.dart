import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_plugin.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import '../../support/test_app.dart';
import 'support/memory_tasks.dart';

class TasksHarness {
  final tasks = MemoryTasks();
  final projects = MemoryProjectQueries();
  final logs = MemoryWorkLogs();
  final ui = PluginUiRegistry();
  final contributors = GraphContributorRegistry();
  final cards = GraphNodePresentationRegistry();
  final editors = GraphEditorRegistry();
  final commands = GraphCommandRegistry();
  late Stream<List<Task>> Function() formSource;
  TasksNodeUi get node => TasksNodeUi(
    size: const Size(180, 120),
    card: (_, data, _) => Text(data.title),
    editor: (_, _) => const SizedBox(),
    create: (_, _) => const SizedBox(),
    attach: (watchTasks) {
      formSource = watchTasks;
      return (_, _) => const SizedBox();
    },
  );
  late final module = TasksPlugin(
    tasks: tasks,
    projects: projects,
    workLogs: logs,
    ui: ui,
    contributors: contributors,
    presentations: cards,
    editors: editors,
    commands: commands,
    delete: (request) async {
      await tasks.deleteTask(request.node.id);
      return {request.node.id};
    },
    visuals: TasksUiBindings(
      screen: (_, _, _, _) => const Text('Independent tasks screen'),
      task: node,
      subtask: node,
    ),
  );
  late final host = PluginHost([
    UiModule(id: 'projects.graph'),
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

Future<void> pumpLifecycle(
  WidgetTester tester,
  Future<void> Function() action,
) async {
  var done = false;
  final operation = action().whenComplete(() => done = true);
  for (var i = 0; i < 50 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(
    done,
    isTrue,
    reason: 'Plugin lifecycle must finish releasing its streams.',
  );
  await operation;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const scope = GraphScope(rootId: 'project', rootKind: 'project');

  test(
    'standalone plugin owns state, task graph commands and work log scope',
    () async {
      final h = TasksHarness();
      addTearDown(h.dispose);
      await h.host.start();
      await h.module.viewModel.state.firstWhere((state) => state is TasksEmpty);
      expect(h.tasks.listeners, hasLength(1));
      expect(h.projects.listeners, hasLength(1));
      expect(h.ui.screens.single.id, 'tasks');
      final picker = h.formSource().listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(h.tasks.listeners, hasLength(2));
      final task = await h.commands.create(
        GraphCreateRequest(
          scope: scope,
          parent: GraphNodeData(
            id: 'project',
            kind: 'project',
            title: 'P',
            color: '#000000',
          ),
          draft: GraphNodeDraft(kind: 'task', title: 'Root'),
        ),
      );
      final subtask = await h.commands.create(
        GraphCreateRequest(
          scope: scope,
          parent: GraphNodeData(
            id: task,
            kind: 'task',
            title: 'Root',
            color: '#000000',
          ),
          draft: GraphNodeDraft(kind: 'subTask', title: 'Child'),
        ),
      );
      expect(h.tasks.items[subtask]!.parentTaskId, task);
      expect(h.tasks.items[task]!.projectId, 'project');
      expect(h.cards.lookup('subTask'), isNotNull);
      final logs = h.module.workLogs;
      final sub = logs.watchWorkLogsForTask(task).listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await h.host.stop();
      expect(h.tasks.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.logs.listeners, isEmpty);
      expect(h.commands.canUpdate('task'), isFalse);
      expect(h.editors.hasEditor('subTask'), isFalse);
      expect(h.ui.screens, isEmpty);
      await expectLater(logs.deleteWorkLog('old'), throwsStateError);
      await sub.cancel();
      await picker.cancel();
      expect(await h.formSource().first, isEmpty);
    },
  );

  test(
    'stop removes screen and drains both task and work log writes',
    () async {
      final h = TasksHarness();
      addTearDown(h.dispose);
      await h.host.start();
      final model = h.module.viewModel;
      final logs = h.module.workLogs;
      h.tasks.writeGate = Completer<void>();
      h.tasks.entered = Completer<void>();
      h.logs.writeGate = Completer<void>();
      h.logs.entered = Completer<void>();
      final task = Task.blank();
      final writeTask = model.addTask(task);
      final writeLog = logs.addWorkLog(
        WorkLog(
          id: 'log',
          taskId: task.id,
          status: 0,
          date: DateTime(2026),
          description: 'Step',
        ),
      );
      await Future.wait([h.tasks.entered!.future, h.logs.entered!.future]);
      final removed = Completer<void>();
      h.ui.addListener(() {
        if (h.ui.screens.isEmpty && !removed.isCompleted) removed.complete();
      });
      var closed = false;
      final stop = h.host.stop().then((_) => closed = true);
      await removed.future;
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      await expectLater(model.addTask(Task.blank()), throwsStateError);
      await expectLater(logs.deleteWorkLog('log'), throwsStateError);
      h.tasks.writeGate!.complete();
      h.logs.writeGate!.complete();
      await Future.wait([writeTask, writeLog]);
      await stop;
      expect(h.tasks.items.containsKey(task.id), isTrue);
      expect(h.logs.items.containsKey('log'), isTrue);
    },
  );

  test(
    'registration collision rolls back task resources and preserves prior screen',
    () async {
      final h = TasksHarness();
      addTearDown(h.dispose);
      h.ui.register(
        'existing',
        screens: [
          PluginScreenContribution(
            id: 'tasks',
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
      expect(h.tasks.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.contributors.contributors, isEmpty);
      expect(h.commands.canCreate('task', 'project'), isFalse);
      expect(h.ui.screens.single.label, 'Existing');
      expect(() => h.module.viewModel, throwsStateError);
      expect(() => h.module.workLogs, throwsStateError);
    },
  );

  test(
    'failed startup can be retried and cancellation errors still release resources',
    () async {
      final h = TasksHarness();
      addTearDown(h.dispose);
      h.tasks.failWatch = true;
      await expectLater(
        h.host.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.ui.screens, isEmpty);
      h.tasks.failWatch = false;
      await h.host.start();
      final model = h.module.viewModel;
      await model.state.firstWhere((state) => state is TasksEmpty);
      h.tasks.failCancel = true;
      await expectLater(
        h.host.stop(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.ui.screens, isEmpty);
      expect(h.tasks.listeners, isEmpty);
      expect(h.projects.listeners, isEmpty);
      expect(h.commands.canUpdate('task'), isFalse);
      await model.state.drain<void>();
    },
  );

  testWidgets(
    'supplied screen renders and stale navigation cannot reopen a new instance',
    (tester) async {
      final h = TasksHarness();
      await h.host.start();
      final navigation = PluginNavigationController(h.ui);
      final oldContext = navigation.contextFor(h.ui.screens.single);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PluginScreenDeck(navigation: navigation)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Independent tasks screen'), findsOneWidget);
      final first = h.module.viewModel;
      await pumpLifecycle(tester, h.host.stop);
      await tester.pumpAndSettle();
      await pumpLifecycle(tester, h.host.start);
      await tester.pumpAndSettle();
      expect(h.module.viewModel, isNot(same(first)));
      expect(oldContext.openScreen('tasks', argument: Task.blank()), isFalse);
      expect(h.module.viewModel.activeTaskWithProject, isNull);
      navigation.open('tasks', argument: Task.blank());
      expect(h.module.viewModel.currentUiFlags.isFormVisible, isTrue);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      await pumpLifecycle(tester, h.dispose);
    },
  );

  test(
    'application restart retains tasks, tags, work logs and selected Pulse navigation',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final first = app.tasksViewModel;
      final task = Task.blank().copyWith(
        title: 'Persisted',
        tags: [Tag(id: 42, name: 'work', colorHex: 123)],
      );
      await first.addTask(task);
      final logs = app.tasksPlugin.workLogs;
      await logs.addWorkLog(
        WorkLog(
          id: 'log',
          taskId: task.id,
          date: DateTime(2026),
          status: 1,
          description: 'Saved step',
        ),
      );
      await app.plugins.stop();
      await app.plugins.start();
      expect(app.tasksViewModel, isNot(same(first)));
      expect(
        (await app.tasksViewModel.getTask(task.id))!.tags.single.name,
        'work',
      );
      expect(
        (await app.tasksPlugin.workLogs.getById('log'))!.description,
        'Saved step',
      );
      await expectLater(first.deleteTask(task.id), throwsStateError);
      await expectLater(logs.deleteWorkLog('log'), throwsStateError);
      expect(app.navigation.selectedId, 'pulse');
    },
  );
}
