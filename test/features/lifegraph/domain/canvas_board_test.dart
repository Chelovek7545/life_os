import 'dart:convert';
import 'package:test/test.dart';
import 'package:lifegraph_plugin/canvas_board.dart';

Map<String, Object?> card(String id, {String type = 'text', String? entity}) =>
    {
      'id': id,
      'type': type,
      'x': -100,
      'y': 200,
      'width': 300,
      'height': 170,
      if (type == 'text') 'text': 'external text',
      if (type == 'file') 'file': 'Notes/one.md',
      if (entity != null) 'pulse': {'entityId': entity, 'kind': 'task'},
    };

void main() {
  CanvasBoardDocument board(List nodes, [List edges = const []]) =>
      CanvasBoardDocument(
        jsonEncode({
          'nodes': nodes,
          'edges': edges,
          'customRoot': {'keep': true},
        }),
      );

  test(
    'reads markdown cards and files while retaining unsupported content',
    () {
      final document = board([
        card('text'),
        card('file', type: 'file'),
        card('entity', entity: 'uuid'),
        {...card('image', type: 'file'), 'file': 'pic.png'},
        {...card('heading', type: 'file'), 'subpath': '#one'},
      ]);
      final notes = document.notes((path) => '/vault/$path');
      expect(notes.map((n) => n.id), ['text', 'file']);
      expect(notes.last.document.source!.path, '/vault/Notes/one.md');
      expect(notes.first.x, -100);
    },
  );
  test(
    'merges known cards by entity UUID and keeps unknown fields and edges',
    () {
      final document = board(
        [
          {...card('obsidian-id', entity: 'uuid'), 'custom': 42},
          card('group', type: 'group'),
          card('sticker'),
        ],
        [
          {
            'id': 'user-edge',
            'fromNode': 'group',
            'toNode': 'obsidian-id',
            'label': 'keep',
          },
        ],
      );
      final merged = document.merge({
        'nodes': [
          card('pulse:uuid', entity: 'uuid'),
          {...card('note:sticker'), 'text': 'edited'},
        ],
        'edges': [],
        'pulse': {'version': 1},
      });
      expect((merged['nodes'] as List).map((n) => n['id']), [
        'obsidian-id',
        'group',
        'sticker',
      ]);
      expect((merged['nodes'] as List).first['custom'], 42);
      expect((merged['nodes'] as List).last['text'], 'edited');
      expect((merged['edges'] as List).single['label'], 'keep');
      expect(merged['customRoot'], {'keep': true});
    },
  );
  test('deleted note removes incident edges but preserves unrelated ones', () {
    final document = board(
      [card('sticker'), card('group', type: 'group')],
      [
        {'id': 'removed', 'fromNode': 'sticker', 'toNode': 'group'},
        {'id': 'kept', 'fromNode': 'group', 'toNode': 'group'},
      ],
    );
    final result = document.merge({'nodes': [], 'edges': []});
    expect((result['nodes'] as List).single['id'], 'group');
    expect((result['edges'] as List).single['id'], 'kept');
  });
  test(
    'external snapshots restore their link and can return to a file card',
    () {
      final document = board([
        {
          ...card('external'),
          'pulse': {
            'noteId': 'external',
            'externalPath': '/vault/one.md',
            'custom': 1,
          },
        },
      ]);
      final note = document
          .notes((_) => throw StateError('Not relative'))
          .single;
      expect(note.document.source!.path, '/vault/one.md');
      expect(note.text, 'external text');
      final merged = document.merge({
        'nodes': [
          {
            ...card('note:external', type: 'file'),
            'pulse': {'noteId': 'external'},
          },
        ],
        'edges': [],
      });
      final file = (merged['nodes'] as List).single;
      expect(file['pulse'].containsKey('externalPath'), isFalse);
      expect(file['pulse']['custom'], 1);
      expect(file.containsKey('text'), isFalse);
      expect(
        CanvasBoardDocument(
          jsonEncode(merged),
        ).notes((p) => '/vault/$p').single.document.source!.path,
        '/vault/Notes/one.md',
      );
    },
  );
  test('hierarchy endpoints are mapped to actual Obsidian card IDs', () {
    final document = board([
      card('a', entity: 'one'),
      card('b', entity: 'two'),
    ]);
    final result = document.merge({
      'nodes': [
        card('pulse:one', entity: 'one'),
        card('pulse:two', entity: 'two'),
      ],
      'edges': [
        {
          'id': 'pulse-hierarchy:one:two',
          'fromNode': 'pulse:one',
          'toNode': 'pulse:two',
        },
      ],
    });
    expect((result['edges'] as List).single['fromNode'], 'a');
    expect((result['edges'] as List).single['toNode'], 'b');
  });
  test('invalid documents fail before any write', () {
    expect(() => CanvasBoardDocument('not json'), throwsFormatException);
    expect(() => board([card('a'), card('a')]), throwsFormatException);
    expect(
      () => board([card('a', entity: 'one'), card('b', entity: 'one')]),
      throwsFormatException,
    );
    expect(
      () => board([
        {...card('a'), 'width': 0},
      ]),
      throwsFormatException,
    );
  });
  test('future extensions and foreign sphere documents are rejected', () {
    final document = board([]);
    document.data['pulse'] = {'version': 2, 'sphereId': 'one'};
    expect(() => document.validateScope('one'), throwsFormatException);
    document.data['pulse'] = {'version': 1, 'sphereId': 'two'};
    expect(() => document.validateScope('one'), throwsFormatException);
  });
}
