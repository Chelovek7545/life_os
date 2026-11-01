import 'dart:async';
import 'package:graph_api/graph_api.dart';
import 'package:test/test.dart';

GraphNodeData node(String id, {String kind = 'sample', String? parent}) =>
    GraphNodeData(
      id: id,
      kind: kind,
      title: id,
      color: '#123456',
      parentId: parent,
    );

void main() {
  const scope = GraphScope(rootId: 'root', rootKind: 'root');
  final parent = node('root', kind: 'root');
  final request = GraphCreateRequest(
    scope: scope,
    parent: parent,
    draft: GraphNodeDraft(kind: 'sample', title: 'New'),
  );

  test(
    'dispatches commands by kind and rejects unsupported parents before writing',
    () async {
      final registry = GraphCommandRegistry();
      addTearDown(registry.dispose);
      var writes = 0;
      registry.register('sample', [
        GraphNodeCommands(
          kind: 'sample',
          parentKinds: {'root'},
          create: (request) async {
            writes++;
            return 'new';
          },
          update: (request) async {
            writes++;
          },
        ),
      ]);
      expect(await registry.create(request), 'new');
      await expectLater(
        registry.create(
          GraphCreateRequest(
            scope: scope,
            parent: node('wrong'),
            draft: request.draft,
          ),
        ),
        throwsUnsupportedError,
      );
      final current = node('existing', parent: 'root');
      await expectLater(
        registry.update(
          GraphUpdateRequest(
            scope: scope,
            current: current,
            updated: node(current.id, kind: 'other', parent: 'root'),
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        registry.update(
          GraphUpdateRequest(
            scope: scope,
            current: current,
            updated: node(current.id, parent: 'other'),
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(
        registry.delete(
          GraphDeleteRequest(scope: scope, node: current, keepChildren: false),
        ),
        throwsUnsupportedError,
      );
      expect(writes, 1);
    },
  );

  test(
    'unregister rejects new work and dispose joins an existing drain',
    () async {
      final registry = GraphCommandRegistry();
      final entered = Completer<void>();
      final gate = Completer<void>();
      registry.register('sample', [
        GraphNodeCommands(
          kind: 'sample',
          parentKinds: {'root'},
          create: (request) async {
            entered.complete();
            await gate.future;
            return 'new';
          },
        ),
      ]);
      final creating = registry.create(request);
      await entered.future;
      var stopped = false;
      final stopping = registry
          .unregister('sample')
          .then((_) => stopped = true);
      expect(
        () => registry.register('replacement', [
          GraphNodeCommands(kind: 'sample'),
        ]),
        throwsArgumentError,
      );
      var disposed = false;
      final disposing = registry.dispose().then((_) => disposed = true);
      await expectLater(registry.create(request), throwsUnsupportedError);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      expect(disposed, isFalse);
      gate.complete();
      expect(await creating, 'new');
      await Future.wait([stopping, disposing]);
      expect(stopped && disposed, isTrue);
    },
  );

  test(
    'command failure reaches its caller and does not prevent owner removal',
    () async {
      final registry = GraphCommandRegistry();
      addTearDown(registry.dispose);
      final gate = Completer<void>();
      registry.register('sample', [
        GraphNodeCommands(
          kind: 'sample',
          parentKinds: {'root'},
          create: (request) async {
            await gate.future;
            throw StateError('Write failed');
          },
        ),
      ]);
      final creating = expectLater(registry.create(request), throwsStateError);
      final stopping = registry.unregister('sample');
      gate.complete();
      await Future.wait([creating, stopping]);
      expect(registry.canCreate('sample', 'root'), isFalse);
    },
  );

  test(
    'duplicate command registration is atomic and does not replace the owner',
    () async {
      final registry = GraphCommandRegistry();
      addTearDown(registry.dispose);
      registry.register('first', [
        GraphNodeCommands(kind: 'sample', update: (_) async {}),
      ]);
      expect(
        () => registry.register('second', [
          GraphNodeCommands(kind: 'new', update: (_) async {}),
          GraphNodeCommands(kind: 'sample'),
        ]),
        throwsArgumentError,
      );
      expect(registry.canUpdate('sample'), isTrue);
      expect(registry.canUpdate('new'), isFalse);
      await registry.unregister('first');
      expect(registry.canUpdate('sample'), isFalse);
    },
  );
}
