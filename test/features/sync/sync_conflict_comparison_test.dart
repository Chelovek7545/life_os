import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/sync/presentation/sync_conflict_comparison.dart';
import 'package:life_os/features/sync/presentation/sync_text_difference.dart';
import 'package:sync_plugin/sync_logic.dart';

void main() {
  test('compares Canvas geometry and links by identifier', () {
    SyncRevision version(String id, int x, String target) {
      final board = SyncCanvasBoard('sphere', {
        'nodes': [
          {'id': 'a', 'type': 'text', 'text': 'Заголовок', 'x': x, 'y': 80},
          {'id': 'b', 'type': 'file', 'file': 'notes/Project.md'},
          {'id': 'c', 'type': 'text', 'text': 'План'},
        ],
        'edges': [
          {'id': 'edge', 'fromNode': 'a', 'toNode': target},
        ],
      });
      return SyncRevision(
        schemaVersion: 9,
        id: id,
        deviceId: id,
        entityId: board.id,
        entityType: 'canvasBoard',
        parents: [],
        payload: board.encode(),
      );
    }

    final versions = [version('local', 10, 'b'), version('tablet', 40, 'c')];
    final sections = compareSyncVersions(versions, {});

    expect(sections.map((section) => section.title), [
      'Карточка «Заголовок»',
      'Связь «Заголовок» → «notes/Project.md»',
    ]);
    expect(sections.first.fields.single.label, 'Положение по X');
    expect(sections.first.fields.single.values, ['10', '40']);
    expect(sections.last.fields.single.label, 'Конечная карточка');
    expect(sections.last.fields.single.values, ['notes/Project.md', 'План']);
    final merged = SyncCanvasBoard.decode(
      buildMergedSyncPayload(versions, {
        sections.first.fields.single: 1,
        sections.last.fields.single: 0,
      }),
    );
    expect(merged.document['nodes'].first['x'], 40);
    expect(merged.document['edges'].single['toNode'], 'b');
  });

  test('highlights changed Markdown lines and preserves line numbers', () {
    final excerpts = syncTextDifferences([
      '# План\n\n- Встреча\n- Обед\n\nИтоги',
      '# План\n\n- Созвон\n- Обед\n\nИтоги',
    ]);

    for (final (index, excerpt) in excerpts.indexed) {
      final changed = excerpt.lines.singleWhere(
        (line) => line.parts.any((part) => part.changed),
      );
      expect(changed.number, 3);
      expect(changed.parts.single.text, index == 0 ? '- Встреча' : '- Созвон');
      expect(excerpt.lines.last.parts.single.changed, isFalse);
    }
  });
}
