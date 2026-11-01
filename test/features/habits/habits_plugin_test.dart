import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_plugin.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import '../../support/test_app.dart';
import 'support/memory_habits.dart';

class HabitsHarness {
  final store = MemoryHabits();
  final ui = PluginUiRegistry();
  final opened = <HabitsViewModel>[];
  final callbacks = <VoidCallback>[];
  late final module = HabitsPlugin(
    habits: store,
    ui: ui,
    slots: const HabitsUiSlots(
      today: 'today',
      toolbar: 'tools',
      calendar: 'overlay',
    ),
    visuals: HabitsUiBindings(
      today: (_, _, _, open) {
        callbacks.add(open);
        return TextButton(onPressed: open, child: const Text('Open calendar'));
      },
      calendar: (_, _, close) =>
          TextButton(onPressed: close, child: const Text('Calendar')),
      showAll: (_, model) async => opened.add(model),
    ),
  );
  late final host = PluginHost(module.plugins);
  Future<void> dispose() async {
    try {
      await host.stop();
    } finally {
      ui.dispose();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'standalone plugin owns both subscriptions and registers supplied slots',
    () async {
      final h = HabitsHarness();
      addTearDown(h.dispose);
      expect(() => h.module.viewModel, throwsStateError);
      await h.host.start();
      final first = h.module.viewModel;
      first.initialize();
      await first.state.firstWhere((state) => state is HabitsLoaded);
      expect(h.store.watches, 1);
      expect(h.store.entryListeners, hasLength(1));
      expect(h.ui.panelsFor('today').single.id, 'habits.today');
      expect(h.ui.panelsFor('tools').single.id, 'habits.toolbar');
      expect(h.ui.panelsFor('overlay').single.id, 'habits.calendar');
      await h.host.stop();
      expect(h.store.habitListeners, isEmpty);
      expect(h.store.entryListeners, isEmpty);
      expect(h.ui.panelsFor('today'), isEmpty);
      await h.host.start();
      expect(h.module.viewModel, isNot(same(first)));
      expect(h.store.watches, 2);
      await expectLater(
        first.saveDraft(Habit.create(title: 'Old', type: const MorningHabit())),
        throwsStateError,
      );
    },
  );

  test('stop removes panels before awaiting accepted writes', () async {
    final h = HabitsHarness();
    addTearDown(h.dispose);
    await h.host.start();
    final model = h.module.viewModel;
    await model.state.firstWhere((state) => state is HabitsLoaded);
    final habit = Habit.create(title: 'Read', type: const MorningHabit());
    await model.saveDraft(habit);
    h.store.writeGate = Completer<void>();
    h.store.entered = Completer<void>();
    final write = model.toggleHabit(habit, model.selectedDate);
    await h.store.entered!.future;
    final removed = Completer<void>();
    h.ui.addListener(() {
      if (h.ui.panelsFor('today').isEmpty && !removed.isCompleted) {
        removed.complete();
      }
    });
    var stopped = false;
    final stop = h.host.stop().then((_) => stopped = true);
    await removed.future;
    expect(stopped, isFalse);
    await expectLater(
      model.skipHabit(habit, model.selectedDate),
      throwsStateError,
    );
    h.store.writeGate!.complete();
    await write;
    await stop;
    expect(h.store.entries.values.single.status, HabitEntryStatus.completed);
  });

  test(
    'registration failure releases subscriptions and preserves existing owner',
    () async {
      final h = HabitsHarness();
      addTearDown(h.dispose);
      h.ui.register(
        'existing',
        panels: [
          PluginPanelContribution(
            id: 'habits.today',
            slot: 'today',
            builder: (_, _) => const Text('Existing'),
          ),
        ],
      );
      await expectLater(
        h.host.start(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.store.habitListeners, isEmpty);
      expect(h.store.entryListeners, isEmpty);
      expect(h.ui.panelsFor('today'), hasLength(1));
      expect(() => h.module.viewModel, throwsStateError);
    },
  );

  test('failed startup can be retried with a fresh model', () async {
    final h = HabitsHarness();
    addTearDown(h.dispose);
    h.store.failWatch = true;
    await expectLater(h.host.start(), throwsA(isA<PluginLifecycleException>()));
    expect(() => h.module.viewModel, throwsStateError);
    expect(h.ui.panelsFor('today'), isEmpty);
    h.store.failWatch = false;
    await h.host.start();
    await h.module.viewModel.state.firstWhere((state) => state is HabitsLoaded);
    expect(h.store.habitListeners, hasLength(1));
    expect(h.store.entryListeners, hasLength(1));
  });

  test(
    'cancellation failure still closes model and unregisters all panels',
    () async {
      final h = HabitsHarness();
      addTearDown(h.dispose);
      await h.host.start();
      final model = h.module.viewModel;
      await model.state.firstWhere((state) => state is HabitsLoaded);
      h.store.failCancel = true;
      await expectLater(
        h.host.stop(),
        throwsA(isA<PluginLifecycleException>()),
      );
      expect(h.store.habitListeners, isEmpty);
      expect(h.store.entryListeners, isEmpty);
      expect(h.ui.panelsFor('today'), isEmpty);
      expect(h.ui.panelsFor('tools'), isEmpty);
      expect(h.ui.panelsFor('overlay'), isEmpty);
      expect(() => h.module.viewModel, throwsStateError);
      await model.state.drain<void>();
    },
  );

  testWidgets(
    'calendar and toolbar use supplied views and stale callbacks stay inactive',
    (tester) async {
      final h = HabitsHarness();
      await h.host.start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                PluginPanelSlot(registry: h.ui, slot: 'today'),
                PluginPanelSlot(registry: h.ui, slot: 'tools'),
                PluginPanelSlot(registry: h.ui, slot: 'overlay'),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open calendar'));
      await tester.pump();
      expect(find.text('Calendar'), findsOneWidget);
      await tester.tap(find.byTooltip('Habits'));
      expect(h.opened.single, same(h.module.viewModel));
      final oldOpen = h.callbacks.first;
      final oldToolbar = tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) => widget is IconButton && widget.tooltip == 'Habits',
            ),
          )
          .onPressed!;
      await tester.runAsync(h.host.stop);
      await tester.pump();
      expect(find.text('Calendar'), findsNothing);
      await tester.runAsync(h.host.start);
      await tester.pump();
      oldOpen();
      oldToolbar();
      await tester.pump();
      expect(find.text('Calendar'), findsNothing);
      expect(h.opened, hasLength(1));
      await tester.tap(find.text('Open calendar'));
      await tester.pump();
      expect(find.text('Calendar'), findsOneWidget);
      await tester.tap(find.text('Calendar'));
      await tester.pump();
      expect(find.text('Calendar'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(h.dispose);
    },
  );

  test(
    'application restart recreates habits state and retains SQLite data',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final first = app.habitsViewModel;
      final habit = Habit.create(
        title: 'Evening read',
        type: const TimeHabit(time: HabitTime(hour: 21, minute: 30)),
        reminderTime: const HabitTime(hour: 21, minute: 0),
      );
      await first.saveDraft(habit);
      await first.toggleHabit(habit, first.selectedDate);
      await app.plugins.stop();
      expect(() => app.habitsViewModel, throwsStateError);
      await app.plugins.start();
      final second = app.habitsViewModel;
      final state =
          await second.state.firstWhere((state) => state is HabitsLoaded)
              as HabitsLoaded;
      expect(second, isNot(same(first)));
      expect(state.habits.single.habit.type, habit.type);
      expect(state.habits.single.habit.reminderTime, habit.reminderTime);
      expect(state.habits.single.isCompleted, isTrue);
      expect(app.navigation.selectedId, 'pulse');
      expect(app.ui.panelsFor('pulse.center').single.id, 'habits.today');
    },
  );
}
