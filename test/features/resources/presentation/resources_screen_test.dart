import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:notes_api/notes_api.dart';
import 'package:resources_plugin/resources_plugin.dart' show ResourcesViewModel;
import '../../../support/memory_graph_sources.dart';

class _Library extends MemoryVault implements NotesLibrarySourcesApi {
  @override
  VaultState? obsidianState;
  @override
  VaultState graphMarkdownState = VaultState();
}

VaultNote _note(String path, String title) => VaultNote(
  absolutePath: path,
  relativePath: '$title.md',
  title: title,
  modifiedAt: DateTime(2026, 11, 12),
  content: 'Body of $title',
);

void main() {
  testWidgets(
    'cached Notes folder Markdown stays readable when its file becomes unavailable',
    (tester) async {
      final notes = MemoryCanvasNotes();
      final files = _Library()..stopped = true;
      files.graphMarkdownState = VaultState(
        vaultPath: '/Pulse/Notes',
        notes: [_note('/Pulse/Notes/Offline.md', 'Offline')],
      );
      final vm = ResourcesViewModel(notes: notes, vault: files);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourcesScreen(viewModel: vm)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Offline'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offline'));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, 'Body of Offline');
      expect(field.readOnly, isTrue);
      expect(find.text('Сохранить'), findsNothing);
      expect(
        find.text('Исходный файл недоступен. Показана сохранённая версия.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await vm.close();
    },
  );
  testWidgets(
    'local notes remain available when the vault plugin is disabled',
    (tester) async {
      final notes = MemoryCanvasNotes();
      final vm = ResourcesViewModel(notes: notes);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourcesScreen(viewModel: vm)),
        ),
      );
      await tester.pump();
      expect(find.text('Ресурсы и Заметки'), findsOneWidget);
      expect(find.text('Интеграция с хранилищем отключена.'), findsOneWidget);
      expect(find.text('Markdown-заметки графа'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -900));
      await tester.pumpAndSettle();
      expect(find.text('Нет локальных стикеров на графах.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await vm.close();
    },
  );

  for (final width in [1100.0, 360.0]) {
    testWidgets('separate file panels open originals and fit width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final notes = MemoryCanvasNotes();
      final files = _Library();
      final vaultNote = _note(
        '/Vault/Obsidian original.md',
        'Obsidian original',
      );
      final graphNote = _note('/Pulse/Notes/Graph file.md', 'Graph file');
      files.obsidianState = VaultState(vaultPath: '/Vault', notes: [vaultNote]);
      files.graphMarkdownState = VaultState(
        vaultPath: '/Pulse/Notes',
        notes: [graphNote],
      );
      files.source.emit(
        VaultState(vaultPath: '/Pulse', notes: [graphNote, vaultNote]),
      );
      files.files.addAll({
        vaultNote.absolutePath: 'Vault body',
        graphNote.absolutePath: 'Graph body',
      });
      notes.source.emit([
        const NoteDocument(id: 'sticker', text: 'Unlinked sticker'),
        NoteDocument(
          id: 'vault-link',
          text: 'Vault cached body',
          source: NoteReference(
            sourceId: 'obsidian',
            path: vaultNote.absolutePath,
          ),
        ),
        const NoteDocument(
          id: 'outside-link',
          text: 'Outside cached body',
          source: NoteReference(
            sourceId: 'obsidian',
            path: '/Other/Elsewhere.md',
          ),
        ),
        NoteDocument(
          id: 'linked',
          text: 'Cached markdown body',
          source: NoteReference(
            sourceId: 'obsidian',
            path: graphNote.absolutePath,
          ),
        ),
        NoteDocument(
          id: 'repeated',
          text: 'Older body',
          source: NoteReference(
            sourceId: 'obsidian',
            path: graphNote.absolutePath,
          ),
        ),
      ]);
      final vm = ResourcesViewModel(notes: notes, vault: files);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourcesScreen(viewModel: vm)),
        ),
      );
      await tester.pumpAndSettle();
      final obsidianPosition = tester.getTopLeft(find.text('Obsidian Vault'));
      final graphPosition = tester.getTopLeft(
        find.text('Markdown-заметки графа'),
      );
      if (width > 840) {
        expect(graphPosition.dy, obsidianPosition.dy);
        expect(graphPosition.dx, greaterThan(obsidianPosition.dx));
      } else {
        expect(graphPosition.dy, greaterThan(obsidianPosition.dy));
      }
      expect(find.text('Obsidian original'), findsOneWidget);
      expect(find.text('Elsewhere'), findsNothing);
      expect(find.text('Graph file'), findsOneWidget);
      expect(find.text('Cached markdown body'), findsNothing);
      await tester.ensureVisible(find.text('Graph file'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Graph file'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Graph body'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Edited graph file');
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(files.files[graphNote.absolutePath], 'Edited graph file');
      expect(files.files[vaultNote.absolutePath], 'Vault body');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Obsidian original'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obsidian original'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Vault body'), findsOneWidget);
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await vm.close();
    });
  }

  testWidgets(
    'Obsidian errors do not hide local markdown and source updates rebuild the panel',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final files = _Library();
      files.obsidianState = VaultState(
        vaultPath: '/Vault',
        error: 'Vault unavailable',
      );
      final notes = MemoryCanvasNotes();
      final vm = ResourcesViewModel(notes: notes, vault: files);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourcesScreen(viewModel: vm)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Vault unavailable'), findsOneWidget);
      final added = _note('/Pulse/Notes/New markdown.md', 'New markdown');
      files.graphMarkdownState = VaultState(
        vaultPath: '/Pulse/Notes',
        notes: [added],
      );
      files.source.emit(VaultState(vaultPath: '/Pulse', notes: [added]));
      await tester.pumpAndSettle();
      expect(find.text('New markdown'), findsOneWidget);
      expect(find.text('Vault unavailable'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await vm.close();
    },
  );
}
