import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;

class TestVaultSettings implements VaultSettings {
  TestVaultSettings(this.vaultPath);
  @override
  String vaultPath;
  final changes = StreamController<String>.broadcast();
  @override
  Stream<String> watchVaultPath() => changes.stream;
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('life_os_vault_');
  });
  tearDown(() async {
    final tempRoot = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(tempRoot, target))
      throw StateError('Unexpected temporary vault path.');
    await directory.delete(recursive: true);
  });

  test(
    'indexes markdown lazily, skips hidden folders and returns immutable snapshots',
    () async {
      await File(
        p.join(directory.path, 'first.md'),
      ).writeAsString('first text');
      await Directory(p.join(directory.path, 'nested')).create();
      await File(
        p.join(directory.path, 'nested', 'second.MD'),
      ).writeAsString('second text');
      await Directory(p.join(directory.path, '.obsidian')).create();
      await File(
        p.join(directory.path, '.obsidian', 'ignored.md'),
      ).writeAsString('hidden');
      await File(p.join(directory.path, 'ignored.txt')).writeAsString('other');
      final vault = ObsidianVault();
      try {
        await vault.openVault(directory.path);
        expect(vault.state.error, isNull);
        expect(vault.state.notes, hasLength(2));
        expect(vault.state.notes.every((note) => note.content.isEmpty), isTrue);
        expect(() => vault.state.notes.clear(), throwsUnsupportedError);
        expect(
          await vault.readContent(p.join(directory.path, 'first.md')),
          'first text',
        );
        expect((await vault.watch().first).notes, hasLength(2));
      } finally {
        await vault.dispose();
      }
    },
  );

  test(
    'atomic writes update content and queued writes finish before stop',
    () async {
      final file = File(p.join(directory.path, 'note.md'));
      await file.writeAsString('old');
      final vault = ObsidianVault();
      await vault.openVault(directory.path);
      final writing = vault.writeContent(file.path, 'new');
      final stopping = vault.stop();
      await Future.wait([writing, stopping]);
      expect(await file.readAsString(), 'new');
      await expectLater(
        vault.writeContent(file.path, 'stopped'),
        throwsStateError,
      );
      await vault.openVault(directory.path);
      expect(await vault.readContent(file.path), 'new');
      await expectLater(
        vault.writeContent(p.join(directory.path, 'missing.md'), 'invalid'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await file.readAsString(), 'new');
      expect((await directory.list().toList()).whereType<File>(), hasLength(1));
      await vault.dispose();
    },
  );

  test(
    'creating a note never overwrites an existing file and sanitizes path separators',
    () async {
      final vault = ObsidianVault();
      await vault.openVault(directory.path);
      final note = await vault.createNote('Existing', 'keep me');
      await expectLater(
        vault.createNote('Existing', 'overwrite'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(note.absolutePath).readAsString(), 'keep me');
      final safe = await vault.createNote(
        'parent' + String.fromCharCode(92) + 'child/file',
        'safe',
      );
      expect(p.isWithin(directory.path, safe.absolutePath), isTrue);
      expect(File(safe.absolutePath).parent.path, directory.path);
      await vault.dispose();
    },
  );

  test(
    'plugin follows settings and cancels every directory watcher on stop',
    () async {
      final second = Directory(p.join(directory.path, 'second'));
      await second.create();
      final settings = TestVaultSettings(directory.path);
      final controllers = <StreamController<FileSystemEvent>>[];
      var listeners = 0;
      final vault = ObsidianVault(
        watchDirectory: (_) {
          late final StreamController<FileSystemEvent> events;
          events = StreamController<FileSystemEvent>.broadcast(
            onListen: () => listeners++,
            onCancel: () => listeners--,
          );
          controllers.add(events);
          return events.stream;
        },
      );
      final plugin = ObsidianPlugin(vault: vault, settings: settings);
      await plugin.start();
      expect(listeners, 2);
      final switched = vault.watch().firstWhere(
        (state) => state.vaultPath == second.path && !state.isLoading,
      );
      settings.vaultPath = second.path;
      settings.changes.add(second.path);
      await switched;
      expect(listeners, 1);
      await plugin.stop();
      expect(listeners, 0);
      settings.changes.add(directory.path);
      await Future<void>.delayed(Duration.zero);
      expect(listeners, 0);
      await vault.dispose();
      await settings.changes.close();
      for (final controller in controllers) {
        await controller.close();
      }
    },
  );

  test('native watchers detect markdown creation in a nested folder', () async {
    final nested = Directory(p.join(directory.path, 'nested'));
    await nested.create();
    final vault = ObsidianVault();
    try {
      await vault.openVault(directory.path);
      final changed = vault
          .watch()
          .firstWhere((state) => state.notes.any((note) => note.title == 'new'))
          .timeout(const Duration(seconds: 5));
      await File(p.join(nested.path, 'new.md')).writeAsString('new content');
      expect((await changed).notes.single.title, 'new');
    } finally {
      await vault.dispose();
    }
  });
}
