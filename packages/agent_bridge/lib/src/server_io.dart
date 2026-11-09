import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:tasks_api/tasks_api.dart';
import '../task_tools.dart';
import 'config.dart';

class _Session {
  bool initialized = false;
  DateTime touched = DateTime.now();
}

class McpServerPlugin implements AppPlugin {
  McpServerPlugin({
    required this.tasks,
    required this.completion,
    McpServerOptions? options,
  }) : options =
           options ??
           McpServerOptions(
             token: Platform.environment['LIFE_OS_MCP_TOKEN'] ?? '',
           );
  final TasksApi tasks;
  final TaskCompletionCommands completion;
  final McpServerOptions options;
  static const protocolVersion = '2025-06-18';
  HttpServer? _server;
  TaskAgentTools? _tools;
  bool _stopping = false;
  final _sessions = <String, _Session>{};
  final _requests = <Future<void>>{};
  Uri? get endpoint => _server == null
      ? null
      : Uri(
          scheme: 'http',
          host: '127.0.0.1',
          port: _server!.port,
          path: '/mcp',
        );
  @override
  String get id => 'agents.mcp';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    if (_server != null) return;
    if (options.token.length < 32 ||
        options.token.length > 256 ||
        !RegExp(r'^[!-~]+$').hasMatch(options.token)) {
      throw StateError(
        'MCP needs LIFE_OS_MCP_TOKEN: 32–256 printable ASCII characters without spaces.',
      );
    }
    if (options.port < 0 || options.port > 65535) {
      throw ArgumentError.value(options.port, 'port');
    }
    _stopping = false;
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      options.port,
      shared: false,
    );
    _server = server;
    _tools = TaskAgentTools(tasks: tasks, completion: completion);
    server.listen((request) {
      final operation = _handle(request);
      _requests.add(operation);
      unawaited(operation.whenComplete(() => _requests.remove(operation)));
    });
  }

  @override
  Future<void> stop() async {
    _stopping = true;
    final server = _server;
    _server = null;
    try {
      await server?.close(force: true);
      await Future.wait(_requests.toList());
    } finally {
      await _tools?.close();
      _tools = null;
      _sessions.clear();
    }
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      await _route(request);
    } on TimeoutException {
      await _status(request, 408);
    } on FormatException {
      await _rpc(
        request,
        null,
        error: {'code': -32700, 'message': 'Invalid JSON.'},
        status: 400,
      );
    } catch (_) {
      await _status(request, 500);
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _route(HttpRequest request) async {
    final host = request.headers.value(HttpHeaders.hostHeader);
    final port = request.connectionInfo?.localPort;
    if (host != '127.0.0.1:$port' && host != 'localhost:$port') {
      await _status(request, 403);
      return;
    }
    // Browser origins are unnecessary for agent clients and rejected entirely.
    if (request.headers.value('origin') != null) {
      await _status(request, 403);
      return;
    }
    if (!_matches(
      request.headers.value(HttpHeaders.authorizationHeader) ?? '',
      'Bearer ${options.token}',
    )) {
      await _status(request, 401);
      return;
    }
    if (_stopping || _tools == null) {
      await _status(request, 503);
      return;
    }
    if (request.uri.path != '/mcp' || request.uri.hasQuery) {
      await _status(request, 404);
      return;
    }
    if (_requests.length >= 16) {
      await _status(request, 429);
      return;
    }
    _sessions.removeWhere(
      (_, value) =>
          DateTime.now().difference(value.touched) >
          const Duration(minutes: 30),
    );
    if (request.method == 'GET') {
      request.response.headers.set(HttpHeaders.allowHeader, 'POST, DELETE');
      await _status(request, 405);
      return;
    }
    if (request.method == 'DELETE') {
      final session = request.headers.value('Mcp-Session-Id');
      await _status(request, _sessions.remove(session) == null ? 404 : 204);
      return;
    }
    if (request.method != 'POST') {
      await _status(request, 405);
      return;
    }
    if (request.headers.contentType?.mimeType != 'application/json') {
      await _status(request, 415);
      return;
    }
    final accept = request.headers.value(HttpHeaders.acceptHeader) ?? '';
    if (!accept.contains('application/json') ||
        !accept.contains('text/event-stream')) {
      await _status(request, 406);
      return;
    }
    final bytes = <int>[];
    if (request.contentLength > 65536) {
      await _status(request, 413);
      return;
    }
    await for (final chunk in request.timeout(const Duration(seconds: 5))) {
      bytes.addAll(chunk);
      if (bytes.length > 65536) {
        await _status(request, 413);
        // Flush the rejection before cancelling the unread request stream.
        await request.response.close();
        return;
      }
    }
    if (_stopping) {
      await _status(request, 503);
      return;
    }
    final message = jsonDecode(utf8.decode(bytes));
    if (message is! Map<String, dynamic> ||
        message['jsonrpc'] != '2.0' ||
        message['method'] is! String ||
        (message.containsKey('id') &&
            message['id'] is! int &&
            message['id'] is! String)) {
      await _rpc(
        request,
        null,
        error: {'code': -32600, 'message': 'Invalid JSON-RPC request.'},
        status: 400,
      );
      return;
    }
    final id = message['id'];
    final method = message['method'] as String;
    final params = message['params'] ?? <String, dynamic>{};
    if (params is! Map<String, dynamic>) {
      await _rpc(
        request,
        id,
        error: {'code': -32602, 'message': 'params must be an object.'},
      );
      return;
    }
    if (method == 'initialize' && message.containsKey('id')) {
      if (params['protocolVersion'] is! String ||
          params['clientInfo'] is! Map ||
          params['capabilities'] is! Map) {
        await _rpc(
          request,
          id,
          error: {
            'code': -32602,
            'message': 'Invalid initialization parameters.',
          },
        );
        return;
      }
      if (_sessions.length >= 32) {
        await _status(request, 429);
        return;
      }
      final random = Random.secure();
      final session = base64Url.encode(
        List.generate(32, (_) => random.nextInt(256)),
      );
      _sessions[session] = _Session();
      request.response.headers.set('Mcp-Session-Id', session);
      await _rpc(
        request,
        id,
        result: {
          'protocolVersion': protocolVersion,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {'name': 'life-os', 'version': '0.1.0'},
          'instructions':
              'Local Life OS task tools. Creation is not idempotent; completion is. No deletion or arbitrary SQL is exposed.',
        },
      );
      return;
    }
    final sessionId = request.headers.value('Mcp-Session-Id');
    final session = _sessions[sessionId];
    if (session == null) {
      await _status(request, sessionId == null ? 400 : 404);
      return;
    }
    if (request.headers.value('MCP-Protocol-Version') != protocolVersion) {
      await _status(request, 400);
      return;
    }
    session.touched = DateTime.now();
    if (!message.containsKey('id')) {
      if (method == 'notifications/initialized') session.initialized = true;
      await _status(request, 202);
      return;
    }
    if (method == 'ping') {
      await _rpc(request, id, result: {});
      return;
    }
    if (!session.initialized) {
      await _rpc(
        request,
        id,
        error: {'code': -32000, 'message': 'Initialize the session first.'},
      );
      return;
    }
    switch (method) {
      case 'tools/list':
        if (params.containsKey('cursor')) {
          await _rpc(
            request,
            id,
            error: {'code': -32602, 'message': 'Unknown cursor.'},
          );
          return;
        }
        await _rpc(request, id, result: {'tools': TaskAgentTools.definitions});
      case 'tools/call':
        final name = params['name'];
        final args = params['arguments'] ?? <String, dynamic>{};
        if (name is! String || args is! Map<String, dynamic>) {
          await _rpc(
            request,
            id,
            error: {'code': -32602, 'message': 'Invalid tool call.'},
          );
          return;
        }
        try {
          final output = await _tools!.call(name, args);
          await _rpc(
            request,
            id,
            result: {
              'content': [
                {'type': 'text', 'text': jsonEncode(output)},
              ],
              'structuredContent': output,
              'isError': output.containsKey('error'),
            },
          );
        } on ToolInputException catch (error) {
          await _rpc(
            request,
            id,
            error: {'code': -32602, 'message': error.message},
          );
        } catch (_) {
          await _rpc(
            request,
            id,
            result: {
              'content': [
                {
                  'type': 'text',
                  'text':
                      'The task operation failed. Check current data before retrying a write.',
                },
              ],
              'isError': true,
            },
          );
        }
      default:
        await _rpc(
          request,
          id,
          error: {'code': -32601, 'message': 'Method not found.'},
        );
    }
  }

  Future<void> _status(HttpRequest request, int code) async {
    try {
      request.response.statusCode = code;
      if (code >= 400) request.response.persistentConnection = false;
    } catch (_) {}
  }

  Future<void> _rpc(
    HttpRequest request,
    Object? id, {
    Object? result,
    Map<String, Object?>? error,
    int status = 200,
  }) async {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.write(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        if (error != null) 'error': error else 'result': result,
      }),
    );
  }
}

bool _matches(String received, String expected) {
  final a = utf8.encode(received), b = utf8.encode(expected);
  var difference = a.length ^ b.length;
  for (var i = 0; i < b.length; i++) {
    difference |= (i < a.length ? a[i] : 0) ^ b[i];
  }
  return difference == 0;
}
