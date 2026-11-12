import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late ObsidianVault vault;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pulse_canvas_');
    vault = ObsidianVault();
    await vault.openVault(directory.path);
  });
  tearDown(() async {
    await vault.dispose();
    final root = await Directory.systemTemp.resolveSymbolicLinks();
    final target = await directory.resolveSymbolicLinks();
    if (!p.isWithin(root, target)) throw StateError('Unexpected test path');
    await directory.delete(recursive: true);
  });
  test(
    'exports distinct complete snapshots and leaves existing edits intact',
    () async {
      final first = await vault.createCanvas('sphere', {
        'nodes': [],
        'edges': [],
      });
      await File(first).writeAsString('user edits');
      final second = await vault.createCanvas('sphere', {
        'nodes': [],
        'edges': [],
      });
      expect(first, isNot(second));
      expect(await File(first).readAsString(), 'user edits');
      expect(jsonDecode(await File(second).readAsString()), {
        'nodes': [],
        'edges': [],
      });
      expect(p.isWithin(directory.path, second), isTrue);
      expect(p.extension(second), '.canvas');
      expect(
        await Directory(
          p.dirname(second),
        ).list().any((e) => e.path.endsWith('.tmp')),
        isFalse,
      );
    },
  );
  test('file references are vault relative with portable separators', () {
    expect(
      vault.canvasNotePath(p.join(directory.path, 'Notes', 'Заметка.md')),
      'Notes/Заметка.md',
    );
    expect(
      () => vault.canvasNotePath(p.join(directory.parent.path, 'outside.md')),
      throwsArgumentError,
    );
  });
  test('invalid sphere identifiers cannot choose the export path', () async {
    await expectLater(
      vault.createCanvas('../outside', {'nodes': []}),
      throwsArgumentError,
    );
  });
  test(
    'accepted export finishes before stop and new export is rejected',
    () async {
      final exporting = vault.createCanvas('sphere', {'nodes': []});
      await vault.stop();
      expect(await File(await exporting).exists(), isTrue);
      expect(
        () => vault.createCanvas('sphere', {'nodes': []}),
        throwsStateError,
      );
    },
  );
  test('vault changes invalidate queued exports', () async {
    final exporting = vault.createCanvas('sphere', {'nodes': []});
    final checked = expectLater(exporting, throwsStateError);
    final reopening = vault.openVault(directory.path);
    await checked;
    await reopening;
  });
}
