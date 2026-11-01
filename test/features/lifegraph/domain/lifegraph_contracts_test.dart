import 'dart:async';
import 'package:test/test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:notes_api/notes_api.dart';
import 'package:lifegraph_plugin/lifegraph_logic.dart';
import 'package:life_os/features/lifegraph/domain/canvas_note.dart' as legacy;
import '../../../support/memory_graph_sources.dart';

class _Nodes implements GraphContributor {
  final source = MemorySource<List<GraphNodeData>>([
    GraphNodeData(id: 'root', kind: 'root', title: 'Root', color: '#123456'),
    GraphNodeData(
      id: 'child',
      kind: 'extension',
      title: 'Child',
      color: '#000000',
      parentId: 'root',
      inheritParentColor: true,
    ),
  ]);
  @override
  String get id => 'nodes';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) => source.watch();
}

void main() {
  test(
    'canvas storage contracts and coordinate values are independent of Flutter',
    () {
      const point = GraphPoint(10, 20);
      expect(point, const GraphPoint(10, 20));
      expect(point.hashCode, const GraphPoint(10, 20).hashCode);
      const note = CanvasNote(
        document: NoteDocument(
          id: 'note',
          text: 'Cache',
          source: NoteReference(sourceId: 'other', path: 'note.md'),
        ),
        x: 1,
        y: 2,
        width: 100,
        height: 80,
        index: 0,
      );
      expect(note, isA<legacy.CanvasNote>());
      expect(note.document.source!.sourceId, 'other');
    },
  );

  test(
    'graph projection owns its source leases and rejects subscriptions after disposal',
    () async {
      final registry = GraphContributorRegistry();
      final contributor = _Nodes();
      registry.register('extension', [contributor]);
      final builder = GraphBuilder(registry: registry, rootKind: 'root');
      final loaded = Completer<List<GraphNodeData>>();
      final stream = builder.watchGraph('root');
      final sub = stream.listen((nodes) {
        if (!loaded.isCompleted) loaded.complete(nodes);
      });
      final nodes = await loaded.future;
      expect(nodes.last.color, '#123456');
      expect(contributor.source.listeners, hasLength(1));
      await builder.dispose();
      expect(contributor.source.listeners, isEmpty);
      expect(() => builder.watchGraph('root'), throwsStateError);
      await expectLater(stream.toList(), throwsStateError);
      await sub.cancel();
      await registry.dispose();
    },
  );
}
