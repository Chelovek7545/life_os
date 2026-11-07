import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:habits_api/habits_api.dart';
import 'support/today_harness.dart';

void main() {
  testWidgets(
    'Today reflows at narrow widths and larger text without changing panel filters',
    (tester) async {
      final h = TodayHarness()..seed();
      await h.host.start();
      final navigation = PluginNavigationController(h.ui);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final width in [1280.0, 760.0, 360.0]) {
        tester.view.physicalSize = Size(width, 1100);
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(useMaterial3: true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(width == 360 ? 1.6 : 1)),
              child: child!,
            ),
            home: Scaffold(body: PluginScreenDeck(navigation: navigation)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(
              width >= 900 ? 'today-wide-layout' : 'today-narrow-layout',
            ),
          ),
          findsOneWidget,
        );
        final tasks = tester.getTopLeft(
          find.byKey(const ValueKey('today-tasks-slot')),
        );
        final habits = tester.getTopLeft(
          find.byKey(const ValueKey('today-habits-slot')),
        );
        expect(
          width >= 900 ? habits.dx > tasks.dx : habits.dy > tasks.dy,
          isTrue,
        );
        h.projectsPanel.viewModel.setOnlyForDate(true);
        await tester.pumpAndSettle();
        expect(h.projectsPanel.viewModel.onlyForDate, isTrue);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      await pumpPluginLifecycle(tester, h.dispose);
    },
  );

  testWidgets(
    'task panel retries failed writes and opens the existing task editor',
    (tester) async {
      final h = TodayHarness()..seed();
      await h.host.start();
      Task? opened;
      h.ui.register(
        'target',
        screens: [
          PluginScreenContribution(
            id: 'tasks',
            label: 'Tasks',
            icon: Icons.list,
            order: 10,
            onOpen: (argument) => opened = argument as Task,
            builder: (_, _) => const Text('Редактор задачи'),
          ),
        ],
      );
      final navigation = PluginNavigationController(h.ui);
      await tester.pumpWidget(todayApp(navigation));
      await tester.pumpAndSettle();
      final task = h.tasks.items.values.first;
      final toggle = find.byKey(ValueKey('task-toggle-${task.id}'));
      h.tasks.failWrite = true;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось обновить задачу. Попробуйте ещё раз.'),
        findsOneWidget,
      );
      expect(h.tasks.items[task.id]!.isCompleted, isFalse);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(h.tasks.items[task.id]!.isCompleted, isTrue);
      expect(find.text(task.title), findsNothing);
      await tester.tap(find.text('Все'));
      await tester.pumpAndSettle();
      expect(find.text(task.title), findsOneWidget);
      await tester.tap(find.text(task.title));
      await tester.pumpAndSettle();
      expect(opened?.id, task.id);
      expect(navigation.selectedId, 'today');
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      await pumpPluginLifecycle(tester, h.dispose);
    },
  );

  testWidgets(
    'habit actions use the selected day and keep other days unchanged',
    (tester) async {
      final h = TodayHarness()..seed();
      await h.host.start();
      final navigation = PluginNavigationController(h.ui);
      tester.view.physicalSize = const Size(1280, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(todayApp(navigation));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('today-next-day')));
      await tester.pumpAndSettle();
      expect(find.text('Задача на завтра'), findsOneWidget);
      expect(find.text('Задача на сегодня'), findsNothing);
      final habit = h.habits.habits.values.single;
      await tester.tap(find.byKey(ValueKey('habit-toggle-${habit.id}')));
      await tester.pumpAndSettle();
      expect(
        h.habits.entries[(habit.id, '2026-11-03')]!.status,
        HabitEntryStatus.completed,
      );
      await tester.tap(find.byKey(ValueKey('habit-skip-${habit.id}')));
      await tester.pumpAndSettle();
      expect(
        h.habits.entries[(habit.id, '2026-11-03')]!.status,
        HabitEntryStatus.skipped,
      );
      await tester.tap(find.byKey(const ValueKey('today-previous-day')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Checkbox>(find.byKey(ValueKey('habit-toggle-${habit.id}')))
            .value,
        isFalse,
      );
      expect(h.habits.entries.containsKey((habit.id, '2026-11-02')), isFalse);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      await pumpPluginLifecycle(tester, h.dispose);
    },
  );

  testWidgets(
    'old screen date callbacks cannot change a restarted Today instance',
    (tester) async {
      final h = TodayHarness()..seed();
      await h.host.start();
      final navigation = PluginNavigationController(h.ui);
      await tester.pumpWidget(todayApp(navigation));
      await tester.pumpAndSettle();
      final previous = tester
          .widget<IconButton>(find.byKey(const ValueKey('today-previous-day')))
          .onPressed!;
      final oldContext = navigation.contextFor(h.ui.screens.single);
      await pumpPluginLifecycle(tester, h.host.stop);
      await pumpPluginLifecycle(tester, h.host.start);
      previous();
      await tester.pumpAndSettle();
      expect(h.module.selectedDate, h.day);
      expect(oldContext.openScreen('today'), isFalse);
      await tester.pumpWidget(const SizedBox());
      navigation.dispose();
      await pumpPluginLifecycle(tester, h.dispose);
    },
  );
}
