import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_view_model.dart';
import '../../../support/test_app.dart';
import '../support/editable_graph_module.dart';

class FailingEditorRegistry extends GraphEditorRegistry {
  @override
  void unregister(String owner) {
    super.unregister(owner);
    throw StateError('Editor cleanup failed');
  }
}

class TextForm extends StatefulWidget {
  const TextForm({
    super.key,
    required this.title,
    required this.save,
    this.initial = '',
  });
  final String title;
  final String initial;
  final Future<void> Function(String) save;
  @override
  State<TextForm> createState() => _TextFormState();
}

class _TextFormState extends State<TextForm> {
  late final controller = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(controller: controller),
    actions: [
      TextButton(
        onPressed: () async {
          await widget.save(controller.text);
          if (mounted) Navigator.pop(context);
        },
        child: const Text('Save sample'),
      ),
    ],
  );
}

GraphNodeData renamed(GraphNodeData node, String title) => GraphNodeData(
  id: node.id,
  kind: node.kind,
  title: title,
  subtitle: node.subtitle,
  color: node.color,
  parentId: node.parentId,
  attributes: node.attributes,
);

GraphNodeEditor sampleEditor({
  void Function(GraphNodeActionContext)? capture,
}) => GraphNodeEditor(
  kind: 'editable.entry',
  builder: (_, actions) {
    capture?.call(actions);
    return TextForm(
      title: 'Sample editor',
      initial: actions.node.title,
      save: (text) => actions.updateNode(renamed(actions.node, text)),
    );
  },
);

GraphChildAction sampleAction() => GraphChildAction(
  id: 'editable.create',
  label: 'Sample entry',
  childKind: 'editable.entry',
  parentKinds: {'sphere'},
  builder: (_, actions) => TextForm(
    title: 'Create sample',
    save: (text) async {
      await actions.createChild(
        GraphNodeDraft(kind: 'editable.entry', title: text),
      );
    },
  ),
);

Future<void> settleUntil(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100 && !ready(); i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(ready(), isTrue);
  await tester.pump();
}

Future<void> showGraph(WidgetTester tester, LifeGraphViewModel vm) async {
  await tester.pumpWidget(MaterialApp(home: LifeGraphScreen(viewModel: vm)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 1000));
}

Finder plusFor(String id) => find.descendant(
  of: find.byKey(ValueKey(id)),
  matching: find.byTooltip('Добавить элемент'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'editor cleanup failure still releases commands, sources and cards',
    () async {
      final feature = EditableGraphModule();
      final spec = feature.module;
      final editors = FailingEditorRegistry();
      final commands = GraphCommandRegistry();
      final sources = GraphContributorRegistry();
      final cards = GraphNodePresentationRegistry();
      final host = PluginHost([
        GraphModulePlugin(
          module: GraphModule(
            id: spec.id,
            contributors: spec.contributors,
            commands: spec.commands,
            presentations: spec.presentations,
            editors: [sampleEditor()],
          ),
          contributors: sources,
          presentations: cards,
          commands: commands,
          editors: editors,
        ),
      ]);
      await host.start();
      final subscription = sources.contributors.single
          .watch(const GraphScope(rootId: 'root', rootKind: 'sphere'))
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);
      expect(feature.listeners, 1);
      await expectLater(host.stop(), throwsA(isA<PluginLifecycleException>()));
      expect(editors.hasEditor('editable.entry'), isFalse);
      expect(commands.canUpdate('editable.entry'), isFalse);
      expect(sources.contributors, isEmpty);
      expect(feature.listeners, 0);
      expect(cards.lookup('editable.entry'), isNull);
      await subscription.cancel();
      await commands.dispose();
      await sources.dispose();
      cards.dispose();
      editors.dispose();
      await feature.changes.close();
    },
  );

  testWidgets(
    'project menu creates a nested project and attaches an existing task',
    (tester) async {
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final sphere = Sphere.create(name: 'Root');
      final goal = Goal.create(name: 'Goal', sphereId: sphere.id);
      final project = Project.create(name: 'Project', goalId: goal.id);
      final detached = Task.blank().copyWith(title: 'Attach me');
      late LifeGraphViewModel vm;
      await tester.runAsync(() async {
        await app.spheresRepository.addSphere(sphere);
        await app.goalsRepository.addGoal(goal);
        await app.projectsRepository.addProject(project);
        await app.tasksRepository.addTask(detached);
        vm = await app.pulseScreenViewModel.openGraph(sphere.id);
        await vm.graphStream.firstWhere((nodes) => nodes.length == 3);
      });
      await showGraph(tester, vm);
      await tester.tap(plusFor(project.id));
      await tester.pumpAndSettle();
      expect(find.text('Существующую задачу'), findsOneWidget);
      expect(find.text('Новую задачу'), findsOneWidget);
      await tester.tap(find.text('Новый подпроект'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Nested from UI');
      await tester.tap(find.text('Создать'));
      await settleUntil(
        tester,
        () => vm.graph.length == 4 && find.byType(TextField).evaluate().isEmpty,
      );
      await tester.runAsync(() async {
        final saved = (await app.projectsRepository.getAllProjects())
            .firstWhere((p) => p.name == 'Nested from UI');
        expect(saved.parentProejectId, project.id);
        expect(saved.goalId, isNull);
      });
      await tester.tap(plusFor(project.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Существующую задачу'));
      await settleUntil(
        tester,
        () => find.text('Attach me').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Attach me'));
      await settleUntil(tester, () => vm.graph.length == 5);
      await tester.runAsync(
        () async => expect(
          (await app.tasksRepository.getById(detached.id))!.projectId,
          project.id,
        ),
      );
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'built-in editor is opened through registration and saves its node',
    (tester) async {
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final sphere = Sphere.create(name: 'Original sphere');
      late LifeGraphViewModel vm;
      await tester.runAsync(() async {
        await app.spheresRepository.addSphere(sphere);
        vm = await app.pulseScreenViewModel.openGraph(sphere.id);
        await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
      });
      await showGraph(tester, vm);
      await tester.longPress(find.text('Original sphere').first);
      await tester.pumpAndSettle();
      expect(find.text('Редактировать сферу'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Edited sphere');
      await tester.tap(find.text('Сохранить'));
      await settleUntil(
        tester,
        () => vm.nodeById(sphere.id)?.title == 'Edited sphere',
      );
      await tester.runAsync(
        () async => expect(
          (await app.spheresRepository.getSphere(sphere.id))!.name,
          'Edited sphere',
        ),
      );
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'new kind contributes creation and editing forms to the unchanged graph screen',
    (tester) async {
      final feature = EditableGraphModule();
      final spec = feature.module;
      final module = GraphModule(
        id: spec.id,
        dependencies: spec.dependencies,
        contributors: spec.contributors,
        commands: spec.commands,
        editors: [sampleEditor()],
        childActions: [sampleAction()],
      );
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false, graphModules: [module]),
      ))!;
      final sphere = Sphere.create(name: 'Root');
      late LifeGraphViewModel vm;
      await tester.runAsync(() async {
        await app.spheresRepository.addSphere(sphere);
        vm = await app.pulseScreenViewModel.openGraph(sphere.id);
        await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
      });
      await showGraph(tester, vm);
      await tester.tap(plusFor(sphere.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sample entry'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'Created via registered form',
      );
      await tester.tap(find.text('Save sample'));
      await settleUntil(
        tester,
        () => vm.graph.length == 2 && find.byType(TextForm).evaluate().isEmpty,
      );
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pump(const Duration(milliseconds: 1000));
      const id = 'editable:1';
      await tester.tap(find.byKey(const ValueKey('graph-actions:$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Изменить'));
      await tester.pumpAndSettle();
      expect(find.text('Sample editor'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField),
        'Edited via registered form',
      );
      await tester.tap(find.text('Save sample'));
      await settleUntil(
        tester,
        () =>
            vm.nodeById(id)?.title == 'Edited via registered form' &&
            find.byType(TextForm).evaluate().isEmpty,
      );
      await tester.tap(find.byKey(const ValueKey('graph-actions:$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      // A confirmation opened for a previous command owner must not act on a
      // replacement registered with the same module ID and node kind.
      await tester.runAsync(() async {
        await app.graphCommands.unregister(spec.id);
        app.graphCommands.register(spec.id, spec.commands);
      });
      await tester.tap(find.text('Удалить всё поддерево'));
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось удалить узел. Повторите попытку.'),
        findsOneWidget,
      );
      expect(feature.nodes, isNotEmpty);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('graph-actions:$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить всё поддерево'));
      await settleUntil(tester, () => vm.graph.length == 1);
      expect(feature.nodes, isEmpty);
      await disposeTestApp(tester, app);
      await feature.changes.close();
    },
  );

  test('editor and action registration is atomic on collisions', () {
    final registry = GraphEditorRegistry();
    registry.register(
      'first',
      editors: [sampleEditor()],
      childActions: [sampleAction()],
    );
    expect(
      () => registry.register(
        'second',
        editors: [sampleEditor()],
        childActions: [
          GraphChildAction(
            id: 'new',
            label: 'New',
            childKind: 'new',
            parentKinds: {'sphere'},
            builder: (_, _) => const SizedBox(),
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(registry.childActions('sphere').map((a) => a.id), [
      'editable.create',
    ]);
    expect(
      () => registry.register(
        'third',
        editors: [
          GraphNodeEditor(kind: 'new', builder: (_, _) => const SizedBox()),
        ],
        childActions: [sampleAction()],
      ),
      throwsArgumentError,
    );
    expect(registry.hasEditor('new'), isFalse);
    registry.dispose();
  });

  test(
    'failed editor registration rolls back commands and cards and preserves previous forms',
    () async {
      final editors = GraphEditorRegistry()
        ..register('existing', editors: [sampleEditor()]);
      final commands = GraphCommandRegistry();
      final sources = GraphContributorRegistry();
      final cards = GraphNodePresentationRegistry();
      final host = PluginHost([
        GraphModulePlugin(
          module: GraphModule(
            id: 'duplicate',
            editors: [sampleEditor()],
            commands: [GraphNodeCommands(kind: 'new', update: (_) async {})],
            presentations: [
              GraphNodePresentation(
                kind: 'new',
                size: const Size(100, 100),
                builder: (_, _, _) => const SizedBox(),
              ),
            ],
          ),
          contributors: sources,
          presentations: cards,
          commands: commands,
          editors: editors,
        ),
      ]);
      await expectLater(host.start(), throwsA(isA<PluginLifecycleException>()));
      expect(editors.hasEditor('editable.entry'), isTrue);
      expect(commands.canUpdate('new'), isFalse);
      expect(cards.lookup('new'), isNull);
      expect(sources.contributors, isEmpty);
      await commands.dispose();
      await sources.dispose();
      cards.dispose();
      editors.dispose();
    },
  );

  test(
    'a form cannot mutate after switching away and back to the same graph',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final first = Sphere.create(name: 'First');
      final second = Sphere.create(name: 'Second');
      await app.spheresRepository.addSphere(first);
      await app.spheresRepository.addSphere(second);
      final vm = await app.pulseScreenViewModel.openGraph(first.id);
      await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
      final actions = vm.actionsFor(first.id);
      await vm.switchSphere(second.id);
      await vm.switchSphere(first.id);
      await expectLater(
        actions.createChild(GraphNodeDraft(kind: 'goal', title: 'Stale')),
        throwsStateError,
      );
      expect(await app.goalsRepository.getAllGoals(), isEmpty);
    },
  );

  test(
    'form validity is checked again when a queued mutation starts',
    () async {
      final feature = EditableGraphModule()..createGate = Completer<void>();
      final app = await createTestApp(
        enableObsidian: false,
        graphModules: [feature.module],
      );
      addTearDown(feature.changes.close);
      addTearDown(app.dispose);
      final first = Sphere.create(name: 'First');
      final second = Sphere.create(name: 'Second');
      await app.spheresRepository.addSphere(first);
      await app.spheresRepository.addSphere(second);
      final vm = await app.pulseScreenViewModel.openGraph(first.id);
      await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
      final actions = vm.actionsFor(first.id);
      final creating = vm.createChild(
        first.id,
        GraphNodeDraft(kind: 'editable.entry', title: 'Pending'),
      );
      await feature.createEntered.future;
      final switching = vm.switchSphere(second.id);
      final rejected = expectLater(
        actions.createChild(GraphNodeDraft(kind: 'goal', title: 'Wrong scope')),
        throwsStateError,
      );
      feature.createGate!.complete();
      await creating;
      await switching;
      await rejected;
      expect(await app.goalsRepository.getAllGoals(), isEmpty);
    },
  );

  testWidgets(
    'unloading and re-registering forms invalidates an edit already waiting in the queue',
    (tester) async {
      final feature = EditableGraphModule();
      final app = (await tester.runAsync(
        () => createTestApp(
          enableObsidian: false,
          graphModules: [feature.module],
        ),
      ))!;
      final sphere = Sphere.create(name: 'Root');
      late LifeGraphViewModel vm;
      late String id;
      late GraphNodeActionContext captured;
      await tester.runAsync(() async {
        await app.spheresRepository.addSphere(sphere);
        vm = await app.pulseScreenViewModel.openGraph(sphere.id);
        await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
        id = await vm.createChild(
          sphere.id,
          GraphNodeDraft(kind: 'editable.entry', title: 'Original'),
        );
        await vm.graphStream.firstWhere((nodes) => nodes.length == 2);
      });
      app.graphEditors.register(
        'forms',
        editors: [sampleEditor(capture: (actions) => captured = actions)],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => GraphNodeDialogs(
                  registry: app.graphEditors,
                  commands: app.graphCommands,
                ).edit(context, vm.actionsFor(id)),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        feature.createGate = Completer<void>();
        final pending = vm.createChild(
          sphere.id,
          GraphNodeDraft(kind: 'editable.entry', title: 'Pending'),
        );
        await Future<void>.delayed(Duration.zero);
        final rejected = expectLater(
          captured.updateNode(renamed(captured.node, 'Unsafe edit')),
          throwsStateError,
        );
        app.graphEditors.unregister('forms');
        app.graphEditors.register('forms', editors: [sampleEditor()]);
        feature.createGate!.complete();
        await pending;
        await rejected;
        await expectLater(
          captured.updateNode(renamed(captured.node, 'Still unsafe')),
          throwsStateError,
        );
      });
      await tester.pumpAndSettle();
      expect(feature.nodes[id]!.title, 'Original');
      expect(find.text('Действие больше недоступно'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      await disposeTestApp(tester, app);
      await feature.changes.close();
    },
  );

  testWidgets(
    'generic delete confirmation keeps a failed operation available for retry',
    (tester) async {
      var attempts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => GraphDeleteDialog(
                    title: 'Sample',
                    onDelete: (keep) async {
                      expect(keep, isFalse);
                      if (++attempts == 1) throw StateError('Failed');
                    },
                  ),
                ),
                child: const Text('Open delete'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить всё поддерево'));
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось удалить узел. Повторите попытку.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Удалить всё поддерево'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(find.byType(GraphDeleteDialog), findsNothing);
    },
  );
}
