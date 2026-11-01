import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart' show GraphNodeType;
import 'package:lifegraph_plugin/lifegraph_plugin.dart' show LifeGraphViewModel;
import '../../../support/test_app.dart';
import '../support/editable_graph_module.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Built-in graph commands', () {
    late DependencyContainer app;
    late LifeGraphViewModel vm;
    late Sphere sphere;
    setUp(() async {
      app = await createTestApp(enableObsidian: false);
      sphere = Sphere.create(name: 'Root');
      await app.spheresRepository.addSphere(sphere);
      vm = await app.pulseScreenViewModel.openGraph(sphere.id);
      await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
    });
    tearDown(() => app.dispose());

    Future<String> create(
      String parent,
      String kind, {
      Map<String, Object?> attributes = const {},
    }) async {
      final id = await vm.createChild(
        parent,
        GraphNodeDraft(kind: kind, title: kind, attributes: attributes),
      );
      await vm.graphStream.firstWhere(
        (nodes) => nodes.any((node) => node.id == id),
      );
      return id;
    }

    test(
      'creates each built-in kind, keeps schedule values and routes subtree deletion',
      () async {
        final due = DateTime(2030, 1, 2);
        final start = DateTime(2030, 1, 2, 10);
        final end = DateTime(2030, 1, 2, 11);
        final goal = await create(sphere.id, 'goal');
        final project = await create(goal, 'project');
        final nested = await create(project, 'project');
        final task = await create(
          nested,
          'task',
          attributes: {'dueDate': due, 'startsAt': start, 'endsAt': end},
        );
        final subtask = await create(task, 'subTask');
        final nestedProject = (await app.projectsRepository.getProjectById(
          nested,
        ))!;
        expect(nestedProject.parentProejectId, project);
        expect(nestedProject.goalId, isNull);
        final saved = (await app.tasksRepository.getById(task))!;
        expect(saved.projectId, nested);
        expect(saved.dueDate, due);
        expect(saved.startsAt, start);
        expect(saved.endsAt, end);
        expect(
          (await app.tasksRepository.getById(subtask))!.parentTaskId,
          task,
        );
        await vm.flush();
        expect(
          (await app.graphPositionsRepository.loadPositions(sphere.id))!.keys,
          containsAll([goal, project, nested, task, subtask]),
        );
        await vm.deleteNode(nested, keepChildren: false);
        expect(await app.projectsRepository.getProjectById(nested), isNull);
        expect(await app.tasksRepository.getById(task), isNull);
        expect(await app.tasksRepository.getById(subtask), isNull);
        expect(await app.projectsRepository.getProjectById(project), isNotNull);
        expect(
          (await app.graphPositionsRepository.loadPositions(sphere.id))!.keys,
          isNot(contains(nested)),
        );
      },
    );

    test(
      'rejects invalid creation parents and cyclic task attachment without changing data',
      () async {
        await expectLater(
          vm.createChild(
            sphere.id,
            GraphNodeDraft(kind: 'task', title: 'Invalid'),
          ),
          throwsUnsupportedError,
        );
        expect(await app.tasksRepository.getAllTasks(), isEmpty);
        final goal = await create(sphere.id, 'goal');
        final project = await create(goal, 'project');
        final parent = await create(project, 'task');
        final child = await create(parent, 'subTask');
        await expectLater(
          vm.attachNode(parentId: child, kind: 'subTask', id: parent),
          throwsStateError,
        );
        expect(
          (await app.tasksRepository.getById(parent))!.parentTaskId,
          isNull,
        );
        expect(
          (await app.tasksRepository.getById(child))!.parentTaskId,
          parent,
        );
        final detached = Task.blank().copyWith(
          title: 'Keep fields',
          dueDate: Wrapped(DateTime(2031, 1, 2)),
        );
        await app.tasksRepository.addTask(detached);
        await vm.attachNode(parentId: project, kind: 'task', id: detached.id);
        final saved = (await app.tasksRepository.getById(detached.id))!;
        expect(saved.projectId, project);
        expect(saved.title, detached.title);
        expect(saved.dueDate, detached.dueDate);
      },
    );

    test(
      'keepChildren detaches descendants and deleting the root opens the next sphere',
      () async {
        final other = Sphere.create(name: 'Next');
        await app.spheresRepository.addSphere(other);
        final goal = await create(sphere.id, 'goal');
        final project = await create(goal, 'project');
        final task = await create(project, 'task');
        await vm.deleteNode(project, keepChildren: true);
        expect((await app.tasksRepository.getById(task))!.projectId, isNull);
        await vm.createNoteWithText(title: '', text: 'Root note');
        await vm.deleteNode(sphere.id, keepChildren: false);
        expect(await app.goalsRepository.getGoal(goal), isNull);
        expect(await app.tasksRepository.getById(task), isNotNull);
        expect(await app.graphNotesRepository.loadNotes(sphere.id), isNull);
        expect(
          await app.graphPositionsRepository.loadPositions(sphere.id),
          isNull,
        );
        expect(vm.currentSphereId, other.id);
        await vm.graphStream.firstWhere(
          (nodes) => nodes.any((node) => node.id == other.id),
        );
      },
    );
  });

  test(
    'switching graphs waits for accepted writes and stores coordinates in the original scope',
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
      final creating = vm.createChild(
        first.id,
        GraphNodeDraft(kind: 'editable.entry', title: 'Pending'),
      );
      await feature.createEntered.future;
      var switched = false;
      final switching = vm.switchSphere(second.id).then((_) => switched = true);
      await Future<void>.delayed(Duration.zero);
      expect(switched, isFalse);
      feature.createGate!.complete();
      final id = await creating;
      await switching;
      expect(
        (await app.graphPositionsRepository.loadPositions(
          first.id,
        ))!.containsKey(id),
        isTrue,
      );
      expect(
        (await app.graphPositionsRepository.loadPositions(
              second.id,
            ))?.containsKey(id) ??
            false,
        isFalse,
      );
      expect(vm.currentSphereId, second.id);
    },
  );

  test(
    'closing the graph drains accepted commands and flushes their final coordinates',
    () async {
      final feature = EditableGraphModule()..createGate = Completer<void>();
      final app = await createTestApp(
        enableObsidian: false,
        graphModules: [feature.module],
      );
      addTearDown(feature.changes.close);
      addTearDown(app.dispose);
      final sphere = Sphere.create(name: 'Root');
      await app.spheresRepository.addSphere(sphere);
      final vm = await app.pulseScreenViewModel.openGraph(sphere.id);
      await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
      final creating = vm.createChild(
        sphere.id,
        GraphNodeDraft(kind: 'editable.entry', title: 'Pending'),
      );
      await feature.createEntered.future;
      var closed = false;
      final closing = vm.dispose().then((_) => closed = true);
      await expectLater(
        vm.createChild(
          sphere.id,
          GraphNodeDraft(kind: 'editable.entry', title: 'Too late'),
        ),
        throwsStateError,
      );
      expect(closed, isFalse);
      feature.createGate!.complete();
      final id = await creating;
      await closing;
      expect(feature.listeners, 0);
      expect(
        (await app.graphPositionsRepository.loadPositions(
          sphere.id,
        ))!.containsKey(id),
        isTrue,
      );
    },
  );

  testWidgets(
    'plugin card edits and deletes its own kind through the common commands',
    (tester) async {
      Future<void> settleUntil(bool Function() ready) async {
        for (var i = 0; i < 100 && !ready(); i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(ready(), isTrue);
        await tester.pump();
      }

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
      await tester.runAsync(() async {
        await app.spheresRepository.addSphere(sphere);
        vm = await app.pulseScreenViewModel.openGraph(sphere.id);
        await vm.graphStream.firstWhere((nodes) => nodes.length == 1);
        id = await vm.createChild(
          sphere.id,
          GraphNodeDraft(kind: 'editable.entry', title: 'Created by plugin'),
        );
        await vm.graphStream.firstWhere((nodes) => nodes.length == 2);
      });
      expect(vm.nodeById(id)!.type, GraphNodeType.external);
      await tester.pumpWidget(
        MaterialApp(home: LifeGraphScreen(viewModel: vm)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.text('Created by plugin'), findsOneWidget);
      await tester.tap(find.text('Edit plugin entry'));
      await settleUntil(() => vm.nodeById(id)?.title == 'Edited by plugin');
      expect(find.text('Edited by plugin'), findsOneWidget);
      await tester.tap(find.text('Delete plugin entry'));
      await settleUntil(() => vm.nodeById(id) == null);
      expect(find.text('Edited by plugin'), findsNothing);
      await tester.runAsync(() async {
        await vm.flush();
        expect(
          (await app.graphPositionsRepository.loadPositions(
            sphere.id,
          ))!.containsKey(id),
          isFalse,
        );
      });
      await disposeTestApp(tester, app);
      await feature.changes.close();
    },
  );
}
