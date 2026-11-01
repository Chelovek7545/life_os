import 'dart:async';
import 'package:graph_api/graph_api.dart';
import 'package:test/test.dart';

class Source implements GraphContributor {
  int active = 0;
  @override
  String get id => 'source';
  @override
  Stream<List<GraphNodeData>> watch(GraphScope scope) => Stream.multi((sink) {
    active++;
    sink.add(const []);
    sink.onCancel = () async {
      active--;
      throw StateError('Source cancellation failed');
    };
  });
}

void main() {
  const scope = GraphScope(rootId: 'root', rootKind: 'sample');
  test(
    'owner removal reports cancellation errors without repeating them on stream close',
    () async {
      final registry = GraphContributorRegistry();
      addTearDown(registry.dispose);
      final source = Source();
      registry.register('owner', [source]);
      final errors = <Object>[];
      final streams = [
        for (var i = 0; i < 2; i++)
          registry.contributors.single
              .watch(scope)
              .listen((_) {}, onError: errors.add),
      ];
      await Future<void>.delayed(Duration.zero);
      expect(source.active, 2);
      await expectLater(registry.unregister('owner'), throwsStateError);
      await Future<void>.delayed(Duration.zero);
      expect(source.active, 0);
      expect(errors, hasLength(2));
      expect(registry.contributors, isEmpty);
      for (final stream in streams) {
        await stream.cancel();
      }
    },
  );

  test(
    'explicit consumer cancellation still reports its failure and releases the lease',
    () async {
      final registry = GraphContributorRegistry();
      addTearDown(registry.dispose);
      final source = Source();
      registry.register('owner', [source]);
      final subscription = registry.contributors.single
          .watch(scope)
          .listen((_) {});
      await Future<void>.delayed(Duration.zero);
      await expectLater(subscription.cancel(), throwsStateError);
      expect(source.active, 0);
      await registry.unregister('owner');
      expect(registry.contributors, isEmpty);
    },
  );
}
