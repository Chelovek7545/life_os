import 'dart:async';
import 'package:test/test.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_logic.dart';
import '../support/memory_habits.dart';

Future<HabitsLoaded> loaded(HabitsViewModel model) async =>
    await model.state.firstWhere((state) => state is HabitsLoaded)
        as HabitsLoaded;

void main() {
  test('public time and model contracts run without Flutter', () {
    final habit = Habit.create(
      title: 'Read',
      type: const TimeHabit(time: HabitTime(hour: 21, minute: 5)),
      reminderTime: const HabitTime(hour: 21, minute: 0),
    );
    expect(habit.type, habitTypeFromStorage(HabitTypeKind.time, time: '21:05'));
    expect(formatStoredTime(habit.reminderTime!), '21:00');
    expect(habit.copyWith(clearReminderTime: true).reminderTime, isNull);
    expect(HabitTypeKind.values.map((value) => value.name), [
      'morning',
      'lunch',
      'evening',
      'time',
    ]);
    expect(HabitEntryStatus.values.map((value) => value.name), [
      'pending',
      'completed',
      'skipped',
    ]);
  });

  test('schedule copies its input and exposes immutable days', () {
    final days = [1, 3, 5];
    final schedule = HabitSchedule(daysOfWeek: days);
    days.clear();
    expect(schedule.daysOfWeek, [1, 3, 5]);
    expect(() => schedule.daysOfWeek.add(7), throwsUnsupportedError);
    expect(encodeDaysOfWeek(schedule.daysOfWeek), 42);
  });

  late MemoryHabits store;
  late HabitsViewModel model;
  late Habit habit;
  setUp(() {
    store = MemoryHabits();
    habit = Habit.create(title: 'Read', type: const MorningHabit());
    store.habits[habit.id] = habit;
    model = HabitsViewModel(store)..initialize();
  });
  tearDown(() async => model.dispose());

  test(
    'initialization is idempotent and snapshots cannot be mutated',
    () async {
      model.initialize();
      final snapshot = await loaded(model);
      expect(store.watches, 1);
      expect(store.entryListeners, hasLength(1));
      expect(() => snapshot.habits.clear(), throwsUnsupportedError);
    },
  );

  test('source notifications preserve a pending optimistic mark', () async {
    await loaded(model);
    store.writeGate = Completer<void>();
    final write = model.toggleHabit(habit, model.selectedDate);
    expect((await loaded(model)).habits.single.isCompleted, isTrue);
    store.emit();
    await Future<void>.delayed(Duration.zero);
    expect((await loaded(model)).habits.single.isCompleted, isTrue);
    store.writeGate!.complete();
    await write;
  });

  test(
    'rapid toggles serialize while the latest optimistic state stays visible',
    () async {
      await loaded(model);
      store.writeGate = Completer<void>();
      store.entered = Completer<void>();
      final first = model.toggleHabit(habit, model.selectedDate);
      final second = model.toggleHabit(habit, model.selectedDate);
      await store.entered!.future;
      expect(store.writes, [HabitEntryStatus.completed]);
      expect((await loaded(model)).habits.single.isCompleted, isFalse);
      store.writeGate!.complete();
      await Future.wait([first, second]);
      expect(store.writes, [
        HabitEntryStatus.completed,
        HabitEntryStatus.pending,
      ]);
      expect(store.entries.values.single.status, HabitEntryStatus.pending);
    },
  );

  test(
    'failed earlier mark does not erase a later skip and queue recovers',
    () async {
      await loaded(model);
      store.writeGate = Completer<void>();
      store.failWrite = true;
      final first = model.toggleHabit(habit, model.selectedDate);
      final failed = expectLater(first, throwsStateError);
      final second = model.skipHabit(habit, model.selectedDate);
      expect((await loaded(model)).habits.single.isSkipped, isTrue);
      store.writeGate!.complete();
      await failed;
      await second;
      expect((await loaded(model)).habits.single.isSkipped, isTrue);
      expect(store.entries.values.single.status, HabitEntryStatus.skipped);
    },
  );

  test('failed undo restores the last confirmed mark', () async {
    await loaded(model);
    await model.toggleHabit(habit, model.selectedDate);
    store.failWrite = true;
    await expectLater(
      model.toggleHabit(habit, model.selectedDate),
      throwsStateError,
    );
    expect((await loaded(model)).habits.single.isCompleted, isTrue);
    expect(model.completedDateKeysOf(habit.id), {
      formatDateKey(model.selectedDate),
    });
  });

  test('failed save keeps draft available for retry', () async {
    await loaded(model);
    model.startEditing(habit);
    store.failWrite = true;
    await expectLater(
      model.saveDraft(habit.copyWith(title: 'Changed')),
      throwsStateError,
    );
    expect(model.editingHabit, same(habit));
    expect(model.isFormVisible, isTrue);
    await model.saveDraft(habit.copyWith(title: 'Changed'));
    expect(store.habits[habit.id]!.title, 'Changed');
    expect(model.isFormVisible, isFalse);
  });

  test(
    'dispose drains accepted writes, rejects new work and waits for cancellation',
    () async {
      await loaded(model);
      store.writeGate = Completer<void>();
      store.cancelGate = Completer<void>();
      store.entered = Completer<void>();
      final write = model.toggleHabit(habit, model.selectedDate);
      await store.entered!.future;
      var closed = false;
      final closing = model.dispose().then((_) => closed = true);
      await expectLater(
        model.skipHabit(habit, model.selectedDate),
        throwsStateError,
      );
      expect(closed, isFalse);
      store.writeGate!.complete();
      await write;
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      store.cancelGate!.complete();
      await closing;
      expect(store.entries.values.single.status, HabitEntryStatus.completed);
      expect(store.habitListeners, isEmpty);
      expect(store.entryListeners, isEmpty);
      expect(model.initialize, throwsStateError);
    },
  );

  test('source errors are shown and a later snapshot restores data', () async {
    await loaded(model);
    for (final listener in store.habitListeners) {
      listener.addError(StateError('Source interrupted'));
    }
    expect(
      await model.state.firstWhere((state) => state is HabitsError),
      isA<HabitsError>(),
    );
    store.emit();
    expect((await loaded(model)).habits.single.habit.id, habit.id);
  });
}
