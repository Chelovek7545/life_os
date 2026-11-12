import 'dart:convert';
import 'package:test/test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:notes_api/notes_api.dart';
import 'package:lifegraph_plugin/canvas_document.dart';

void main() {
  CanvasEntity entity(String id, {String? parent, double x = 1.6}) =>
      CanvasEntity(
        node: GraphNodeData(
          id: id,
          kind: 'task',
          title: 'Задача',
          color: '#FF0000',
          parentId: parent,
          attributes: {'taskStatus': 'notStarted'},
        ),
        position: GraphPoint(x, -20.4),
        width: 176,
        height: 68,
      );
  CanvasNote note(String id, {NoteReference? source}) => CanvasNote(
    document: NoteDocument(id: id, text: 'Текст', source: source),
    x: 2,
    y: 3,
    width: 250,
    height: 180,
    index: 0,
  );
  Map<String, Object?> build(
    List<CanvasEntity> entities, [
    List<CanvasNote> notes = const [],
  ]) => createSphereCanvas(
    sphereId: 'sphere',
    entities: entities,
    notes: notes,
    filePath: (path) => 'Notes/file.md',
  );

  test('standard text cards retain Pulse identity and integer geometry', () {
    final result = jsonDecode(jsonEncode(build([entity('one')])));
    final card = result['nodes'][0];
    expect(card['type'], 'text');
    expect(card['pulse'], {'kind': 'task', 'entityId': 'one'});
    expect(card['x'], 2);
    expect(card['y'], -20);
    expect(card['width'], 176);
    expect(card['text'], contains('notStarted'));
    expect(result['pulse'], {'version': 1, 'sphereId': 'sphere'});
  });
  test('only projected parents produce deterministic hierarchy edges', () {
    final result = build([
      entity('root'),
      entity('child', parent: 'root'),
      entity('orphan', parent: 'absent'),
    ]);
    final edges = result['edges'] as List;
    expect(edges, hasLength(1));
    expect(edges.single['fromNode'], 'pulse:root');
    expect(edges.single['toNode'], 'pulse:child');
    expect(edges.single['pulse'], {'kind': 'hierarchy'});
    expect(
      build([entity('root'), entity('child', parent: 'root')])['edges'],
      edges,
    );
  });
  test(
    'stickers and vault notes use text and file without identity collisions',
    () {
      final result = build(
        [entity('same')],
        [
          note('same'),
          note(
            'file',
            source: const NoteReference(sourceId: 'obsidian', path: 'absolute'),
          ),
        ],
      );
      final nodes = result['nodes'] as List;
      expect(nodes[1]['id'], 'note:same');
      expect(nodes[1]['text'], 'Текст');
      expect(nodes[2]['type'], 'file');
      expect(nodes[2]['file'], 'Notes/file.md');
      expect(nodes[2].containsKey('text'), isFalse);
    },
  );
  test('duplicate cards and non-finite coordinates fail explicitly', () {
    expect(() => build([entity('same'), entity('same')]), throwsArgumentError);
    expect(() => build([entity('one', x: double.nan)]), throwsArgumentError);
  });
  test('a note outside the save root is readable and retains its source', () {
    final result = createSphereCanvas(
      sphereId: 'sphere',
      entities: [],
      notes: [
        note(
          'external',
          source: const NoteReference(
            sourceId: 'obsidian',
            path: '/vault/Knowledge/note.md',
          ),
        ),
      ],
      filePath: (_) => throw ArgumentError('Outside root'),
    );
    final card = (result['nodes'] as List).single;
    expect(card['type'], 'text');
    expect(card['text'], 'Текст');
    expect(card['pulse']['externalPath'], '/vault/Knowledge/note.md');
    expect(card.containsKey('file'), isFalse);
  });
  test('unknown note sources are not silently flattened', () {
    expect(
      () => build([], [
        note(
          'one',
          source: const NoteReference(sourceId: 'other', path: 'file'),
        ),
      ]),
      throwsUnsupportedError,
    );
  });
}
