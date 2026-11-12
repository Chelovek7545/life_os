import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';

void main() {
  late Directory directory;
  late ObsidianVault vault;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pulse_board_');
    vault = ObsidianVault(watchDirectory: (_) => const Stream.empty());
    await vault.openVault(directory.path);
  });
  tearDown(() async {
    await vault.dispose();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    if (!p.isWithin(root, await directory.resolveSymbolicLinks())) {
      throw StateError('Invalid temp path');
    }
    await directory.delete(recursive: true);
  });
  test(
    'canonical board is stable and preserves its first migration snapshot',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      expect(await board.read(), isNull);
      await board.write('first', expected: null);
      await board.write('second', expected: 'first');
      expect(await board.read(), 'second');
      final reopened = await vault.openCanvasBoard('sphere');
      expect(reopened.path, board.path);
      final backups = await Directory(
        p.join(directory.path, 'Pulse', 'Backups'),
      ).list().where((e) => e.path.contains('.migration-')).toList();
      expect(backups, hasLength(1));
      expect(await File(backups.single.path).readAsString(), 'first');
    },
  );
  test(
    'stale writers preserve the external file and produce a recovery copy',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await board.write('original', expected: null);
      await File(board.path).writeAsString('Obsidian edits');
      CanvasBoardConflict? conflict;
      try {
        await board.write('Pulse edits', expected: 'original');
      } on CanvasBoardConflict catch (e) {
        conflict = e;
      }
      expect(conflict, isNotNull);
      expect(await File(conflict!.recoveryPath).readAsString(), 'Pulse edits');
      expect(await board.read(), 'Obsidian edits');
    },
  );
  test(
    'deleted external file is a conflict, not an invitation to recreate it',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await board.write('old', expected: null);
      await File(board.path).delete();
      await expectLater(
        board.write('new', expected: 'old'),
        throwsA(isA<CanvasBoardConflict>()),
      );
      expect(await board.read(), isNull);
    },
  );
  test(
    'session stays bound to the original vault and rejects restart callbacks',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await vault.openVault(directory.path);
      await expectLater(board.write('new', expected: null), throwsStateError);
      expect(() => board.resolveNote('../outside.md'), throwsStateError);
    },
  );
  test('portable note paths cannot escape the vault', () async {
    final board = await vault.openCanvasBoard('sphere');
    expect(
      board.notePath(p.join(directory.path, 'Notes', 'one.md')),
      'Notes/one.md',
    );
    expect(
      board.resolveNote('Notes/one.md'),
      p.join(directory.path, 'Notes', 'one.md'),
    );
    expect(() => board.resolveNote('../outside.md'), throwsArgumentError);
  });
  test('two sessions cannot silently overwrite each other', () async {
    final first = await vault.openCanvasBoard('sphere');
    await first.write('original', expected: null);
    final second = await vault.openCanvasBoard('sphere');
    final revision = await second.read();
    await first.write('first edit', expected: 'original');
    await expectLater(
      second.write('second edit', expected: revision),
      throwsA(isA<CanvasBoardConflict>()),
    );
    expect(await second.read(), 'first edit');
  });
  test('accepted board write completes before stop', () async {
    final board = await vault.openCanvasBoard('sphere');
    final write = board.write('accepted', expected: null);
    await vault.stop();
    await write;
    expect(await File(board.path).readAsString(), 'accepted');
    expect(() => board.write('late', expected: 'accepted'), throwsStateError);
  });
}
