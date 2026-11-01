import 'dart:async';
import 'package:graph_api/graph_api.dart';
import 'package:test/test.dart';
import 'package:life_os/features/lifegraph/domain/graph_builder.dart';

class MutableContributor implements GraphContributor {
  MutableContributor(this.id, this.snapshot);
  @override
  final String id;
  List<GraphNodeData> snapshot;
  final changes = StreamController<List<GraphNodeData>>.broadcast();
  int listeners = 0;
  Completer<void>? cancelGate;
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) =>
      Stream.multi((listener) {
        listeners++;
        listener.add(snapshot);
        final subscription = changes.stream.listen(listener.add);
        listener.onCancel = () async {
          await subscription.cancel();
          await cancelGate?.future;
          listeners--;
        };
      }, isBroadcast: true);
  void emit(List<GraphNodeData> value) {
    snapshot = value;
    changes.add(value);
  }
}

GraphNodeData node(
  String id, {
  String kind = 'custom',
  String? parent,
  String color = '#123456',
  bool inherit = false,
}) => GraphNodeData(
  id: id,
  kind: kind,
  title: id,
  color: color,
  parentId: parent,
  inheritParentColor: inherit,
);

void main() {
  test(
    'projects arbitrarily deep, unordered nodes and excludes orphaned cycles',
    () async {
      final registry = GraphContributorRegistry();
      final source = MutableContributor('source', [
        node('deep', parent: 'child', inherit: true),
        node('cycle-a', parent: 'cycle-b'),
        node('cycle-b', parent: 'cycle-a'),
        node('other-root'),
        node('other-child', parent: 'other-root'),
        node('root', kind: 'custom-root', color: '#ABCDEF'),
        node('child', parent: 'root', inherit: true),
      ]);
      registry.register('module', [source]);
      final result = await GraphBuilder(
        registry: registry,
        rootKind: 'custom-root',
      ).watchGraph('root').first;
      expect(result.map((value) => value.id), ['root', 'child', 'deep']);
      expect(result.map((value) => value.color), everyElement('#ABCDEF'));
      expect(() => result.clear(), throwsUnsupportedError);
      await registry.dispose();
      await source.changes.close();
    },
  );
  test('a new contributor kind works without changing the assembler', () async {
    final registry = GraphContributorRegistry();
    final root = MutableContributor('root-source', [
      node('root', kind: 'custom-root'),
    ]);
    final extra = MutableContributor('journal', [
      node('journal:1', kind: 'journal.entry', parent: 'root'),
    ]);
    registry.register('root', [root]);
    final iterator = StreamIterator(
      GraphBuilder(
        registry: registry,
        rootKind: 'custom-root',
      ).watchGraph('root'),
    );
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(1));
    registry.register('journal', [extra]);
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current.last.kind, 'journal.entry');
    expect(root.listeners, 1);
    expect(extra.listeners, 1);
    registry.unregister('journal');
    expect(await iterator.moveNext(), isTrue);
    expect(iterator.current, hasLength(1));
    expect(extra.listeners, 0);
    await iterator.cancel();
    expect(root.listeners, 0);
    await registry.dispose();
    await root.changes.close();
    await extra.changes.close();
  });
  test(
    'registry disposal stops active projections and contributor subscriptions',
    () async {
      final registry = GraphContributorRegistry();
      final root = MutableContributor('root', [node('root', kind: 'root')]);
      registry.register('root', [root]);
      final iterator = StreamIterator(
        GraphBuilder(registry: registry, rootKind: 'root').watchGraph('root'),
      );
      await iterator.moveNext();
      final disposing = registry.dispose();
      expect(await iterator.moveNext(), isTrue);
      expect(iterator.current, isEmpty);
      expect(await iterator.moveNext(), isFalse);
      await disposing;
      expect(root.listeners, 0);
      await root.changes.close();
    },
  );
  test(
    'missing roots emit empty snapshots and later root changes propagate',
    () async {
      final registry = GraphContributorRegistry();
      final source = MutableContributor('source', [
        node('child', parent: 'root'),
      ]);
      registry.register('source', [source]);
      final iterator = StreamIterator(
        GraphBuilder(registry: registry, rootKind: 'root').watchGraph('root'),
      );
      await iterator.moveNext();
      expect(iterator.current, isEmpty);
      source.emit([node('root', kind: 'root'), node('child', parent: 'root')]);
      await iterator.moveNext();
      expect(iterator.current, hasLength(2));
      source.emit([]);
      await iterator.moveNext();
      expect(iterator.current, isEmpty);
      await iterator.cancel();
      await registry.dispose();
      await source.changes.close();
    },
  );
  test(
    'duplicate node IDs fail explicitly instead of overwriting another module',
    () async {
      final registry = GraphContributorRegistry();
      final source = MutableContributor('source', [
        node('root', kind: 'root'),
        node('root'),
      ]);
      registry.register('source', [source]);
      await expectLater(
        GraphBuilder(
          registry: registry,
          rootKind: 'root',
        ).watchGraph('root').first,
        throwsStateError,
      );
      await registry.dispose();
      await source.changes.close();
    },
  );
  test('unregister waits for a contributor to release its resources', () async {
    final registry = GraphContributorRegistry();
    final root = MutableContributor('root', [node('root', kind: 'root')]);
    registry.register('root', [root]);
    final iterator = StreamIterator(
      GraphBuilder(registry: registry, rootKind: 'root').watchGraph('root'),
    );
    await iterator.moveNext();
    root.cancelGate = Completer<void>();
    var stopped = false;
    final stopping = registry.unregister('root').then((_) => stopped = true);
    await Future<void>.delayed(Duration.zero);
    expect(stopped, isFalse);
    expect(root.listeners, 1);
    root.cancelGate!.complete();
    await stopping;
    expect(root.listeners, 0);
    await iterator.cancel();
    await registry.dispose();
    await root.changes.close();
  });
  test('duplicate contributor registration is atomic', () async {
    final registry = GraphContributorRegistry();
    final source = MutableContributor('source', []);
    registry.register('first', [source]);
    expect(
      () =>
          registry.register('second', [MutableContributor('new', []), source]),
      throwsArgumentError,
    );
    expect(registry.contributors.map((item) => item.id), ['source']);
    await registry.dispose();
    await source.changes.close();
  });
}
