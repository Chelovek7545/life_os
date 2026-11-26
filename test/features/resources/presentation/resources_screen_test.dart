import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:notes_api/notes_api.dart';
import 'package:resources_plugin/resources_plugin.dart' show ResourcesViewModel;
import '../../../support/memory_graph_sources.dart';

class _Library extends MemoryVault
    implements NotesLibrarySourcesApi, MarkdownNoteDeleteApi {
  @override
  VaultState? obsidianState;
  @override
  VaultState graphMarkdownState = VaultState();
  @override
  Future<void> deleteMarkdownNote(String path) async {
    files.remove(path);
    graphMarkdownState = VaultState(
      vaultPath: graphMarkdownState.vaultPath,
      notes: [
        for (final note in graphMarkdownState.notes)
          if (note.absolutePath != path) note,
      ],
    );
    source.emit(
      VaultState(vaultPath: '/Pulse', notes: graphMarkdownState.notes),
    );
  }

  @override
  Future<bool> noteTitleExists(String title) async =>
      files.containsKey('/Pulse/Notes/$title.md');

  @override
  Future<VaultNote> createNote(String title, String content) async {
    if (await noteTitleExists(title)) throw const MarkdownNoteNameConflict();
    final note = VaultNote(
      absolutePath: '/Pulse/Notes/$title.md',
      relativePath: '$title.md',
      title: title,
      modifiedAt: DateTime(2026, 11, 12),
      content: content,
    );
    await writeContent(note.absolutePath, content);
    graphMarkdownState = VaultState(
      vaultPath: '/Pulse/Notes',
      notes: [...graphMarkdownState.notes, note],
    );
    source.emit(
      VaultState(vaultPath: '/Pulse', notes: graphMarkdownState.notes),
    );
    return note;
  }
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
    'deleting from the gallery requires confirmation and updates it',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final note = _note('/Pulse/Notes/To delete.md', 'To delete');
      final files = _Library()
        ..graphMarkdownState = VaultState(
          vaultPath: '/Pulse/Notes',
          notes: [note],
        );
      files.files[note.absolutePath] = 'body';
      final vm = ResourcesViewModel(notes: MemoryCanvasNotes(), vault: files);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourcesScreen(viewModel: vm)),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> requestDelete() async {
        await tester.tap(find.byTooltip('Действия заметки'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Удалить заметку'));
        await tester.pumpAndSettle();
      }

      await requestDelete();
      expect(find.text('Удалить заметку?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(files.files[note.absolutePath], 'body');
      expect(find.text('To delete'), findsOneWidget);
      await requestDelete();
      await tester.tap(find.byKey(const ValueKey('markdown-delete-confirm')));
      await tester.pumpAndSettle();
      expect(files.files.containsKey(note.absolutePath), isFalse);
      expect(find.text('To delete'), findsNothing);
      expect(find.text('Пока нет Markdown-заметок'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await vm.close();
    },
  );

  testWidgets(
    'the gallery keeps the draft on name conflicts and saves a retry',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final files = _Library()
        ..graphMarkdownState = VaultState(vaultPath: '/Pulse/Notes')
        ..files['/Pulse/Notes/Existing.md'] = 'original content';
      final notes = MemoryCanvasNotes();
      final vm = ResourcesViewModel(notes: notes, vault: files);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ResourcesScreen(viewModel: vm)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('markdown-create')));
      await tester.pumpAndSettle();
      final title = find.byKey(const ValueKey('markdown-note-title'));
      final body = find.byKey(const ValueKey('markdown-note-text'));
      final create = find.widgetWithText(FilledButton, 'Создать .md');
      final conflict = find.text(const MarkdownNoteNameConflict().toString());

      await tester.enterText(body, '# Body');
      await tester.enterText(title, 'Existing');
      await tester.pumpAndSettle();
      expect(conflict, findsOneWidget);
      expect(tester.widget<FilledButton>(create).onPressed, isNull);

      await tester.enterText(title, 'Created from gallery');
      await tester.pumpAndSettle();
      expect(conflict, findsNothing);
      files.files['/Pulse/Notes/Created from gallery.md'] = 'created elsewhere';
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(conflict, findsOneWidget);
      expect(
        tester.widget<TextField>(title).controller!.text,
        'Created from gallery',
      );
      expect(tester.widget<TextField>(body).controller!.text, '# Body');

      await tester.enterText(title, 'Another name');
      await tester.pumpAndSettle();
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      expect(files.files['/Pulse/Notes/Existing.md'], 'original content');
      expect(
        files.files['/Pulse/Notes/Created from gallery.md'],
        'created elsewhere',
      );
      expect(files.files['/Pulse/Notes/Another name.md'], '# Body');
      expect(find.text('Another name'), findsOneWidget);
      expect(vm.getAllNotes(), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await vm.close();
    },
  );

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
      expect(find.byType(Markdown), findsOneWidget);
      expect(find.text('Body of Offline', findRichText: true), findsWidgets);
      expect(find.text('Редактирование'), findsNothing);
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
      const graphBody =
          '# План\n\n1. Первый пункт\n2. Второй пункт\n'
          '\n- [x] Готово\n- [ ] Ожидает\n'
          '\n| День | Дело |\n| --- | --- |\n| Пн | Работа |\n';
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
        graphNote.absolutePath: graphBody,
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
      final obsidianPosition = tester.getTopLeft(
        find
            .ancestor(
              of: find.text('Obsidian Vault'),
              matching: find.byType(Card),
            )
            .first,
      );
      final graphPosition = tester.getTopLeft(
        find.byKey(const ValueKey('markdown-gallery')),
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
      final preview = find.byType(Markdown);
      final field = find.byKey(const ValueKey('resource-note-body'));
      expect(field, findsNothing);
      expect(find.text('План', findRichText: true), findsWidgets);
      expect(find.text('# План', findRichText: true), findsNothing);
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.byIcon(Icons.check_box), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outline_blank), findsOneWidget);
      expect(
        find.descendant(of: preview, matching: find.byType(Table)),
        findsOneWidget,
      );
      await tester.tap(find.text('Редактирование'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, graphBody);
      const edited = '# Новый план\n\n- **Новый пункт**\n';
      await tester.enterText(field, edited);
      await tester.tap(find.text('Предпросмотр'));
      await tester.pumpAndSettle();
      expect(find.text('Новый план', findRichText: true), findsWidgets);
      expect(find.text('Новый пункт', findRichText: true), findsWidgets);
      expect(find.text('•'), findsOneWidget);
      expect(files.files[graphNote.absolutePath], graphBody);
      await tester.tap(find.text('Редактирование'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(field).controller!.text, edited);
      await tester.tap(find.text('Предпросмотр'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(preview, findsNothing);
      expect(files.files[graphNote.absolutePath], edited);
      expect(files.files[vaultNote.absolutePath], 'Vault body');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Obsidian original'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Obsidian original'));
      await tester.pumpAndSettle();
      expect(preview, findsOneWidget);
      expect(find.text('Vault body', findRichText: true), findsWidgets);
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
