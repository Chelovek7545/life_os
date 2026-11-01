import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:drift/native.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/ui/telegram_bot_toggle_button.dart';
import 'support/test_app.dart';

void main() {
  for (final telegram in [false, true]) {
    testWidgets(
      'application runs with Telegram enabled: ' + telegram.toString(),
      (tester) async {
        final container = (await tester.runAsync(
          () => createTestApp(enableTelegram: telegram),
        ))!;
        await tester.pumpWidget(MyApp(diContainer: container));
        await tester.pump();
        expect(find.byType(MaterialApp), findsOneWidget);
        expect(
          find.byType(TelegramBotToggleButton),
          telegram ? findsWidgets : findsNothing,
        );
        expect(container.plugins.states.containsKey('telegram'), telegram);
        await disposeTestApp(tester, container);
      },
    );
  }
  test(
    'failed initialization still allows complete resource cleanup',
    () async {
      final db = _TrackingDatabase();
      final container = DependencyContainer(
        database: db,
        enableTelegram: false,
        additionalPlugins: [_FailingPlugin(failStart: true)],
      );
      await expectLater(
        container.init(),
        throwsA(isA<PluginLifecycleException>()),
      );
      await container.dispose();
      expect(db.wasClosed, isTrue);
      expect(container.init, throwsStateError);
    },
  );
  test('a failed plugin shutdown still closes the database', () async {
    final db = _TrackingDatabase();
    final container = DependencyContainer(
      database: db,
      enableTelegram: false,
      additionalPlugins: [_FailingPlugin(failStart: false)],
    );
    await container.init();
    await expectLater(
      container.dispose(),
      throwsA(isA<PluginLifecycleException>()),
    );
    expect(db.wasClosed, isTrue);
  });
  test(
    'containers have independent dependencies and idempotent shutdown',
    () async {
      final first = await createTestApp();
      final second = await createTestApp();
      expect(identical(first, second), isFalse);
      expect(identical(first.tasksRepository, second.tasksRepository), isFalse);
      await first.dispose();
      await first.dispose();
      expect(await second.tasksRepository.getAllTasks(), isEmpty);
      await second.dispose();
    },
  );
}

class _FailingPlugin implements AppPlugin {
  _FailingPlugin({required this.failStart});
  final bool failStart;
  @override
  String get id => 'failure-test';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    if (failStart) throw StateError('startup failed');
  }

  @override
  Future<void> stop() async {
    if (!failStart) throw StateError('shutdown failed');
  }
}

class _TrackingDatabase extends AppDatabase {
  _TrackingDatabase() : super(NativeDatabase.memory());
  bool wasClosed = false;
  @override
  Future<void> close() async {
    wasClosed = true;
    await super.close();
  }
}
