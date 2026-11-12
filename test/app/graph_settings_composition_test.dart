import 'package:flutter_test/flutter_test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_folders_form.dart';
import '../support/test_app.dart';

class _BuilderContext extends Fake implements BuildContext {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('saved graph settings form cannot write after module restart', () async {
    final before = SettingsService.graphFolders.value;
    final app = await createTestApp(enableObsidian: false);
    try {
      final contribution = app.ui.settings.singleWhere(
        (s) => s.id == 'lifegraph.storage.settings',
      );
      final oldForm =
          contribution.builder(_BuilderContext()) as GraphFoldersForm;
      await app.lifeGraphPlugin.plugins.single.stop();
      await app.lifeGraphPlugin.plugins.single.start();
      await expectLater(
        oldForm.save(const VaultFolders(boards: 'Stale')),
        throwsStateError,
      );
      expect(SettingsService.graphFolders.value.toJson(), before.toJson());
    } finally {
      await app.dispose();
    }
  });
  test(
    'graph owns its settings contribution even with Obsidian disabled',
    () async {
      final app = await createTestApp(enableObsidian: false);
      try {
        expect(
          app.ui.settings.any(
            (s) => s.id == 'lifegraph.storage.settings' && s.title == 'Граф',
          ),
          isTrue,
        );
        expect(
          app.ui.settings.any((s) => s.id == 'obsidian.settings'),
          isFalse,
        );
        await app.lifeGraphPlugin.plugins.single.stop();
        expect(
          app.ui.settings.any((s) => s.id == 'lifegraph.storage.settings'),
          isFalse,
        );
      } finally {
        await app.dispose();
      }
    },
  );
  test(
    'graph applies folders and owns their subscription across restarts',
    () async {
      final previous = SettingsService.graphFolders.value;
      final oldRoot = SettingsService.obsidianVaultPath.value;
      SettingsService.obsidianVaultPath.value = '';
      SettingsService.graphFolders.value = const VaultFolders(boards: 'Stored');
      final app = await createTestApp();
      try {
        final vault = app.obsidianRepository!;
        expect(vault.folders.boards, 'Stored');
        SettingsService.graphFolders.value = const VaultFolders(
          boards: 'Updated',
        );
        await Future<void>.delayed(Duration.zero);
        expect(vault.folders.boards, 'Updated');
        await app.lifeGraphPlugin.plugins.single.stop();
        SettingsService.graphFolders.value = const VaultFolders(
          boards: 'Next launch',
        );
        await Future<void>.delayed(Duration.zero);
        expect(vault.folders.boards, 'Updated');
        await app.lifeGraphPlugin.plugins.single.start();
        expect(vault.folders.boards, 'Next launch');
      } finally {
        await app.dispose();
        SettingsService.graphFolders.value = previous;
        SettingsService.obsidianVaultPath.value = oldRoot;
      }
    },
  );
}
