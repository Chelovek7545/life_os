import 'dart:async';
import 'dart:convert';
import 'package:agent_bridge/local_assistant.dart';
import 'package:agent_bridge/task_tools.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:test/test.dart';
import '../tasks/support/memory_tasks.dart';
import 'support/agent_harness.dart';
import 'support/assistant_fake.dart';

String call(String name, Map<String, Object?> args) =>
    jsonEncode({'type': 'tool_call', 'name': name, 'arguments': args});
void main() {
  late MemoryTasks store;
  late FakeAssistantBackend backend;
  late AssistantController controller;
  AssistantController build({
    AssistantSettingsWriter? save,
    DateTime Function()? now,
  }) => AssistantController(
    tools: TaskAgentTools(tasks: store, completion: Completion(store)),
    backendFactory: (_) async => backend,
    settings: const AssistantSettings(),
    saveSettings: save ?? (_) async {},
    now: now,
  );
  setUp(() {
    store = MemoryTasks();
    backend = FakeAssistantBackend();
    controller = build();
  });
  tearDown(() => controller.close());

  test(
    'relative calendar dates refresh across midnight and year boundary',
    () async {
      await controller.close();
      var now = DateTime(2026, 12, 31, 23, 55);
      controller = build(now: () => now);
      await controller.send('Поставь задачу на завтра');
      final first = backend.prompts.last.first['content']!;
      expect(first, contains('tomorrow/завтра = 2027-01-01'));
      expect(first, contains('day after tomorrow/послезавтра = 2027-01-02'));
      expect(first, contains('"startsAt":"2027-01-01"'));
      now = DateTime(2027, 1, 1, 0, 5);
      await controller.send('А теперь на завтра');
      expect(
        backend.prompts.last.first['content'],
        contains('tomorrow/завтра = 2027-01-02'),
      );
    },
  );

  test(
    'lazy load, conversation memory, clear and no accidental operations',
    () async {
      expect(backend.starts, 0);
      await controller.send('Привет');
      await controller.send('Ещё вопрос');
      expect(backend.starts, 1);
      expect(store.writes, isEmpty);
      expect(backend.prompts.last.map((m) => m['content']), contains('Привет'));
      expect(controller.state.messages.length, 4);
      controller.clear();
      expect(controller.state.messages, isEmpty);
      await controller.send('Новый');
      expect(backend.prompts.last.length, 2);
    },
  );

  test(
    'lists and completes through existing tools, recording actual results',
    () async {
      final task = Task.blank().copyWith(title: 'Книга');
      store.items[task.id] = task;
      var turn = 0;
      backend = FakeAssistantBackend(
        reply: (messages, _) {
          switch (turn++) {
            case 0:
              return call('tasks_list', {'query': 'книга'});
            case 1:
              expect(messages.last['content'], contains(task.id));
              return call('tasks_complete', {'id': task.id});
            default:
              return '{"type":"message","text":"Готово"}';
          }
        },
      );
      await controller.send('Отметь Книгу выполненной');
      expect(store.items[task.id]!.isCompleted, isTrue);
      expect(
        controller.state.messages
            .where((m) => m.kind == AssistantMessageKind.action)
            .length,
        2,
      );
      expect(controller.state.messages.last.text, 'Готово');
      expect(controller.state.busy, isFalse);
    },
  );

  test('same successful create is not repeated within one turn', () async {
    var count = 0;
    backend = FakeAssistantBackend(
      reply: (_, _) => count++ < 2
          ? call('tasks_create', {'title': 'Одна задача'})
          : '{"type":"message","text":"Создана"}',
    );
    await controller.send('Создай одну задачу');
    expect(store.items.length, 1);
    expect(store.writes.length, 1);
    expect(
      controller.state.messages
          .where((m) => m.kind == AssistantMessageKind.action)
          .length,
      1,
    );
  });
  test(
    'native tool calls and their results remain in the next turn history',
    () async {
      var count = 0;
      backend = FakeAssistantBackend(
        reply: (_, _) => count++ == 0
            ? '<tool_call>{"name":"tasks_create","arguments":{"title":"Native"}}</tool_call>'
            : 'Готово',
      );
      await controller.send('Создай задачу');
      await controller.send('Продолжим');
      expect(store.items.values.single.title, 'Native');
      expect(
        backend.prompts.last.any(
          (message) =>
              message['role'] == 'tool' &&
              message['content']!.contains(store.items.keys.single),
        ),
        isTrue,
      );
    },
  );
  test(
    'multiple native calls in one reply are rejected before any writes',
    () async {
      backend = FakeAssistantBackend(
        reply: (_, _) =>
            '<tool_call>{"name":"tasks_create","arguments":{"title":"One"}}</tool_call><tool_call>{"name":"tasks_create","arguments":{"title":"Two"}}</tool_call>',
      );
      await controller.send('Добавь');
      expect(store.writes, isEmpty);
      expect(controller.state.messages.last.kind, AssistantMessageKind.error);
    },
  );

  test('malformed outputs never execute, failures remain visible', () async {
    backend = FakeAssistantBackend(reply: (_, _) => '{');
    await controller.send('Создай задачу');
    expect(store.writes, isEmpty);
    expect(controller.state.messages.last.kind, AssistantMessageKind.error);
    expect(controller.state.busy, isFalse);
    expect(backend.closes, 1);
  });

  test(
    'unknown tools and invalid arguments cannot write, rounds are bounded',
    () async {
      backend = FakeAssistantBackend(
        reply: (_, _) => call('shell_execute', {'command': 'anything'}),
      );
      await controller.send('Помоги');
      expect(store.writes, isEmpty);
      expect(backend.prompts.length, 5);
      expect(controller.state.messages.last.kind, AssistantMessageKind.error);
      expect(controller.state.messages.last.text, contains('предел'));
    },
  );

  test('cancellation prevents a late model reply from writing', () async {
    final entered = Completer<void>(), result = Completer<String>();
    backend = FakeAssistantBackend(
      reply: (_, _) {
        entered.complete();
        return result.future;
      },
    );
    final sending = controller.send('Создай задачу');
    await entered.future;
    final cancelling = controller.cancel();
    expect(controller.state.busy, isTrue);
    result.complete(call('tasks_create', {'title': 'Stale'}));
    await cancelling;
    await sending;
    expect(store.writes, isEmpty);
    expect(controller.state.busy, isFalse);
  });

  test('shutdown drains accepted writes and rejects stale callbacks', () async {
    store.entered = Completer<void>();
    store.writeGate = Completer<void>();
    backend = FakeAssistantBackend(
      reply: (_, _) => call('tasks_create', {'title': 'Принятая запись'}),
    );
    final sending = controller.send('Создай задачу');
    await store.entered!.future;
    var closed = false;
    final closing = controller.close().then((_) => closed = true);
    await Future<void>.delayed(Duration.zero);
    expect(closed, isFalse);
    await controller.send('Не выполнять');
    store.writeGate!.complete();
    await closing;
    await sending;
    expect(store.items.values.single.title, 'Принятая запись');
    expect(store.writes.length, 1);
  });

  test('settings are committed only on success and unload old model', () async {
    var fail = true;
    AssistantSettings? saved;
    await controller.close();
    controller = build(
      save: (value) async {
        if (fail) throw StateError('offline');
        saved = value;
      },
    );
    await controller.send('Привет');
    const changed = AssistantSettings(
      pythonExecutable: 'custom-python',
      modelDirectory: 'custom-model',
      device: 'CPU',
    );
    await controller.configure(changed);
    expect(controller.state.settings.device, 'NPU');
    fail = false;
    await controller.configure(changed);
    expect(saved, same(changed));
    expect(controller.state.settings, same(changed));
    expect(backend.closes, 1);
  });
}
