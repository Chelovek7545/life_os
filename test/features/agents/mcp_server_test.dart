import 'dart:async';
import 'dart:io';
import 'package:agent_bridge/agent_bridge.dart';
import 'package:test/test.dart';
import '../tasks/support/memory_tasks.dart';
import 'support/agent_harness.dart';

void main() {
  late MemoryTasks store;
  late McpServerPlugin server;
  late McpClient client;
  setUp(() async {
    store = MemoryTasks();
    server = McpServerPlugin(
      tasks: store,
      completion: Completion(store),
      options: const McpServerOptions(token: token, port: 0),
    );
    await server.start();
    client = McpClient(server.endpoint!);
  });
  tearDown(() async {
    client.close();
    await server.stop();
  });

  test(
    'negotiates the supported version and executes all tools over HTTP',
    () async {
      final initialized = await client.send({
        'jsonrpc': '2.0',
        'id': 1,
        'method': 'initialize',
        'params': {
          'protocolVersion': '2025-11-25',
          'clientInfo': {'name': 'test', 'version': '1'},
          'capabilities': {},
        },
      });
      expect(initialized.body!['result']['protocolVersion'], '2025-06-18');
      client.session = initialized.session;
      expect((await client.rpc('tools/list'))['error']['code'], -32000);
      expect(
        (await client.send({
          'jsonrpc': '2.0',
          'method': 'notifications/initialized',
        })).status,
        202,
      );
      final list = await client.rpc('tools/list');
      expect((list['result']['tools'] as List).map((tool) => tool['name']), [
        'tasks_list',
        'tasks_create',
        'tasks_complete',
      ]);
      final created = await client.tool('tasks_create', {'title': 'Через MCP'});
      final id = created['result']['structuredContent']['task']['id'] as String;
      expect(
        (await client.tool('tasks_list', {
          'query': 'через',
        }))['result']['structuredContent']['total'],
        1,
      );
      expect(
        (await client.tool('tasks_complete', {'id': id}))['result']['isError'],
        isFalse,
      );
      expect(store.items[id]!.isCompleted, isTrue);
    },
  );

  test(
    'requires token, loopback Host, native origin and valid content',
    () async {
      expect((await client.send({}, method: 'GET')).status, 405);
      expect((await client.send({}, authorization: null)).status, 401);
      expect(
        (await client.send({}, authorization: 'Bearer wrong')).status,
        401,
      );
      expect(
        (await client.send({}, origin: 'https://untrusted.example')).status,
        403,
      );
      final untrusted = McpClient(server.endpoint!);
      addTearDown(untrusted.close);
      expect((await untrusted.send({}, host: 'untrusted.example')).status, 403);
      expect((await client.send('invalid json', raw: true)).status, 400);
      expect(
        (await client.send([
          {'jsonrpc': '2.0', 'id': 1, 'method': 'initialize'},
        ])).status,
        400,
      );
      expect((await client.send('x' * 65537, raw: true)).status, 413);
      expect(store.items, isEmpty);
    },
  );

  test(
    'independent clients have separate sessions and deleted sessions cannot act',
    () async {
      final other = McpClient(server.endpoint!);
      addTearDown(other.close);
      await client.initialize();
      await other.initialize();
      expect(client.session, isNot(other.session));
      expect((await client.send({}, method: 'DELETE')).status, 204);
      expect(
        (await client.send({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'tools/list',
        })).status,
        404,
      );
      expect((await other.rpc('tools/list'))['result'], isNotNull);
      expect(
        (await other.send({
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'tools/list',
        }, version: 'unsupported')).status,
        400,
      );
    },
  );

  test(
    'tool and method errors do not expose storage exception details',
    () async {
      await client.initialize();
      expect((await client.rpc('not-a-method'))['error']['code'], -32601);
      expect((await client.tool('not-a-tool'))['error']['code'], -32602);
      expect(
        (await client.tool('tasks_create', {'title': ''}))['error']['code'],
        -32602,
      );
      store.failWrite = true;
      final error = await client.tool('tasks_create', {'title': 'Failed'});
      expect(error['result']['isError'], isTrue);
      expect(error.toString(), isNot(contains('StateError')));
      expect((await client.tool('tasks_list'))['result']['isError'], isFalse);
      expect(
        (await client.tool('tasks_complete', {
          'id': 'missing',
        }))['result']['isError'],
        isTrue,
      );
    },
  );

  test(
    'stop waits for an accepted write and a restart invalidates old sessions',
    () async {
      await client.initialize();
      final old = client.session;
      store.entered = Completer<void>();
      store.writeGate = Completer<void>();
      final request = client
          .tool('tasks_create', {'title': 'Accepted'})
          .then<void>((_) {}, onError: (Object _, StackTrace _) {});
      await store.entered!.future;
      var stopped = false;
      final closing = server.stop().then((_) => stopped = true);
      await Future<void>.delayed(Duration.zero);
      expect(stopped, isFalse);
      expect(server.endpoint, isNull);
      store.writeGate!.complete();
      await closing;
      await request;
      expect(store.items.values.single.title, 'Accepted');
      await server.start();
      client.endpoint = server.endpoint!;
      client.session = old;
      expect(
        (await client.send({
          'jsonrpc': '2.0',
          'id': 4,
          'method': 'tools/list',
        })).status,
        404,
      );
      await client.initialize();
      expect((await client.rpc('tools/list'))['result'], isNotNull);
    },
  );

  test(
    'startup failure does not leave resources or accept an empty credential',
    () async {
      final noToken = McpServerPlugin(
        tasks: store,
        completion: Completion(store),
        options: const McpServerOptions(token: '', port: 0),
      );
      await expectLater(noToken.start(), throwsStateError);
      await noToken.stop();
      expect(noToken.endpoint, isNull);
      final occupied = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final busy = McpServerPlugin(
        tasks: store,
        completion: Completion(store),
        options: McpServerOptions(token: token, port: occupied.port),
      );
      await expectLater(busy.start(), throwsA(isA<SocketException>()));
      await busy.stop();
      await occupied.close();
      await busy.start();
      expect(busy.endpoint, isNotNull);
      await busy.stop();
    },
  );
}
