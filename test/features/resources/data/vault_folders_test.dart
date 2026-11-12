import 'dart:io';
import 'package:test/test.dart';
import 'package:path/path.dart' as p;
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';

void main() {
  late Directory directory;
  late ObsidianVault vault;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pulse_folders_');
    vault = ObsidianVault(watchDirectory: (_) => const Stream.empty());
    await vault.openVault(directory.path);
  });
  tearDown(() async {
    await vault.dispose();
    if (!p.isWithin(
      await Directory.systemTemp.resolveSymbolicLinks(),
      await directory.resolveSymbolicLinks(),
    )) {
      throw StateError('Invalid temp directory');
    }
    await directory.delete(recursive: true);
  });
  test(
    'changing folders copies boards and keeps live sessions and originals intact',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await board.write('original', expected: null);
      final originalPath = board.path;
      await vault.configureFolders(
        const VaultFolders(
          boards: 'My Boards',
          notes: 'My Notes',
          exports: 'Exports',
          backups: 'Recovery',
        ),
      );
      expect(board.path, p.join(directory.path, 'My Boards', 'sphere.canvas'));
      expect(await board.read(), 'original');
      await board.write('new', expected: 'original');
      expect(await File(originalPath).readAsString(), 'original');
      expect(await board.read(), 'new');
      final note = await vault.createNote('Title.md', 'markdown');
      expect(note.absolutePath, p.join(directory.path, 'My Notes', 'Title.md'));
      final exported = await vault.createCanvas('sphere', {
        'nodes': [],
        'edges': [],
      });
      expect(p.dirname(exported), p.join(directory.path, 'Exports'));
      await File(board.path).writeAsString('external');
      try {
        await board.write('local', expected: 'new');
        fail('Expected conflict');
      } on CanvasBoardConflict catch (e) {
        expect(p.dirname(e.recoveryPath), p.join(directory.path, 'Recovery'));
      }
    },
  );
  test(
    'destination collision rejects change without replacing either board',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await board.write('original', expected: null);
      final other = File(p.join(directory.path, 'Other', 'sphere.canvas'));
      await other.parent.create();
      await other.writeAsString('different');
      await expectLater(
        vault.configureFolders(const VaultFolders(boards: 'Other')),
        throwsA(isA<FileSystemException>()),
      );
      expect(vault.folders.boards, 'Pulse/Boards');
      expect(await board.read(), 'original');
      expect(await other.readAsString(), 'different');
    },
  );
  test(
    'root and portable paths work while absolute paths and traversal are rejected',
    () async {
      for (final path in [
        '../outside',
        r'C:\Outside',
        '/outside',
        r'Folder\..\outside',
      ]) {
        expect(
          () => vault.configureFolders(VaultFolders(notes: path)),
          throwsArgumentError,
        );
      }
      await vault.configureFolders(
        const VaultFolders(notes: '', boards: r'Life\Boards'),
      );
      expect(vault.folders.boards, 'Life/Boards');
      expect(
        File((await vault.createNote('root', 'text')).absolutePath).parent.path,
        directory.path,
      );
    },
  );
  test(
    'folder browser lists directories relative to vault and skips hidden paths',
    () async {
      await Directory(
        p.join(directory.path, 'Visible', 'Child'),
      ).create(recursive: true);
      await Directory(p.join(directory.path, '.obsidian')).create();
      await File(p.join(directory.path, 'file.md')).writeAsString('text');
      expect(await vault.listFolders(), ['', 'Visible', 'Visible/Child']);
    },
  );
  test(
    'queued writes finish before boards are copied to a different folder',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await board.write('old', expected: null);
      final write = board.write('accepted', expected: 'old');
      final configure = vault.configureFolders(
        const VaultFolders(boards: 'Next'),
      );
      await Future.wait([write, configure]);
      expect(await board.read(), 'accepted');
    },
  );
  test(
    'a note accepted before a vault switch is never created in the new vault',
    () async {
      final writing = vault.createNote('stale', 'text');
      final checked = expectLater(writing, throwsStateError);
      final switching = vault.openVault(directory.path);
      await checked;
      await switching;
      expect(
        await File(
          p.join(directory.path, 'Pulse', 'Notes', 'stale.md'),
        ).exists(),
        isFalse,
      );
    },
  );
  test(
    'loading saved folder options does not recopy an old archived board',
    () async {
      final board = await vault.openCanvasBoard('sphere');
      await board.write('old archived version', expected: null);
      final archived = board.path;
      final active = File(p.join(directory.path, 'Saved', 'sphere.canvas'));
      await active.parent.create();
      await active.writeAsString('current version');
      await vault.configureFolders(
        const VaultFolders(boards: 'Saved'),
        copyBoards: false,
      );
      expect(await board.read(), 'current version');
      expect(await File(archived).readAsString(), 'old archived version');
    },
  );
}
