import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:graph_canvas/graph_canvas.dart' as graph;
import 'package:graph_api/graph_api.dart';
import 'package:life_os/app/dependency_container.dart';
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
  Future<LifeGraphViewModel> open() async {
    final vm = LifeGraphViewModel(
      spheresRepository: app.spheresRepository,
      positionsRepository: app.graphPositionsRepository,
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
        throwsA(isA<FileSystemException>()),
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
    await tester.tap(find.text('Преобразовать'));
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
    await tester.tap(find.byTooltip('Add note'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать .md'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('markdown-note-title')),
      'Created UI',
    );
    await tester.enterText(
      find.byKey(const ValueKey('markdown-note-text')),
      'body from dialog',
    );
    await tester.pump();
    await tester.tap(find.text('Создать .md'));
    await until(
      () =>
          vm.notes.length == 2 && vm.saveStatus.value == GraphSaveStatus.saved,
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
          vm.notes.length == 3 && vm.saveStatus.value == GraphSaveStatus.saved,
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
    await tester.runAsync(() async {
      final root = await Directory.systemTemp.resolveSymbolicLinks();
      if (!p.isWithin(root, await directory.resolveSymbolicLinks())) {
        throw StateError('Invalid temp path');
      }
      await directory.delete(recursive: true);
    });
    models.clear();
    cleaned = true;
  });
}
