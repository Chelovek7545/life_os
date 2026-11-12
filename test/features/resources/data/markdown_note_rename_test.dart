import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late ObsidianVault vault;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pulse_rename_');
    vault = ObsidianVault(watchDirectory: (_) => const Stream.empty());
    await vault.openVault(directory.path);
  });
  tearDown(() async {
    await vault.dispose();
    if (!p.isWithin(
      await Directory.systemTemp.resolveSymbolicLinks(),
      await directory.resolveSymbolicLinks(),
    )) {
      throw StateError('Invalid test path');
    }
    await directory.delete(recursive: true);
  });
  test(
    'rename updates canonical boards, aliases and stale session writes while preserving IDs and edges',
    () async {
      final note = await vault.createNote('Original', 'Unicode Привет');
      final board = await vault.openCanvasBoard('sphere');
      final raw = jsonEncode({
        'nodes': [
          {
            'id': 'same-id',
            'type': 'file',
            'file': vault.canvasNotePath(note.absolutePath),
            'x': 1,
            'y': 2,
            'width': 250,
            'height': 180,
            'custom': 42,
          },
          {
            'id': 'external',
            'type': 'text',
            'text': 'Unicode Привет',
            'pulse': {'externalPath': note.absolutePath},
          },
        ],
        'edges': [
          {'id': 'edge', 'fromNode': 'same-id', 'toNode': 'external'},
        ],
        'custom': true,
      });
      await board.write(raw, expected: null);
      final next = await vault.renameMarkdownNote(
        note.absolutePath,
        'Новое.md',
      );
      expect(p.basename(next), 'Новое.md');
      expect(await File(note.absolutePath).exists(), isFalse);
      expect(await File(next).readAsString(), 'Unicode Привет');
      final renamed = jsonDecode((await board.read())!);
      expect(renamed['nodes'][0]['file'], 'Pulse/Notes/Новое.md');
      expect(renamed['nodes'][0]['custom'], 42);
      expect(renamed['nodes'][1]['pulse']['externalPath'], next);
      expect(renamed['edges'].single['id'], 'edge');
      expect(renamed['custom'], isTrue);
      expect(vault.state.notes.single.title, 'Новое');
      expect(await vault.readContent(note.absolutePath), 'Unicode Привет');
      await board.write(raw, expected: raw);
      expect(
        jsonDecode((await board.read())!)['nodes'][0]['file'],
        'Pulse/Notes/Новое.md',
      );
      await File(
        board.path,
      ).writeAsString('{"nodes":[],"edges":[],"externalEdit":true}');
      await expectLater(
        board.write(raw, expected: raw),
        throwsA(isA<CanvasBoardConflict>()),
      );
    },
  );
  test('name collisions and path input never replace notes', () async {
    final source = await vault.createNote('Original', 'source');
    final occupied = await vault.createNote('Occupied', 'keep');
    await expectLater(
      vault.renameMarkdownNote(source.absolutePath, 'Occupied'),
      throwsA(isA<FileSystemException>()),
    );
    for (final title in ['', '../outside', 'folder/name', 'bad:name', '.md']) {
      await expectLater(
        vault.renameMarkdownNote(source.absolutePath, title),
        throwsArgumentError,
      );
    }
    expect(await File(source.absolutePath).readAsString(), 'source');
    expect(await File(occupied.absolutePath).readAsString(), 'keep');
  });
  test(
    'concurrent source changes preserve the original and recovery copy',
    () async {
      final source = await vault.createNote('Original', 'first');
      await expectLater(
        vault.renameMarkdownNote(
          source.absolutePath,
          'Renamed',
          updateReferences: (_, _) =>
              File(source.absolutePath).writeAsString('external edit'),
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(source.absolutePath).readAsString(), 'external edit');
      expect(
        await File(
          p.join(p.dirname(source.absolutePath), 'Renamed.md'),
        ).readAsString(),
        'first',
      );
    },
  );
  test(
    'accepted renames and writes to the old path finish before stop',
    () async {
      final source = await vault.createNote('Original', 'first');
      final entered = Completer<void>();
      final gate = Completer<void>();
      final renaming = vault.renameMarkdownNote(
        source.absolutePath,
        'Renamed',
        updateReferences: (_, _) async {
          entered.complete();
          await gate.future;
        },
      );
      await entered.future;
      final writing = vault.writeContent(source.absolutePath, 'queued edit');
      final closing = vault.stop();
      gate.complete();
      final next = await renaming;
      await writing;
      await closing;
      expect(await File(next).readAsString(), 'queued edit');
      expect(await File(source.absolutePath).exists(), isFalse);
      expect(() => vault.renameMarkdownNote(next, 'stale'), throwsStateError);
    },
  );
}
