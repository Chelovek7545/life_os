import 'dart:convert';
import 'dart:io';
import 'package:tasks_api/tasks_api.dart';
import '../../tasks/support/memory_tasks.dart';

const token = 'test-token-012345678901234567890123456789';

class Completion implements TaskCompletionCommands {
  Completion(this.tasks);
  final MemoryTasks tasks;
  @override
  Future<Task?> completeTask(String id) async {
    final task = tasks.items[id];
    if (task == null || task.isCompleted) return task;
    final updated = task.copyWith(status: TaskStatus.done);
    await tasks.updateTask(updated);
    return updated;
  }
}

class McpClient {
  McpClient(this.endpoint);
  Uri endpoint;
  final client = HttpClient();
  String? session;
  int serial = 0;
  Future<({int status, Map<String, dynamic>? body, String? session})> send(
    Object data, {
    String method = 'POST',
    String? authorization = 'Bearer $token',
    String? origin,
    String? host,
    String version = '2025-06-18',
    bool raw = false,
  }) async {
    final request = await client.openUrl(method, endpoint);
    request.headers.contentType = ContentType.json;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/json, text/event-stream',
    );
    if (authorization != null) {
      request.headers.set(HttpHeaders.authorizationHeader, authorization);
    }
    if (session != null) request.headers.set('Mcp-Session-Id', session!);
    request.headers.set('MCP-Protocol-Version', version);
    if (origin != null) request.headers.set('origin', origin);
    if (host != null) request.headers.set(HttpHeaders.hostHeader, host);
    if (method == 'POST') request.write(raw ? data : jsonEncode(data));
    final response = await request.close();
    final text = await utf8.decoder.bind(response).join();
    return (
      status: response.statusCode,
      body: text.isEmpty ? null : jsonDecode(text) as Map<String, dynamic>,
      session: response.headers.value('Mcp-Session-Id'),
    );
  }

  Future<Map<String, dynamic>> rpc(
    String method, [
    Map<String, Object?> params = const {},
  ]) async => (await send({
    'jsonrpc': '2.0',
    'id': ++serial,
    'method': method,
    'params': params,
  })).body!;
  Future<void> initialize() async {
    final response = await send({
      'jsonrpc': '2.0',
      'id': ++serial,
      'method': 'initialize',
      'params': {
        'protocolVersion': '2025-11-25',
        'capabilities': {},
        'clientInfo': {'name': 'test', 'version': '1'},
      },
    });
    session = response.session;
    await send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
  }

  Future<Map<String, dynamic>> tool(
    String name, [
    Map<String, Object?> arguments = const {},
  ]) => rpc('tools/call', {'name': name, 'arguments': arguments});
  void close() => client.close(force: true);
}
