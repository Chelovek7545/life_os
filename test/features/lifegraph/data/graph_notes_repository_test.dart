import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:notes_api/notes_api.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/features/lifegraph/data/graph_notes_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'rename updates every catalog scope and normalizes queued stale snapshots before close',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = GraphNotesRepository();
      const note = CanvasNote(
        document: NoteDocument(
          id: 'id',
          text: 'body',
          source: NoteReference(sourceId: 'obsidian', path: '/Notes/Old.md'),
        ),
        x: 1,
        y: 2,
        width: 250,
        height: 180,
        index: 3,
      );
      await store.saveNotes('one', [note]);
      await store.saveNotes('two', [note]);
      await store.renameSource('/Notes/Old.md', '/Notes/New.md');
      final saving = store.saveNotes('two', [note]);
      await store.dispose();
      await saving;
      final reopened = GraphNotesRepository();
      for (final scope in ['one', 'two']) {
        final restored = (await reopened.loadNotes(scope))!.single;
        expect(restored.document.source!.path, '/Notes/New.md');
        expect(restored.id, 'id');
        expect(restored.text, 'body');
        expect(restored.x, 1);
        expect(restored.index, 3);
      }
      await reopened.dispose();
    },
  );
  test(
    'loads legacy snapshots without filesystem access and preserves source links',
    () async {
      SharedPreferences.setMockInitialValues({
        'graph_notes.sphere': jsonEncode({
          'v': 1,
          'notes': {
            'local': {
              'text': 'local text',
              'x': 3,
              'y': 4,
              'w': 210,
              'h': 120,
              'index': 1,
            },
            'external': {
              'type': 'obsidianNote',
              'obsidianPath': '/unavailable/note.md',
              'x': 10,
              'y': 20,
            },
          },
        }),
      });
      final store = GraphNotesRepository();
      final loaded = (await store.loadNotes('sphere'))!;
      expect(loaded.first.text, 'local text');
      expect(loaded.last.document.source!.sourceId, 'obsidian');
      expect(loaded.last.document.source!.path, '/unavailable/note.md');
      expect(() => loaded.clear(), throwsUnsupportedError);
      await store.saveNotes('sphere', [
        loaded.first,
        CanvasNote(
          document: NoteDocument(
            id: 'external',
            text: 'cached external text',
            source: loaded.last.document.source,
          ),
          x: 10,
          y: 20,
          width: 212,
          height: 150,
          index: 2,
        ),
      ]);
      final reopened = GraphNotesRepository();
      final restored = (await reopened.loadNotes('sphere'))!;
      expect(restored.last.text, 'cached external text');
      expect(restored.last.document.source!.path, '/unavailable/note.md');
      expect(
        (await store.watchNotes().first).last.text,
        'cached external text',
      );
      await reopened.dispose();
      await store.dispose();
    },
  );
  test('unknown snapshots remain available for recovery', () async {
    const raw = '{invalid snapshot';
    SharedPreferences.setMockInitialValues({'graph_notes.old': raw});
    final store = GraphNotesRepository();
    await store.init();
    expect(
      (await SharedPreferences.getInstance()).getString('graph_notes.old'),
      raw,
    );
    expect(store.notes, isEmpty);
    await store.dispose();
  });
}
