import 'package:agent_bridge/local_assistant.dart';
import 'package:agent_bridge/task_tools.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_theme.dart';
import 'package:life_os/features/assistant/presentation/assistant_overlay.dart';
import '../tasks/support/memory_tasks.dart';
import 'support/agent_harness.dart';
import 'support/assistant_fake.dart';

void main() {
  late AssistantController controller;
  late FakeAssistantBackend backend;
  setUp(() {
    final tasks = MemoryTasks();
    backend = FakeAssistantBackend();
    controller = AssistantController(
      tools: TaskAgentTools(tasks: tasks, completion: Completion(tasks)),
      backendFactory: (_) async => backend,
      settings: const AssistantSettings(),
      saveSettings: (_) async {},
    );
  });
  void chatTest(String name, Future<void> Function(WidgetTester) body) {
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        var closed = false;
        final closing = controller.close().then((_) => closed = true);
        for (var i = 0; i < 100 && !closed; i++) {
          await tester.pump(const Duration(milliseconds: 10));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 1)),
          );
        }
        expect(closed, isTrue, reason: 'Assistant resources must close');
        await closing;
      }
    });
  }

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onTap,
    double textScale = 1,
  }) async => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: TextButton(
                key: const ValueKey('underlay'),
                onPressed: onTap ?? () {},
                child: const Text('Основной экран'),
              ),
            ),
            AssistantOverlay(controller: controller),
          ],
        ),
      ),
    ),
  );
  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('assistant.toggle')));
    await tester.pumpAndSettle();
  }

  chatTest(
    'corner button leaves page interactive, expands and keeps draft and messages',
    (tester) async {
      var taps = 0;
      await pump(tester, onTap: () => taps++);
      await tester.tap(find.byKey(const ValueKey('underlay')));
      expect(taps, 1);
      expect(backend.starts, 0);
      await open(tester);
      await tester.enterText(
        find.byKey(const ValueKey('assistant.input')),
        'Привет',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assistant.send')));
      await tester.pumpAndSettle();
      expect(find.text('Локальный ответ'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('assistant.input')),
        'Черновик',
      );
      await tester.tap(find.byKey(const ValueKey('assistant.minimize')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assistant.panel')), findsNothing);
      await open(tester);
      expect(find.text('Локальный ответ'), findsOneWidget);
      expect(find.text('Черновик'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  chatTest(
    'Enter sends once, Shift+Enter creates a newline and Escape minimizes',
    (tester) async {
      await pump(tester);
      await open(tester);
      final input = find.byKey(const ValueKey('assistant.input'));
      await tester.enterText(input, 'Вопрос');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(backend.prompts, isEmpty);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(backend.prompts.length, 1);
      await tester.tap(input);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assistant.toggle')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  chatTest('narrow window, enlarged text and keyboard leave composer usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await pump(tester, textScale: 1.4);
    await open(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('assistant.send')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('assistant.settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('assistant.save-settings')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('assistant.settings-scroll')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('assistant.save-settings')).hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  chatTest('settings save and new conversation reset memory', (tester) async {
    await pump(tester);
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('assistant.settings')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('assistant.python')),
      'C:/Python/python.exe',
    );
    await tester.enterText(
      find.byKey(const ValueKey('assistant.model')),
      'C:/Models/Qwen',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('assistant.save-settings')),
      120,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('assistant.settings-scroll')),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('assistant.save-settings')));
    await tester.pumpAndSettle();
    expect(controller.state.settings.modelDirectory, 'C:/Models/Qwen');
    await tester.enterText(
      find.byKey(const ValueKey('assistant.input')),
      'Привет',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('assistant.send')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('assistant.clear')));
    await tester.pumpAndSettle();
    expect(find.text('Локальный ответ'), findsNothing);
    expect(controller.state.messages, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
