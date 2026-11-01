import 'dart:async';
import 'package:habits_api/habits_api.dart';

class MemoryHabits implements HabitsApi {
  final habits = <String, Habit>{};
  final entries = <(String, String), HabitEntry>{};
  final habitListeners = <MultiStreamController<List<Habit>>>{};
  final entryListeners = <MultiStreamController<List<HabitEntry>>>{};
  final writes = <HabitEntryStatus>[];
  Completer<void>? writeGate;
  Completer<void>? entered;
  Completer<void>? cancelGate;
  bool failWrite = false;
  bool failWatch = false;
  bool failCancel = false;
  int watches = 0;

  @override
  Stream<List<Habit>> watchActiveHabits() {
    if (failWatch) throw StateError('Source failed');
    return Stream.multi((listener) {
      watches++;
      habitListeners.add(listener);
      listener.add(habits.values.where((habit) => !habit.isArchived).toList());
      listener.onCancel = () async {
        await cancelGate?.future;
        habitListeners.remove(listener);
        if (failCancel) throw StateError('Cancellation failed');
      };
    });
  }

  @override
  Stream<List<HabitEntry>> watchAllEntries() => Stream.multi((listener) {
    entryListeners.add(listener);
    listener.add(entries.values.toList());
    listener.onCancel = () => entryListeners.remove(listener);
  });

  void emit() {
    for (final listener in habitListeners) {
      listener.add(habits.values.where((habit) => !habit.isArchived).toList());
    }
    for (final listener in entryListeners) {
      listener.add(entries.values.toList());
    }
  }

  Future<void> _write(void Function() action) async {
    if (entered case final signal? when !signal.isCompleted) signal.complete();
    await writeGate?.future;
    if (failWrite) {
      failWrite = false;
      throw StateError('Write failed');
    }
    action();
    emit();
  }

  @override
  Future<List<Habit>> getAllHabits() async =>
      habits.values.where((habit) => !habit.isArchived).toList();
  @override
  Future<Habit?> getHabitById(String id) async => habits[id];
  @override
  Future<void> addHabit(Habit habit) => _write(() => habits[habit.id] = habit);
  @override
  Future<void> updateHabit(Habit habit) =>
      _write(() => habits[habit.id] = habit);
  @override
  Future<void> archiveHabit(String id) =>
      _write(() => habits[id] = habits[id]!.copyWith(isArchived: true));
  @override
  Future<void> deleteHabit(String id) => _write(() {
    habits.remove(id);
    entries.removeWhere((key, _) => key.$1 == id);
  });
  @override
  Future<void> setEntryStatus(
    String habitId,
    String dateKey,
    HabitEntryStatus status,
  ) {
    writes.add(status);
    return _write(() {
      entries[(habitId, dateKey)] = HabitEntry.create(
        habitId: habitId,
        dateKey: dateKey,
        status: status,
      );
    });
  }
}
