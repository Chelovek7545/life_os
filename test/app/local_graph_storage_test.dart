import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';
import 'package:path/path.dart' as p;
import 'package:spheres_api/spheres_api.dart';
import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temporary;
  late GraphStorageTarget previous;
  DependencyContainer? app;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('pulse_local_app_');
    previous = SettingsService.graphStorageTarget.value;
    SettingsService.graphStorageTarget.value = GraphStorageTarget(
      mode: GraphStorageMode.local,
      localPath: p.join(temporary.path, 'Pulse'),
    );
  });
  tearDown(() async {
    await app?.dispose();
    app = null;
    SettingsService.graphStorageTarget.value = previous;
    if (!p.isWithin(
      await Directory.systemTemp.resolveSymbolicLinks(),
      await temporary.resolveSymbolicLinks(),
    )) {
      throw StateError('Invalid test path');
    }
    await temporary.delete(recursive: true);
  });
  test('Resources deletes only current Notes files without Obsidian', () async {
    app = await createTestApp(enableObsidian: false);
    final resources = app!.resourcesViewModel;
    final note = await resources.createMarkdownNote('Delete', 'body');
    expect(resources.canDeleteMarkdown, isTrue);
    final outside = File(p.join(temporary.path, 'Outside.md'));
    await outside.writeAsString('keep');
    await expectLater(
      resources.deleteMarkdownNote(outside.path),
      throwsStateError,
    );
    final deletion = resources.deleteMarkdownNote(note.absolutePath);
    await app!.dispose();
    app = null;
    await deletion;
    expect(await File(note.absolutePath).exists(), isFalse);
    expect(await outside.readAsString(), 'keep');
    await expectLater(
      resources.deleteMarkdownNote(note.absolutePath),
      throwsStateError,
    );
  });
  test(
    'existing Notes files expose their content after opening the application',
    () async {
      final file = File(
        p.join(temporary.path, 'Pulse', 'Notes', 'nested', 'Existing.md'),
      );
      await file.parent.create(recursive: true);
      await file.writeAsString('# Existing\nPreview survives reopening');
      app = await createTestApp(enableObsidian: false);
      expect(
        app!.resourcesViewModel.graphMarkdownState.notes.single.content,
        '# Existing\nPreview survives reopening',
      );
      await app!.resourcesViewModel.refreshVault();
      expect(
        app!.resourcesViewModel.graphMarkdownState.notes.single.content,
        '# Existing\nPreview survives reopening',
      );
    },
  );
  test(
    'Resources creates only Notes files and finishes accepted creation before shutdown',
    () async {
      app = await createTestApp(enableObsidian: false);
      final resources = app!.resourcesViewModel;
      final note = await resources.createMarkdownNote(
        'Library file',
        '# Markdown body',
      );
      expect(
        note.absolutePath,
        p.join(temporary.path, 'Pulse', 'Notes', 'Library file.md'),
      );
      expect(await File(note.absolutePath).readAsString(), '# Markdown body');
      expect(
        resources.graphMarkdownState.notes.single.absolutePath,
        note.absolutePath,
      );
      expect(resources.getAllNotes(), isEmpty);
      await expectLater(
        resources.createMarkdownNote('Library file', 'overwrite'),
        throwsA(isA<FileSystemException>()),
      );
      expect(await File(note.absolutePath).readAsString(), '# Markdown body');
      final pending = resources.createMarkdownNote(
        'Accepted',
        'finish writing',
      );
      await app!.dispose();
      app = null;
      expect(
        await File((await pending).absolutePath).readAsString(),
        'finish writing',
      );
      await expectLater(
        resources.createMarkdownNote('Stale', 'no'),
        throwsStateError,
      );
    },
  );
  for (final withObsidian in [false, true]) {
    test(
      'renaming preserves live and closed graph links, Obsidian=$withObsidian',
      () async {
        final previousVault = SettingsService.obsidianVaultPath.value;
        final vault = Directory(p.join(temporary.path, 'Vault'));
        await vault.create();
        SettingsService.obsidianVaultPath.value = vault.path;
        try {
          app = await createTestApp(enableObsidian: withObsidian);
          final spheres = [
            for (final name in ['A', 'B', 'Closed']) Sphere.create(name: name),
          ];
          for (final sphere in spheres) {
            await app!.spheresRepository.addSphere(sphere);
          }
          final first = await app!.pulseScreenViewModel.openGraph(
            spheres[0].id,
          );
          await first.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
          final source = withObsidian
              ? (await app!.obsidianRepository!.createNote(
                  'Original',
                  'body',
                )).absolutePath
              : await first.createMarkdownNote(title: 'Original', text: 'body');
          if (withObsidian) {
            await first.createNoteWithText(
              title: '',
              text: '',
              obsidianPath: source,
            );
          }
          final second = await app!.pulseScreenViewModel.openGraph(
            spheres[1].id,
          );
          await second.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
          await second.createNoteWithText(
            title: '',
            text: '',
            obsidianPath: source,
          );
          final closed = await app!.pulseScreenViewModel.openGraph(
            spheres[2].id,
          );
          await closed.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
          await closed.createNoteWithText(
            title: '',
            text: '',
            obsidianPath: source,
          );
          await closed.dispose();
          final firstId = first.notes.single.id;
          final secondId = second.notes.single.id;
          final position = second.notes.single.position;
          await first.updateNoteText(firstId, 'last accepted draft');
          final renamed = second.notesStream.firstWhere(
            (notes) => notes.single.source!.path != source,
          );
          final path = await first.renameNote(firstId, 'Renamed');
          await renamed;
          await second.flush();
          expect(first.notes.single.id, firstId);
          expect(second.notes.single.id, secondId);
          expect(second.notes.single.position, position);
          expect(second.notes.single.source!.path, path);
          expect(await File(source).exists(), isFalse);
          expect(await File(path).readAsString(), 'last accepted draft');
          expect(
            (await app!.graphNotesRepository.loadNotes(
              spheres[1].id,
            ))!.single.document.source!.path,
            path,
          );
          final reopened = await app!.pulseScreenViewModel.openGraph(
            spheres[2].id,
          );
          await reopened.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
          expect(reopened.notes.single.source!.path, path);
          expect(reopened.notes.single.text, 'last accepted draft');
          expect(
            first.markdownLibraryNotes.map((note) => note.absolutePath),
            withObsidian ? isEmpty : contains(path),
          );
          expect(
            first.obsidianLibraryNotes.map((note) => note.absolutePath),
            withObsidian ? contains(path) : isEmpty,
          );
          await app!.pulseScreenViewModel.closeGraphs();
          final again = await app!.pulseScreenViewModel.openGraph(
            spheres[0].id,
          );
          await again.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
          expect(again.notes.single.source!.path, path);
        } finally {
          await app?.dispose();
          app = null;
          SettingsService.obsidianVaultPath.value = previousVault;
        }
      },
    );
  }
  test(
    'local graph and markdown persist and reopen with Obsidian disabled',
    () async {
      app = await createTestApp(enableObsidian: false);
      final sphere = Sphere.create(name: 'Local');
      await app!.spheresRepository.addSphere(sphere);
      final vm = await app!.pulseScreenViewModel.openGraph(sphere.id);
      await vm.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
      final notePath = await vm.createMarkdownNote(
        title: 'Note',
        text: 'local body',
      );
      vm.commitMove(sphere.id, 300, 400);
      await vm.flush();
      expect(app!.obsidianRepository, isNull);
      expect(
        vm.canvasBoardPath,
        p.join(temporary.path, 'Pulse', 'Boards', '${sphere.id}.canvas'),
      );
      expect(notePath, p.join(temporary.path, 'Pulse', 'Notes', 'Note.md'));
      await app!.dispose();
      app = await createTestApp(enableObsidian: false);
      await app!.spheresRepository.addSphere(sphere);
      final reopened = await app!.pulseScreenViewModel.openGraph(sphere.id);
      await reopened.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
      expect(reopened.notes.single.text, 'local body');
      expect(reopened.graph.single.position.dx, 300);
    },
  );
  test(
    'changing local roots finishes writes and rejects stale graph operations',
    () async {
      app = await createTestApp(enableObsidian: false);
      final sphere = Sphere.create(name: 'Switch');
      await app!.spheresRepository.addSphere(sphere);
      final vm = await app!.pulseScreenViewModel.openGraph(sphere.id);
      await vm.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
      final source = await vm.createMarkdownNote(title: 'Note', text: 'first');
      await vm.updateNoteText(vm.notes.single.id, 'last accepted edit');
      final next = GraphStorageTarget(
        mode: GraphStorageMode.local,
        localPath: p.join(temporary.path, 'Next Pulse'),
      );
      await app!.graphStorageRepository.selectTarget(next);
      await SettingsService.setGraphStorageTarget(next);
      expect(vm.isClosing, isTrue);
      final cached = await app!.graphNotesRepository.loadNotes(sphere.id);
      expect(cached!.single.document.source!.path, source);
      await app!.resourcesViewModel.updateNoteContent(
        source,
        'library edit after switch',
      );
      await expectLater(
        vm.createMarkdownNote(title: 'stale'),
        throwsStateError,
      );
      final reopened = await app!.pulseScreenViewModel.openGraph(sphere.id);
      await reopened.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
      expect(reopened.notes.single.text, 'library edit after switch');
      expect(reopened.notes.single.source!.path, source);
      expect(await File(source).readAsString(), 'library edit after switch');
      expect(
        await File(p.join(next.localPath, 'Notes', 'Note.md')).exists(),
        isFalse,
      );
    },
  );
  test(
    'local boards can add and reopen original Obsidian notes without copying them',
    () async {
      final previousVault = SettingsService.obsidianVaultPath.value;
      final vault = Directory(p.join(temporary.path, 'Vault', 'Knowledge'));
      await vault.create(recursive: true);
      final original = File(p.join(vault.path, 'Original.md'));
      await original.writeAsString('Original text');
      SettingsService.obsidianVaultPath.value = vault.parent.path;
      try {
        app = await createTestApp();
        final sphere = Sphere.create(name: 'Mixed sources');
        await app!.spheresRepository.addSphere(sphere);
        final vm = await app!.pulseScreenViewModel.openGraph(sphere.id);
        await vm.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
        expect(vm.vaultNotes.single.absolutePath, original.path);
        await vm.createNoteWithText(
          title: '',
          text: '',
          obsidianPath: original.path,
        );
        final linkedId = vm.notes.single.id;
        await vm.createMarkdownNote(title: 'Graph note', text: 'new text');
        await vm.flush();
        expect(
          app!.resourcesViewModel.vaultNotes.map((n) => n.absolutePath),
          contains(original.path),
        );
        await app!.pulseScreenViewModel.closeGraphs();
        final reopened = await app!.pulseScreenViewModel.openGraph(sphere.id);
        await reopened.graphStream.firstWhere((nodes) => nodes.isNotEmpty);
        final linked = reopened.notes.singleWhere((n) => n.id == linkedId);
        expect(linked.source!.path, original.path);
        expect(linked.text, 'Original text');
        await reopened.updateNoteText(linkedId, 'Edited from Pulse');
        await reopened.flush();
        expect(await original.readAsString(), 'Edited from Pulse');
        expect(
          app!.obsidianRepository!.state.notes.single.content,
          'Edited from Pulse',
        );
        expect(
          await File(
            p.join(temporary.path, 'Pulse', 'Knowledge', 'Original.md'),
          ).exists(),
          isFalse,
        );
        expect(
          await File(
            p.join(temporary.path, 'Pulse', 'Notes', 'Graph note.md'),
          ).readAsString(),
          'new text',
        );
      } finally {
        await app?.dispose();
        app = null;
        SettingsService.obsidianVaultPath.value = previousVault;
      }
    },
  );
}
