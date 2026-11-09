import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:tasks_api/tasks_api.dart';
import 'config.dart';

class McpServerPlugin implements AppPlugin {
  McpServerPlugin({
    required TasksApi tasks,
    required TaskCompletionCommands completion,
    McpServerOptions? options,
  });
  Uri? get endpoint => null;
  @override
  String get id => 'agents.mcp';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async =>
      throw UnsupportedError('Local MCP requires a native platform.');
  @override
  Future<void> stop() async {}
}
