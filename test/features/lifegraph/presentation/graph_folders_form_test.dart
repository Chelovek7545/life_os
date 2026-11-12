import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_folders_form.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:lifegraph_plugin/graph_storage_settings.dart';

void main() {
  testWidgets('local storage chooses one folder and hides per-category paths', (
    tester,
  ) async {
    GraphStorageTarget? saved;
    var folderSaves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GraphFoldersForm(
              initial: const VaultFolders(),
              listFolders: () async => [],
              save: (_) async {
                folderSaves++;
              },
              saveTarget: (value) async {
                saved = value;
              },
              pickDirectory: () async => r'C:\Pulse',
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('graph-storage-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('В папке Pulse на компьютере').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('graph-folder-0')), findsNothing);
    await tester.tap(find.byTooltip('Выбрать папку Pulse'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Сохранить папки'));
    await tester.tap(find.text('Сохранить папки'));
    await tester.pumpAndSettle();
    expect(saved!.mode, GraphStorageMode.local);
    expect(saved!.localPath, r'C:\Pulse');
    expect(folderSaves, 0);
  });
  test('storage mode and single root survive settings reload', () async {
    final previous = SettingsService.graphStorageTarget.value;
    SharedPreferences.setMockInitialValues({});
    try {
      const target = GraphStorageTarget(
        mode: GraphStorageMode.local,
        localPath: r'C:\Pulse',
      );
      await SettingsService.setGraphStorageTarget(target);
      SettingsService.graphStorageTarget.value = const GraphStorageTarget();
      await SettingsService.init();
      expect(
        SettingsService.graphStorageTarget.value.toJson(),
        target.toJson(),
      );
    } finally {
      SettingsService.graphStorageTarget.value = previous;
    }
  });
  testWidgets(
    'folder browser selects a directory and form saves each category',
    (tester) async {
      VaultFolders? saved;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GraphFoldersForm(
                initial: const VaultFolders(),
                listFolders: () async => ['', 'Life/Boards'],
                save: (value) async {
                  saved = value;
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Выбрать папку').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Life/Boards'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('graph-folder-1')),
        'Notes',
      );
      await tester.ensureVisible(find.text('Сохранить папки'));
      await tester.tap(find.text('Сохранить папки'));
      await tester.pumpAndSettle();
      expect(saved!.boards, 'Life/Boards');
      expect(saved!.notes, 'Notes');
      expect(saved!.backups, 'Pulse/Backups');
    },
  );
  testWidgets('folder failures are shown without claiming success', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: GraphFoldersForm(
              initial: const VaultFolders(),
              listFolders: () async => [],
              save: (_) async => throw StateError('folder collision'),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Сохранить папки'));
    await tester.tap(find.text('Сохранить папки'));
    await tester.pumpAndSettle();
    expect(find.textContaining('folder collision'), findsOneWidget);
    expect(find.text('Папки сохранены'), findsNothing);
  });
  test('storage folders survive settings reload', () async {
    final previous = SettingsService.graphFolders.value;
    SharedPreferences.setMockInitialValues({});
    try {
      const folders = VaultFolders(
        boards: 'Life',
        notes: 'Notes',
        exports: '',
        backups: 'Backup',
      );
      await SettingsService.setGraphFolders(folders);
      SettingsService.graphFolders.value = const VaultFolders();
      await SettingsService.init();
      expect(SettingsService.graphFolders.value.toJson(), folders.toJson());
    } finally {
      SettingsService.graphFolders.value = previous;
    }
  });
  test(
    'existing Obsidian folder preferences migrate without resetting paths',
    () async {
      final previous = SettingsService.graphFolders.value;
      const old = VaultFolders(
        boards: 'My Boards',
        notes: 'My Notes',
        exports: 'Out',
        backups: 'Copies',
      );
      SharedPreferences.setMockInitialValues({
        'obsidian_folders_v1': jsonEncode(old.toJson()),
      });
      try {
        await SettingsService.init();
        expect(SettingsService.graphFolders.value.toJson(), old.toJson());
        await SettingsService.setGraphFolders(
          const VaultFolders(boards: 'New Boards'),
        );
        await SettingsService.init();
        expect(SettingsService.graphFolders.value.boards, 'New Boards');
        expect(
          (await SharedPreferences.getInstance()).getString(
            'obsidian_folders_v1',
          ),
          jsonEncode(old.toJson()),
        );
      } finally {
        SettingsService.graphFolders.value = previous;
      }
    },
  );
}
