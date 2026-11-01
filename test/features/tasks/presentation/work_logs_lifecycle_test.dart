import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tasks_plugin/tasks_plugin.dart';
import 'package:life_os/features/tasks/presentation/components/work_logs_section.dart';
import '../support/memory_tasks.dart';

void main() {
  test(
    'work log model cancels its subscription and new logs have unique IDs',
    () async {
      final store = MemoryWorkLogs();
      final session = WorkLogsSession(store);
      final model = WorkLogsViewModel(session, 'task');
      await Future<void>.delayed(Duration.zero);
      expect(store.listeners, hasLength(1));
      await Future.wait([
        model.addWorkLog(description: 'First'),
        model.addWorkLog(description: 'Second'),
      ]);
      expect(store.items, hasLength(2));
      await Future<void>.delayed(Duration.zero);
      expect(() => model.workLogs.clear(), throwsUnsupportedError);
      model.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(store.listeners, isEmpty);
      await expectLater(
        model.addWorkLog(description: 'Stale'),
        throwsStateError,
      );
      await session.dispose();
    },
  );

  testWidgets(
    'work log editor waits for storage and allows retry after failure',
    (tester) async {
      final store = MemoryWorkLogs();
      final session = WorkLogsSession(store);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkLogsSection(taskId: 'task', repository: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Добавить ворклог'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Saved step');
      store.writeGate = Completer<void>();
      await tester.tap(find.text('Сохранить'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Сохранить'),
            )
            .onPressed,
        isNull,
      );
      store.writeGate!.completeError(StateError('Disk unavailable'));
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось сохранить запись. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      expect(store.items, isEmpty);
      store.writeGate = null;
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(store.items.values.single.description, 'Saved step');
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(session.dispose);
      expect(store.listeners, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'an open editor cannot write into a different task after switching',
    (tester) async {
      final store = MemoryWorkLogs();
      final session = WorkLogsSession(store);
      Widget page(String id) => MaterialApp(
        home: Scaffold(
          body: WorkLogsSection(taskId: id, repository: session),
        ),
      );
      await tester.pumpWidget(page('old-task'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Добавить ворклог'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Old draft');
      await tester.pumpWidget(page('new-task'));
      await tester.pumpAndSettle();
      expect(store.listeners.values.toList(), ['new-task']);
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(store.items, isEmpty);
      expect(
        find.text('Не удалось сохранить запись. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(session.dispose);
      expect(store.listeners, isEmpty);
    },
  );
}
