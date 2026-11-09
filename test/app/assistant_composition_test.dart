import 'dart:convert';
import 'package:agent_bridge/local_assistant.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app/plugins/assistant_plugin_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/agents/support/assistant_fake.dart';
import '../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'assistant is independently optional and startup never loads a model',
    () async {
      final without = await createTestApp(enableObsidian: false);
      expect(without.assistantPlugin, isNull);
      await without.dispose();
      var creations = 0;
      final app = await createTestApp(
        enableObsidian: false,
        enableAssistant: true,
        assistantBackendFactory: (_) async {
          creations++;
          return FakeAssistantBackend();
        },
      );
      addTearDown(app.dispose);
      expect(
        app.ui
            .panelsFor('app.overlays')
            .any((p) => p.id == 'assistant.chat.overlay'),
        isTrue,
      );
      expect(creations, 0);
      expect(app.mcpPlugin, isNull);
    },
  );
  test(
    'local chat shares SQLite, persists configuration and revokes an old controller',
    () async {
      var calls = 0;
      final app = await createTestApp(
        enableObsidian: false,
        enableAssistant: true,
        assistantBackendFactory: (_) async => FakeAssistantBackend(
          reply: (_, _) => calls++ == 0
              ? '{"type":"tool_call","name":"tasks_create","arguments":{"title":"Через локальный чат"}}'
              : '{"type":"message","text":"Готово"}',
        ),
      );
      addTearDown(app.dispose);
      final old = app.assistantPlugin!.controller!;
      final selected = app.navigation.selectedId;
      await old.send('Создай задачу');
      expect(
        (await app.tasksRepository.getAllTasks()).single.title,
        'Через локальный чат',
      );
      expect(app.navigation.selectedId, selected);
      const settings = AssistantSettings(
        pythonExecutable: 'C:/Python/python.exe',
        modelDirectory: 'C:/Models/Qwen',
        device: 'CPU',
      );
      await old.configure(settings);
      final stored = (await SharedPreferences.getInstance()).getString(
        AssistantPlugin.settingsKey,
      )!;
      expect(jsonDecode(stored)['device'], 'CPU');
      await app.plugins.stop();
      expect(old.isActive, isFalse);
      await old.send('Старый callback');
      await app.plugins.start();
      final current = app.assistantPlugin!.controller!;
      expect(identical(old, current), isFalse);
      expect(current.state.settings.modelDirectory, settings.modelDirectory);
      expect(current.state.messages, isEmpty);
      expect((await app.tasksRepository.getAllTasks()).length, 1);
    },
  );
}
