import 'dart:io';
import 'package:agent_bridge/local_assistant.dart';
import 'package:agent_bridge/task_tools.dart';
import 'package:test/test.dart';
import '../tasks/support/memory_tasks.dart';
import 'support/agent_harness.dart';

void main() {
  final model = Platform.environment['LIFE_OS_TEST_OPENVINO_MODEL'];
  final python = Platform.environment['ASSISTANT_TEST_PYTHON'];
  test(
    'real NPU model creates a task through the local assistant',
    () async {
      final tasks = MemoryTasks();
      final controller = AssistantController(
        now: () => DateTime(2026, 11, 8, 12),
        tools: TaskAgentTools(tasks: tasks, completion: Completion(tasks)),
        settings: AssistantSettings(
          pythonExecutable: python!,
          modelDirectory: model!,
          device: 'NPU',
        ),
        backendFactory: (settings) async => OpenVinoProcessBackend(
          settings: settings,
          workerSource: await File('tool/openvino/worker.py').readAsString(),
        ),
        saveSettings: (_) async {},
      );
      addTearDown(controller.close);
      await controller.send('Создай задачу с названием Купить молоко.');
      expect(
        tasks.items.values.map((task) => task.title),
        contains('Купить молоко'),
      );
      expect(
        controller.state.messages.any(
          (m) => m.kind == AssistantMessageKind.action,
        ),
        isTrue,
      );
      expect(controller.state.busy, isFalse);
      await controller.send(
        'Найди задачу Купить молоко и отметь её выполненной.',
      );
      expect(
        tasks.items.values.single.isCompleted,
        isTrue,
        reason: controller.state.messages.map((m) => m.text).join('\n'),
      );
      controller.clear();
      await controller.send(
        'Создай задачу с названием Читать книгу на завтра.',
      );
      final scheduled = tasks.items.values.singleWhere(
        (task) => task.title == 'Читать книгу',
      );
      expect(
        scheduled.startsAt,
        DateTime(2026, 11, 9),
        reason: controller.state.messages.map((m) => m.text).join('\n'),
      );
      expect(scheduled.dueDate, isNull);
      expect(scheduled.endsAt, isNull);
      controller.clear();
      await controller.send('Создай задачу с названием Отчёт, дедлайн завтра.');
      final deadline = tasks.items.values.singleWhere(
        (task) => task.title == 'Отчёт',
      );
      expect(
        deadline.dueDate,
        DateTime(2026, 11, 9),
        reason: controller.state.messages.map((m) => m.text).join('\n'),
      );
      expect(deadline.startsAt, isNull);
      controller.clear();
      await controller.send('Покажи все задачи');
      expect(
        controller.state.messages.any(
          (m) =>
              m.kind == AssistantMessageKind.action &&
              m.text.startsWith('Найдено задач:'),
        ),
        isTrue,
        reason: controller.state.messages.map((m) => m.text).join('\n'),
      );
    },
    skip: model == null || python == null
        ? 'Set LIFE_OS_TEST_OPENVINO_MODEL and ASSISTANT_TEST_PYTHON for hardware smoke test'
        : false,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}
