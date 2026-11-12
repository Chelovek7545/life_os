import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/lifegraph/data/graph_storage_repository.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';
import 'package:lifegraph_plugin/canvas_board.dart';
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temporary;
  late ObsidianVault vault;
  late GraphStorageRepository storage;
  late ValueNotifier<GraphStorageTarget> target;
  late ValueNotifier<VaultFolders> folders;
  var closes = 0;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pulse_root_');
    final directory = Directory(p.join(temporary.path, 'Vault'));
    await directory.create();
    vault = ObsidianVault(watchDirectory: (_) => const Stream.empty());
    await vault.openVault(directory.path);
    target = ValueNotifier(const GraphStorageTarget());
    folders = ValueNotifier(const VaultFolders());
    closes = 0;
    storage = GraphStorageRepository(
      target: target,
      vaultFolders: folders,
      obsidian: vault,
      beforeSwitch: () async {
        closes++;
      },
    );
    await storage.start();
  });
  tearDown(() async {
    await storage.dispose();
    await vault.dispose();
    target.dispose();
    folders.dispose();
    if (!p.isWithin(
      await Directory.systemTemp.resolveSymbolicLinks(),
      await temporary.resolveSymbolicLinks(),
    )) {
      throw StateError('Unexpected test directory');
    }
    await temporary.delete(recursive: true);
  });
  GraphStorageTarget local() => GraphStorageTarget(
    mode: GraphStorageMode.local,
    localPath: p.join(temporary.path, 'Pulse'),
  );

  test(
    'one local root controls boards, markdown, backups and exports',
    () async {
      await storage.selectTarget(local());
      final root = local().localPath;
      final note = await storage.createNote('Local', 'body');
      expect(note.absolutePath, p.join(root, 'Notes', 'Local.md'));
      final board = await storage.openCanvasBoard('sphere');
      await board.write('{"nodes":[],"edges":[]}', expected: null);
      expect(board.path, p.join(root, 'Boards', 'sphere.canvas'));
      expect(await Directory(p.join(root, 'Backups')).exists(), isTrue);
      expect(
        p.dirname(await storage.createCanvas('sphere', {'nodes': []})),
        p.join(root, 'Exports'),
      );
      expect(closes, 1);
    },
  );
  test(
    'switching saves the board and keeps existing markdown in its original vault',
    () async {
      final note = await vault.createNote('Referenced', 'keep me');
      final relative = vault.canvasNotePath(note.absolutePath);
      final board = await vault.openCanvasBoard('sphere');
      final document = jsonEncode({
        'nodes': [
          {
            'id': 'file',
            'type': 'file',
            'file': relative,
            'x': 10,
            'y': 20,
            'width': 250,
            'height': 180,
          },
        ],
        'edges': [],
      });
      await board.write(document, expected: null);
      final oldPath = board.path;
      await storage.selectTarget(local());
      final saved = await storage.openCanvasBoard('sphere');
      final parsed = CanvasBoardDocument((await saved.read())!);
      final linked = parsed.notes(saved.resolveNote).single;
      expect(linked.document.source!.path, note.absolutePath);
      expect(linked.text, 'keep me');
      expect(linked.x, 10);
      expect(
        await File(
          p.join(local().localPath, 'Notes', 'Referenced.md'),
        ).exists(),
        isFalse,
      );
      expect(await storage.readContent(note.absolutePath), 'keep me');
      expect(await File(oldPath).readAsString(), document);
      expect(await File(note.absolutePath).readAsString(), 'keep me');
    },
  );
  test(
    'Obsidian and local notes stay visible and receive source updates',
    () async {
      final original = await vault.createNote('Existing', 'vault body');
      await storage.selectTarget(local());
      final added = await storage.createNote('New', 'local body');
      expect(
        storage.obsidianState!.notes.single.absolutePath,
        original.absolutePath,
      );
      expect(
        storage.graphMarkdownState.notes.single.absolutePath,
        added.absolutePath,
      );
      expect(
        storage.state.notes.map((note) => note.absolutePath),
        unorderedEquals([original.absolutePath, added.absolutePath]),
      );
      final update = storage.watch().firstWhere(
        (state) => state.notes.any(
          (note) =>
              note.absolutePath == original.absolutePath &&
              note.content == 'changed outside',
        ),
      );
      await vault.writeContent(original.absolutePath, 'changed outside');
      await update;
      await storage.writeContent(original.absolutePath, 'edit original');
      expect(vault.state.notes.single.content, 'edit original');
      expect(await File(original.absolutePath).readAsString(), 'edit original');
      await storage.refresh();
      expect(storage.state.notes, hasLength(2));
      expect(
        await Directory(p.join(local().localPath, 'Pulse')).exists(),
        isFalse,
      );
    },
  );
  test('overlapping roots show the same file once', () async {
    final note = await vault.createNote('Existing', 'body');
    await storage.selectTarget(
      GraphStorageTarget(
        mode: GraphStorageMode.local,
        localPath: vault.state.vaultPath,
      ),
    );
    expect(storage.state.notes.map((value) => value.absolutePath), [
      note.absolutePath,
    ]);
  });
  test(
    'the graph Markdown panel follows its notes folder without moving existing files',
    () async {
      final old = await storage.createNote('Old folder', 'keep');
      final update = storage.watch().firstWhere(
        (_) =>
            storage.graphMarkdownState.vaultPath ==
            p.join(vault.state.vaultPath, 'New Notes'),
      );
      await storage.configureFolders(const VaultFolders(notes: 'New Notes'));
      await update;
      expect(storage.graphMarkdownState.notes, isEmpty);
      final next = await storage.createNote('New folder', 'new');
      expect(
        storage.graphMarkdownState.notes.single.absolutePath,
        next.absolutePath,
      );
      expect(
        storage.obsidianState!.notes.map((note) => note.absolutePath),
        unorderedEquals([old.absolutePath, next.absolutePath]),
      );
      expect(await File(old.absolutePath).readAsString(), 'keep');
    },
  );
  test(
    'a destination collision keeps the active source and both versions',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await board.write('{"nodes":[],"edges":[]}', expected: null);
      final destination = File(
        p.join(local().localPath, 'Boards', 'sphere.canvas'),
      );
      await destination.parent.create(recursive: true);
      await destination.writeAsString('other version');
      await expectLater(
        storage.selectTarget(local()),
        throwsA(isA<FileSystemException>()),
      );
      expect(storage.state.vaultPath, vault.state.vaultPath);
      expect(await destination.readAsString(), 'other version');
      expect(await board.read(), '{"nodes":[],"edges":[]}');
    },
  );
  test(
    'copies work without any configured root and finish before storage stops',
    () async {
      final independent = GraphStorageRepository(
        target: target,
        vaultFolders: folders,
        beforeSwitch: () async {},
      );
      await independent.start();
      try {
        await expectLater(
          independent.configureFolders(
            const VaultFolders(boards: '../outside'),
          ),
          throwsArgumentError,
        );
        final saving = independent.saveMarkdownCopy(
          temporary.path,
          'Standalone',
          'copy only',
        );
        await independent.stop();
        expect(await File(await saving).readAsString(), 'copy only');
        expect(
          () => independent.saveMarkdownCopy(temporary.path, 'Stale', 'text'),
          throwsStateError,
        );
      } finally {
        await independent.dispose();
      }
    },
  );
  test('invalid roots are rejected before closing open graphs', () async {
    await expectLater(
      storage.selectTarget(
        const GraphStorageTarget(
          mode: GraphStorageMode.local,
          localPath: 'relative',
        ),
      ),
      throwsArgumentError,
    );
    expect(closes, 0);
    expect(storage.state.vaultPath, vault.state.vaultPath);
  });
  test(
    'sessions from the previous root cannot mutate archived boards after switching',
    () async {
      final old = await storage.openCanvasBoard('sphere');
      const original = '{"nodes":[],"edges":[]}';
      await old.write(original, expected: null);
      final path = old.path;
      await storage.selectTarget(local());
      await expectLater(
        old.write('stale', expected: original),
        throwsStateError,
      );
      expect(await File(path).readAsString(), original);
      expect(await (await storage.openCanvasBoard('sphere')).read(), original);
    },
  );
  test(
    'custom copies can be written outside the active root and cannot overwrite files',
    () async {
      final outside = Directory(p.join(temporary.path, 'Outside'));
      await outside.create();
      final path = await storage.saveMarkdownCopy(
        outside.path,
        'Copy.md',
        '# Unicode Привет',
      );
      expect(path, p.join(outside.path, 'Copy.md'));
      expect(await File(path).readAsString(), '# Unicode Привет');
      await expectLater(
        storage.saveMarkdownCopy(outside.path, 'Copy', 'replace'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(path).readAsString(), '# Unicode Привет');
    },
  );
}
