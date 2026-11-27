import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:graph_canvas/graph_canvas.dart' as graph;
import 'package:graph_api/graph_api.dart';
import 'package:graph_components/graph_components.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart';
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;
import 'package:spheres_api/spheres_api.dart';
import '../../../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late ObsidianVault vault;
  late DependencyContainer app;
  late Sphere sphere;
  var cleaned = false;
  final models = <LifeGraphViewModel>[];
  setUp(() async {
    cleaned = false;
    directory = await Directory.systemTemp.createTemp('pulse_board_vm_');
    vault = ObsidianVault(watchDirectory: (_) => const Stream.empty());
    await vault.openVault(directory.path);
    app = await createTestApp(enableObsidian: false);
    sphere = Sphere.create(name: 'Original name');
    await app.spheresRepository.addSphere(sphere);
  });
  tearDown(() async {
    if (cleaned) return;
    for (final vm in models) {
      await vm.dispose();
    }
    models.clear();
    await app.dispose();
    await vault.dispose();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    if (!p.isWithin(root, await directory.resolveSymbolicLinks())) {
      throw StateError('Unexpected temp directory');
    }
    await directory.delete(recursive: true);
  });
  Future<LifeGraphViewModel> open({GraphPositionsStore? positions}) async {
    final vm = LifeGraphViewModel(
      spheresRepository: app.spheresRepository,
      positionsRepository: positions ?? app.graphPositionsRepository,
      notesRepository: app.graphNotesRepository,
      graphBuilder: app.graphBuilder,
      nodePresentations: app.graphPresentations,
      nodeEditors: app.graphEditors,
      commands: app.graphCommands,
      obsidianRepository: vault,
    );
    models.add(vm);
    await vm.switchSphere(sphere.id);
    await vm.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
    return vm;
  }

  Future<Map<String, dynamic>> read(LifeGraphViewModel vm) async =>
      jsonDecode(await File(vm.canvasBoardPath!).readAsString())
          as Map<String, dynamic>;

  Future<void> cleanTempDirectory() async {
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    if (!p.isWithin(root, await directory.resolveSymbolicLinks())) {
      throw StateError('Unexpected temp directory');
    }
    await directory.delete(recursive: true);
    models.clear();
    cleaned = true;
  }

  test(
    'deleting selected stickers saves the board and keeps original Markdown',
    () async {
      final vm = await open();
      final path = await vm.createMarkdownNote(
        title: 'Keep file',
        text: 'original body',
      );
      final linked = vm.notes.single.id;
      await vm.createNote();
      final sticker = vm.notes.last.id;
      await vm.deletionForSelection(nodeIds: {}, noteIds: {linked, sticker})(
        true,
      );
      await vm.flush();
      expect(vm.notes, isEmpty);
      expect(await File(path).readAsString(), 'original body');
      final document = await read(vm);
      expect(
        (document['nodes'] as List).any(
          (n) => n['id'] == linked || n['id'] == sticker,
        ),
        isFalse,
      );
      await vm.dispose();
      final reopened = await open();
      expect(reopened.notes, isEmpty);
      expect(await File(path).readAsString(), 'original body');
    },
  );

  test(
    'migration captures layout and notes, reopen imports negative coordinates and unknown content',
    () async {
      await app.graphPositionsRepository.savePositions(sphere.id, {
        sphere.id: const GraphPoint(100, 200),
      });
      await app.graphNotesRepository.saveNotes(sphere.id, [
        const CanvasNote(
          document: NoteDocument(id: 'legacy', text: 'legacy note'),
          x: 400,
          y: 300,
          width: 250,
          height: 180,
          index: 0,
        ),
      ]);
      final first = await open();
      await first.flush();
      final document = await read(first);
      expect(document['nodes'][0]['x'], 100);
      expect(document['nodes'][1]['text'], 'legacy note');
      await first.dispose();
      document['nodes'][0]['x'] = -500;
      document['nodes'][0]['width'] = 420;
      document['nodes'][0]['text'] = 'do not import into DB';
      document['nodes'][1]['text'] = 'Obsidian note';
      document['nodes'].add({
        'id': 'group',
        'type': 'group',
        'x': 0,
        'y': 0,
        'width': 300,
        'height': 250,
        'custom': true,
      });
      document['edges'].add({
        'id': 'user',
        'fromNode': 'group',
        'toNode': document['nodes'][0]['id'],
        'label': 'relation',
      });
      document['customRoot'] = 42;
      await File(first.canvasBoardPath!).writeAsString(jsonEncode(document));
      final second = await open();
      expect(second.graph.single.size.width, 420);
      expect(second.notes.single.text, 'Obsidian note');
      expect(second.notes.single.id, 'legacy');
      expect(second.nodeById(sphere.id)!.title, 'Original name');
      final exported = jsonDecode(
        await File(await second.exportCanvas()).readAsString(),
      );
      expect(exported['nodes'][0]['x'], -500);
      expect(exported['nodes'][0]['width'], 420);
      await second.flush();
      final saved = await read(second);
      expect(saved['customRoot'], 42);
      expect(saved['nodes'].last['custom'], isTrue);
      expect(saved['edges'].single['label'], 'relation');
      expect(await app.graphPositionsRepository.loadPositions(sphere.id), {
        sphere.id: const GraphPoint(100, 200),
      });
    },
  );

  test('reset restores standard node sizes at the same positions', () async {
    final vm = await open();
    final goal = await vm.createChild(
      sphere.id,
      GraphNodeDraft(kind: 'goal', title: 'Goal'),
    );
    await vm.graphStream.firstWhere((nodes) => nodes.any((n) => n.id == goal));
    await vm.createNoteWithText(title: '', text: 'Keep this sticker');
    await vm.flush();
    final before = await read(vm);
    (before['nodes'][0] as Map<String, dynamic>).addAll({
      'x': -460,
      'y': -170,
      'width': 280,
      'height': 280,
    });
    (before['nodes'][1] as Map<String, dynamic>).addAll({
      'width': 310,
      'height': 150,
    });
    await File(vm.canvasBoardPath!).writeAsString(jsonEncode(before));
    await vm.reloadCanvasBoard();
    expect(vm.hasCustomNodeSizes, isTrue);
    final positions = {for (final node in vm.graph) node.id: node.position};

    await vm.resetNodeSizes();
    expect(vm.hasCustomNodeSizes, isFalse);
    expect(vm.graph.map((node) => node.size), [
      const Size(140, 140),
      const Size(180, 100),
    ]);
    expect({for (final node in vm.graph) node.id: node.position}, positions);

    await vm.dispose();
    final reopened = await open();
    expect(reopened.hasCustomNodeSizes, isFalse);
    expect({
      for (final node in reopened.graph) node.id: node.position,
    }, positions);
    final after = await read(reopened);
    expect(after['nodes'], [
      {...before['nodes'][0] as Map, 'width': 140, 'height': 140},
      {...before['nodes'][1] as Map, 'width': 180, 'height': 100},
      before['nodes'][2],
    ]);
    expect(after['edges'], before['edges']);
  });

  test(
    'external edit conflicts produce recovery and reload continues from the external file',
    () async {
      final vm = await open();
      await vm.flush();
      final document = await read(vm);
      document['nodes'].add({
        'id': 'new-note',
        'type': 'text',
        'text': 'external',
        'x': 100,
        'y': 200,
        'width': 200,
        'height': 150,
      });
      final external = jsonEncode(document);
      await File(vm.canvasBoardPath!).writeAsString(external);
      await vm.createNote();
      await vm.updateNoteText(vm.notes.single.id, 'local recovery');
      await expectLater(vm.flush(), throwsA(isA<CanvasBoardConflict>()));
      expect(await File(vm.canvasBoardPath!).readAsString(), external);
      expect(vm.saveStatus.value, GraphSaveStatus.failed);
      await vm.reloadCanvasBoard();
      expect(vm.notes.single.text, 'external');
      expect(vm.saveStatus.value, GraphSaveStatus.saved);
      final copies = await Directory(
        p.join(directory.path, 'Pulse', 'Backups'),
      ).list().where((e) => e.path.contains('.conflict-')).toList();
      expect(copies, isNotEmpty);
      expect(
        await File(copies.first.path).readAsString(),
        contains('local recovery'),
      );
      vm.commitNoteMove(vm.notes.single.id, 500, 600);
      await vm.flush();
      expect((await read(vm))['nodes'][1]['x'], 500);
    },
  );

  test(
    'switch and close finish each board under its captured sphere',
    () async {
      final second = Sphere.create(name: 'Second');
      await app.spheresRepository.addSphere(second);
      final vm = await open();
      final firstPath = vm.canvasBoardPath!;
      await vm.createNote();
      await vm.updateNoteText(vm.notes.single.id, 'first sphere');
      await vm.switchSphere(second.id);
      await vm.graphStream.firstWhere(
        (nodes) => nodes.any((n) => n.id == second.id),
      );
      await vm.createNote();
      await vm.updateNoteText(vm.notes.single.id, 'second sphere');
      final secondPath = vm.canvasBoardPath!;
      await vm.dispose();
      expect(await File(firstPath).readAsString(), contains('first sphere'));
      expect(
        await File(firstPath).readAsString(),
        isNot(contains('second sphere')),
      );
      expect(await File(secondPath).readAsString(), contains('second sphere'));
    },
  );
  test('corrupt primary is never replaced with legacy state', () async {
    final session = await vault.openCanvasBoard(sphere.id);
    await session.write('broken canvas', expected: null);
    await expectLater(open(), throwsFormatException);
    expect(await session.read(), 'broken canvas');
  });

  test(
    'conversion keeps card identity, geometry and user links and edits the markdown file',
    () async {
      await vault.configureFolders(const VaultFolders(notes: 'My Notes'));
      final vm = await open();
      await vm.createNote();
      final id = vm.notes.single.id;
      await vm.updateNoteText(id, '# Body\n\nText');
      vm.commitNoteMove(id, 800, 900);
      vm.commitNoteResize(id, 300, 200);
      await vm.flush();
      final document = await read(vm);
      final oldCard = Map<String, dynamic>.of(
        document['nodes'][1] as Map<String, dynamic>,
      );
      document['edges'].add({
        'id': 'user',
        'fromNode': oldCard['id'],
        'toNode': document['nodes'][0]['id'],
      });
      await File(vm.canvasBoardPath!).writeAsString(jsonEncode(document));
      await vm.reloadCanvasBoard();
      final file = await vm.convertNoteToMarkdown(id, title: 'My note');
      expect(file, p.join(directory.path, 'My Notes', 'My note.md'));
      expect(await File(file).readAsString(), '# Body\n\nText');
      expect(vm.notes.single.id, id);
      final converted = (await read(vm))['nodes'][1];
      for (final field in ['id', 'x', 'y', 'width', 'height']) {
        expect(converted[field], oldCard[field]);
      }
      expect(converted['type'], 'file');
      expect(converted['file'], 'My Notes/My note.md');
      expect(converted.containsKey('text'), isFalse);
      expect((await read(vm))['edges'].single['fromNode'], oldCard['id']);
      await vm.updateNoteText(id, 'edited markdown');
      await vm.flush();
      expect(await File(file).readAsString(), 'edited markdown');
    },
  );
  test(
    'duplicate file names leave the sticker and existing markdown unchanged',
    () async {
      final vm = await open();
      final existing = await vault.createNote('Existing', 'keep');
      await vm.createNote();
      await vm.updateNoteText(vm.notes.single.id, 'sticker');
      await expectLater(
        vm.convertNoteToMarkdown(vm.notes.single.id, title: 'Existing'),
        throwsA(isA<MarkdownNoteNameConflict>()),
      );
      expect(vm.notes.single.source, isNull);
      expect(await File(existing.absolutePath).readAsString(), 'keep');
      final file = await vm.createMarkdownNote(
        title: 'Fresh',
        text: 'new text',
      );
      expect(vm.notes, hasLength(2));
      expect(vm.notes.last.source!.path, file);
      expect(await File(file).readAsString(), 'new text');
      await vm.dispose();
      await expectLater(
        vm.createMarkdownNote(title: 'Stale'),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'graph removes task placement and adds the stored task at a new position',
    (tester) async {
      Future<void> until(bool Function() done) async {
        for (var i = 0; i < 100 && !done(); i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 2)),
          );
        }
        expect(done(), isTrue);
      }

      Future<T> finish<T>(Future<T> operation) async {
        var done = false;
        final result = operation.whenComplete(() => done = true);
        await until(() => done);
        return result;
      }

      try {
        final vm = (await tester.runAsync(open))!;
        await tester.runAsync(() async {
          await tester.pumpWidget(
            MaterialApp(home: LifeGraphScreen(viewModel: vm)),
          );
          await vm.refreshNotes();
        });
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();

        Future<graph.GraphNode> create(
          Offset point,
          String menuLabel,
          String title,
        ) async {
          final viewer = find.byType(InteractiveViewer);
          final controller = tester
              .widget<InteractiveViewer>(viewer)
              .transformationController!;
          final expected = controller.toScene(
            point - tester.getTopLeft(viewer),
          );
          final mouse = await tester.startGesture(
            point,
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await mouse.up();
          await tester.pumpAndSettle();
          expect(find.text('Создать задачу'), findsOneWidget);
          expect(find.text('Создать проект'), findsOneWidget);
          await tester.tap(find.text(menuLabel));
          await tester.pumpAndSettle();
          await tester.enterText(
            find
                .descendant(
                  of: find.byType(GraphChildCreateDialog),
                  matching: find.byType(TextField),
                )
                .first,
            title,
          );
          await tester.tap(find.text('Создать'));
          await until(() => vm.graph.any((n) => n.label == title));
          final node = vm.graph.singleWhere((node) => node.label == title);
          expect(node.parentId, isNull);
          expect((node.position - expected).distance, lessThan(0.01));
          await tester.pumpAndSettle();
          return node;
        }

        final task = await create(
          const Offset(210, 410),
          'Создать задачу',
          'Standalone task',
        );
        final project = await create(
          const Offset(580, 120),
          'Создать проект',
          'Standalone project',
        );
        await finish(vm.flush());
        await tester.runAsync(() async {
          final storedTask = (await app.tasksRepository.getById(task.id))!;
          final storedProject = (await app.projectsRepository.getProjectById(
            project.id,
          ))!;
          expect(storedTask.projectId, isNull);
          expect(storedTask.parentTaskId, isNull);
          expect(storedProject.goalId, isNull);
          expect(storedProject.parentProejectId, isNull);
          final document = await read(vm);
          expect(document['edges'], isEmpty);
          expect(
            (document['nodes'] as List).map((node) => node['id']),
            unorderedEquals([
              'pulse:${sphere.id}',
              'pulse:${task.id}',
              'pulse:${project.id}',
            ]),
          );
        });
        await tester.tap(find.byTooltip('Fit graph'));
        await tester.pumpAndSettle();

        Future<TestGesture> drag(String sourceId, String targetTitle) async {
          final plus = find.byKey(ValueKey('graph-connect:$sourceId'));
          final mouse = await tester.startGesture(
            tester.getCenter(plus),
            kind: PointerDeviceKind.mouse,
          );
          await mouse.moveBy(const Offset(-40, 0));
          await tester.pump();
          await mouse.moveTo(tester.getCenter(find.text(targetTitle)));
          await tester.pump();
          final viewer = tester.widget<InteractiveViewer>(
            find.byType(InteractiveViewer),
          );
          expect(viewer.panEnabled, isFalse);
          return mouse;
        }

        final cancelled = await drag(project.id, task.label);
        await cancelled.cancel();
        await tester.pump();
        expect(vm.nodeById(task.id)!.parentId, isNull);
        expect(
          tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .panEnabled,
          isTrue,
        );

        final connecting = await drag(project.id, task.label);
        await connecting.up();
        await until(() => vm.nodeById(task.id)?.parentId == project.id);
        expect(
          vm.graph.singleWhere((node) => node.id == task.id).position,
          task.position,
        );
        expect(
          vm.graph.singleWhere((node) => node.id == project.id).position,
          project.position,
        );
        await finish(vm.flush());
        await tester.runAsync(() async {
          final storedTask = (await app.tasksRepository.getById(task.id))!;
          expect(storedTask.projectId, project.id);
          expect(storedTask.parentTaskId, isNull);
          final document = await read(vm);
          final edge = (document['edges'] as List).single as Map;
          expect(edge['fromNode'], 'pulse:${project.id}');
          expect(edge['toNode'], 'pulse:${task.id}');
          expect(edge['pulse'], {'kind': 'hierarchy'});
        });

        Future<String> anotherTask(String title, Offset delta) => finish(
          vm.standaloneCreationAt(task.position + delta)(
            GraphNodeDraft(kind: 'task', title: title),
            () => true,
          ),
        );
        final next = await anotherTask('Next task', const Offset(560, 0));
        final sub = await anotherTask('Child task', const Offset(560, 240));
        await until(() => vm.nodeById(sub) != null);
        await tester.tap(find.byTooltip('Fit graph'));
        await tester.pumpAndSettle();
        Future<void> choose(
          String targetTitle,
          String option, {
          String? sourceId,
        }) async {
          final gesture = await drag(sourceId ?? task.id, targetTitle);
          await gesture.up();
          await tester.pumpAndSettle();
          expect(find.text('Сделать подзадачей'), findsOneWidget);
          expect(find.text('Сделать следующей задачей'), findsOneWidget);
          await tester.tap(find.text(option));
          await tester.pumpAndSettle();
        }

        await choose('Next task', 'Отмена');
        expect(vm.nodeById(next)!.attributes['predecessorTaskId'], isNull);
        await choose('Next task', 'Сделать следующей задачей');
        await until(
          () => vm.nodeById(next)?.attributes['predecessorTaskId'] == task.id,
        );
        await choose('Child task', 'Сделать подзадачей');
        await until(() => vm.nodeById(sub)?.parentId == task.id);
        await choose('Next task', 'Сделать следующей задачей', sourceId: sub);
        await until(() => vm.sequencePredecessorsFor(next).length == 2);
        await finish(vm.flush());
        await tester.runAsync(() async {
          final edges = (await read(vm))['edges'] as List;
          expect(edges, hasLength(4));
          final sequence = edges.singleWhere(
            (e) =>
                e['toNode'] == 'pulse:$next' &&
                e['fromNode'] == 'pulse:${task.id}',
          );
          expect(sequence['fromNode'], 'pulse:${task.id}');
          expect(sequence['pulse'], {'kind': 'sequence'});
          final hierarchy = edges.singleWhere(
            (e) => e['toNode'] == 'pulse:$sub',
          );
          expect(hierarchy['fromNode'], 'pulse:${task.id}');
          expect(hierarchy['pulse'], {'kind': 'hierarchy'});
        });

        final subPosition = vm.graph
            .singleWhere((node) => node.id == sub)
            .position;
        Future<void> openChildMenu() async {
          final menu = await tester.startGesture(
            tester.getCenter(find.text('Child task')),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await menu.up();
          await tester.pumpAndSettle();
        }

        await openChildMenu();
        await tester.tap(find.text('Отсоединить…'));
        await tester.pumpAndSettle();
        expect(find.text('Какую связь убрать?'), findsOneWidget);
        await tester.tap(find.text('${task.label} → Child task'));
        await until(
          () => vm.nodeById(sub) != null && vm.nodeById(sub)!.parentId == null,
        );
        expect(
          vm.graph.singleWhere((node) => node.id == sub).position,
          subPosition,
        );
        expect(vm.sequencePredecessorsFor(next), [task.id, sub]);

        await tester.pumpAndSettle();
        await tester.tap(find.text(task.label));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Отсоединить узел'));
        await tester.pumpAndSettle();
        expect(find.text('Последовательность'), findsOneWidget);
        await tester.tap(find.text('${task.label} → Next task'));
        await until(() => vm.sequencePredecessorsFor(next).length == 1);
        expect(vm.sequencePredecessorsFor(next), [sub]);
        await tester.pumpAndSettle();
        await openChildMenu();
        expect(find.text('Убрать с графа'), findsNothing);
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        expect(find.text('Удалить задачу'), findsOneWidget);
        await tester.tap(find.text('Убрать с графа'));
        await until(() => vm.graph.every((node) => node.id != sub));
        await finish(vm.flush());
        await tester.runAsync(() async {
          final document = await read(vm);
          final edge = (document['edges'] as List).single as Map;
          expect(document['pulse']['removedTaskIds'], [sub]);
          expect(document['pulse']['hiddenTasks'], isNull);
          expect(
            (document['nodes'] as List).any(
              (node) => node['id'] == 'pulse:$sub',
            ),
            isFalse,
          );
          expect(edge['fromNode'], 'pulse:${project.id}');
          expect(edge['toNode'], 'pulse:${task.id}');
          expect(
            (await app.tasksRepository.getById(sub))!.parentTaskId,
            isNull,
          );
          expect(
            (await app.tasksRepository.getById(next))!.predecessorTaskIds,
            [sub],
          );
        });

        await tester.pumpWidget(const SizedBox());
        await finish(vm.dispose());
        final reopened = await finish(
          open(positions: GraphPositionsRepository(prefix: 'reopened_graph')),
        );
        expect(reopened.tasksRemovedFromBoard.map((task) => task.id), [sub]);
        expect(reopened.nodeById(sub), isNull);
        expect(
          reopened.graph.singleWhere((node) => node.id == next).predecessorIds,
          isEmpty,
        );
        await tester.pumpWidget(
          MaterialApp(home: LifeGraphScreen(viewModel: reopened)),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Скрытые задачи'), findsNothing);
        expect(find.byTooltip('Добавить задачу на доску'), findsNothing);
        final viewer = find.byType(InteractiveViewer);
        final placedAt = tester
            .widget<InteractiveViewer>(viewer)
            .transformationController!
            .toScene(const Offset(690, 525) - tester.getTopLeft(viewer));
        final contextMenu = await tester.startGesture(
          const Offset(690, 525),
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
        await contextMenu.up();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Добавить существующую задачу'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Child task'));
        await until(() => reopened.nodeById(sub) != null);
        await finish(reopened.flush());
        await tester.runAsync(() async {
          final document = await read(reopened);
          expect(document['pulse']['removedTaskIds'], isNull);
          expect((document['edges'] as List), hasLength(2));
        });
        expect(
          reopened.graph.map((node) => node.id),
          unorderedEquals([sphere.id, task.id, project.id, next, sub]),
        );
        expect(reopened.nodeById(next)!.parentId, isNull);
        expect(reopened.sequencePredecessorsFor(next), [sub]);
        expect(reopened.nodeById(sub)!.parentId, isNull);
        expect(reopened.nodeById(sub)!.attributes['predecessorTaskId'], isNull);
        expect(reopened.nodeById(task.id)!.parentId, project.id);
        expect(
          (reopened.graph.singleWhere((node) => node.id == sub).position -
                  placedAt)
              .distance,
          lessThan(1),
        );
        expect(
          (reopened.graph.singleWhere((node) => node.id == task.id).position -
                  task.position)
              .distance,
          lessThan(1),
        );
        await tester.tap(find.byTooltip('Fit graph'));
        await tester.pumpAndSettle();
        await openChildMenu();
        await tester.tap(find.text('Удалить'));
        await tester.pumpAndSettle();
        expect(find.text('Убрать с графа'), findsOneWidget);
        await tester.tap(find.text('Удалить задачу'));
        await until(() => reopened.nodeById(sub) == null);
        await until(
          () => find.text('Что сделать с задачей?').evaluate().isEmpty,
        );
        expect(await finish(app.tasksRepository.getById(sub)), isNull);
        expect(await finish(app.tasksRepository.getById(next)), isNotNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        for (final model in models) {
          await finish(model.dispose());
        }
        await disposeTestApp(tester, app);
        await finish(vault.dispose());
        await tester.runAsync(cleanTempDirectory);
      }
    },
  );

  testWidgets('board menu converts a sticker and creates a new markdown card', (
    tester,
  ) async {
    Future<void> until(
      bool Function() done, {
      String Function()? reason,
    }) async {
      for (var i = 0; i < 500 && !done(); i++) {
        await tester.pump(const Duration(milliseconds: 10));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
      }
      expect(done(), isTrue, reason: reason?.call());
    }

    final vm = (await tester.runAsync(() async {
      await Directory(p.join(directory.path, 'Chosen')).create();
      final vm = await open();
      await vm.createNote();
      await vm.updateNoteText(vm.notes.single.id, 'UI note');
      await vm.flush();
      return vm;
    }))!;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: LifeGraphScreen(
            viewModel: vm,
            pickDirectory: () async => p.join(directory.path, 'Chosen'),
          ),
        ),
      );
      await vm.refreshNotes();
    });
    await tester.pumpAndSettle();
    expect(find.text('Converted UI'), findsNothing);
    expect(find.byTooltip('Действия заметки'), findsNothing);
    expect(find.byTooltip('Перечитать Canvas'), findsNothing);
    final mouse = await tester.startGesture(
      tester.getTopLeft(find.byType(graph.DefaultNoteCard)) +
          const Offset(40, 36),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Удалить с доски'), findsOneWidget);
    expect(
      tester
          .widgetList<Material>(find.byType(Material))
          .any(
            (material) =>
                material.color == AppGraphThemes.dark.surface &&
                material.shape is RoundedRectangleBorder,
          ),
      isTrue,
    );
    await tester.tap(find.text('Преобразовать в .md'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('markdown-note-title')),
      'Converted UI',
    );
    final convert = find.widgetWithText(FilledButton, 'Преобразовать');
    await until(() => tester.widget<FilledButton>(convert).onPressed != null);
    await tester.tap(convert);
    await until(
      () =>
          vm.notes.single.source != null &&
          vm.saveStatus.value == GraphSaveStatus.saved,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(graph.DefaultNoteCard),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Converted UI',
        ),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Действия заметки'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    final bodyPosition =
        tester.getTopLeft(find.byType(graph.DefaultNoteCard)) +
        const Offset(45, 65);
    await tester.tapAt(bodyPosition);
    await tester.pump(const Duration(milliseconds: 80));
    await tester.tapAt(bodyPosition);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'UI note edited before rename',
    );
    await tester.tap(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Converted UI',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('note-title-editor')),
      'Renamed UI',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await until(
      () =>
          p.basename(vm.notes.single.source!.path) == 'Renamed UI.md' &&
          vm.saveStatus.value == GraphSaveStatus.saved,
      reason: () =>
          '${vm.notes.single.source!.path}; ${vm.saveStatus.value}; ${tester.widgetList<SnackBar>(find.byType(SnackBar)).map((s) => s.content)}',
    );
    await tester.pumpAndSettle();
    expect(vm.notes.single.text, 'UI note edited before rename');
    final fileMouse = await tester.startGesture(
      tester.getTopLeft(find.byType(graph.DefaultNoteCard)) +
          const Offset(40, 36),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await fileMouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Преобразовать в .md'), findsNothing);
    expect(find.text('Редактировать'), findsOneWidget);
    final originalSource = vm.notes.single.source!.path;
    await tester.tap(find.text('Сохранить копию .md в папку…'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('markdown-note-title')),
      'Exported UI',
    );
    await tester.pump();
    await tester.tap(find.text('Сохранить копию'));
    await until(
      () =>
          find.textContaining('Копия заметки сохранена:').evaluate().isNotEmpty,
    );
    expect(
      await tester.runAsync(
        () => File(
          p.join(directory.path, 'Chosen', 'Exported UI.md'),
        ).readAsString(),
      ),
      'UI note edited before rename',
    );
    expect(vm.notes.single.source!.path, originalSource);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    final noteId = vm.notes.single.id;
    final boardBeforeRemoval = (await tester.runAsync(() => read(vm)))!;
    final fileCard = (boardBeforeRemoval['nodes'] as List).singleWhere(
      (node) => node['pulse']?['noteId'] == noteId,
    );
    expect(fileCard['type'], 'file');
    final removeMouse = await tester.startGesture(
      tester.getTopLeft(find.byType(graph.DefaultNoteCard)) +
          const Offset(40, 36),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await removeMouse.up();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить с доски'));
    await until(
      () => vm.notes.isEmpty && vm.saveStatus.value == GraphSaveStatus.saved,
    );
    await tester.pumpAndSettle();
    expect(find.byType(graph.DefaultNoteCard), findsNothing);
    final savedBoard = (await tester.runAsync(() => read(vm)))!;
    expect(
      (savedBoard['nodes'] as List).map((node) => node['id']),
      isNot(contains(fileCard['id'])),
    );
    expect(
      await tester.runAsync(() => File(originalSource).readAsString()),
      'UI note edited before rename',
    );

    await tester.tap(find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать .md'));
    await tester.pumpAndSettle();
    final title = find.byKey(const ValueKey('markdown-note-title'));
    final body = find.byKey(const ValueKey('markdown-note-text'));
    final create = find.widgetWithText(FilledButton, 'Создать .md');
    await tester.enterText(body, 'body from dialog');
    await tester.enterText(title, 'Renamed UI.md');
    final conflict = find.text(const MarkdownNoteNameConflict().toString());
    await until(() => conflict.evaluate().isNotEmpty);
    expect(tester.widget<FilledButton>(create).onPressed, isNull);
    expect(tester.widget<TextField>(body).controller!.text, 'body from dialog');
    await tester.enterText(title, 'Created UI');
    await until(() => tester.widget<FilledButton>(create).onPressed != null);
    await tester.tap(create);
    await until(
      () =>
          vm.notes.length == 1 && vm.saveStatus.value == GraphSaveStatus.saved,
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(graph.DefaultNoteCard),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == 'Created UI',
        ),
      ),
      findsOneWidget,
    );
    expect(
      await tester.runAsync(
        () => File(vm.notes.last.source!.path).readAsString(),
      ),
      'body from dialog',
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Из Markdown-хранилища'));
    await tester.pumpAndSettle();
    expect(find.text('Markdown-хранилище'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Renamed UI'),
      ),
    );
    await until(
      () =>
          vm.notes.length == 2 && vm.saveStatus.value == GraphSaveStatus.saved,
    );
    expect(vm.notes.last.source!.path, originalSource);
    expect(vm.notes.last.text, 'UI note edited before rename');
    await tester.pumpWidget(const SizedBox.shrink());
    var closed = false;
    final closing = vm.dispose().then((_) => closed = true);
    await until(() => closed);
    await closing;
    await disposeTestApp(tester, app);
    var stopped = false;
    final stopping = vault.dispose().then((_) => stopped = true);
    await until(() => stopped);
    await stopping;
    await tester.runAsync(cleanTempDirectory);
  });
}
