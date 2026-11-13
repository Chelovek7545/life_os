import 'package:agent_bridge/agent_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:life_os/core/database/database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks_api/tasks_api.dart';
import '../features/agents/support/agent_harness.dart';
import '../support/test_app.dart';

class _NetworkBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _NetworkBinding();
  test(
    'production defaults omit AI chat while MCP remains independently usable',
    () async {
      SharedPreferences.setMockInitialValues({});
      final app = DependencyContainer(
        database: AppDatabase(NativeDatabase.memory()),
        enableTelegram: false,
        enableObsidian: false,
        enableMcp: true,
        mcpOptions: const McpServerOptions(token: token, port: 0),
        assistantBackendFactory: (_) =>
            throw StateError('Default app must not start local AI'),
      );
      addTearDown(app.dispose);
      expect(app.enableAssistant, isFalse);
      await app.init();
      expect(app.assistantPlugin, isNull);
      expect(app.plugins.states.containsKey('assistant.chat'), isFalse);
      expect(
        app.ui
            .panelsFor('app.overlays')
            .any((panel) => panel.id == 'assistant.chat.overlay'),
        isFalse,
      );
      final client = McpClient(app.mcpPlugin!.endpoint!);
      addTearDown(client.close);
      await client.initialize();
      final created = await client.tool('tasks_create', {
        'title': 'MCP без AI-чата',
      });
      expect(created['result']['isError'], isFalse);
      final found = await client.tool('tasks_list', {
        'query': 'MCP без AI-чата',
      });
      expect(found['result']['structuredContent']['total'], 1);
    },
  );
  test('MCP is opt-in and does not register a listener by default', () async {
    final app = await createTestApp(enableObsidian: false);
    addTearDown(app.dispose);
    expect(app.mcpPlugin, isNull);
    expect(app.plugins.states.containsKey('agents.mcp'), isFalse);
  });

  test(
    'MCP uses live SQLite, preserves task details and work logs, and drains before database closure',
    () async {
      final app = await createTestApp(
        enableObsidian: false,
        enableMcp: true,
        mcpOptions: const McpServerOptions(token: token, port: 0),
      );
      addTearDown(app.dispose);
      final client = McpClient(app.mcpPlugin!.endpoint!);
      addTearDown(client.close);
      await client.initialize();
      final task = Task.blank().copyWith(
        title: 'Latest title',
        description: 'Preserved description',
        startsAt: Wrapped(DateTime(2027, 2, 3, 10)),
        tags: [const Tag(id: 0, name: 'important', colorHex: 0xFF112233)],
      );
      await app.tasksRepository.addTask(task);
      final log = WorkLog.blank(task.id);
      await app.workLogsRepository.addWorkLog(log);
      final changed = app.tasksRepository.watchTasks().firstWhere(
        (tasks) => tasks.any((item) => item.id == task.id && item.isCompleted),
      );
      final result = await client.tool('tasks_complete', {'id': task.id});
      expect(result['result']['isError'], isFalse);
      await changed;
      final saved = (await app.tasksRepository.getById(task.id))!;
      expect(saved.title, task.title);
      expect(saved.description, task.description);
      expect(saved.startsAt, task.startsAt);
      expect(saved.tags.single.name, 'important');
      expect(await app.workLogsRepository.getById(log.id), isNotNull);
      await client.tool('tasks_complete', {'id': task.id});
      expect(
        (await app.tasksRepository.getById(task.id))!.updatedAt,
        saved.updatedAt,
      );
      await app.tasksRepository.deleteTask(task.id);
      expect(
        (await client.tool('tasks_complete', {
          'id': task.id,
        }))['result']['isError'],
        isTrue,
      );
      expect(await app.tasksRepository.getById(task.id), isNull);
      await client.tool('tasks_create', {'title': 'Created through MCP'});
      final found = await client.tool('tasks_list', {
        'query': 'created through',
      });
      expect(found['result']['structuredContent']['total'], 1);
      final oldEndpoint = app.mcpPlugin!.endpoint;
      await app.plugins.stop();
      expect(app.mcpPlugin!.endpoint, isNull);
      await app.plugins.start();
      expect(app.mcpPlugin!.endpoint, isNotNull);
      expect(oldEndpoint, isNotNull);
    },
  );
}
