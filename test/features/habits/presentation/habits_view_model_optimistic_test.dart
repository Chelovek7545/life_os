import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/data/habits_repository.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_logic.dart';

class PendingHabitsRepository extends Fake implements HabitsRepository {
  PendingHabitsRepository(this.habit);
  final Habit habit;
  Completer<void> write = Completer<void>();
  @override
  Stream<List<Habit>> watchActiveHabits() => Stream.value([habit]);
  @override
  Stream<List<HabitEntry>> watchAllEntries() => Stream.value([]);
  @override
  Future<void> setEntryStatus(
    String habitId,
    String dateKey,
    HabitEntryStatus status,
  ) => write.future;
}

void main() {
  for (final skip in [false, true]) {
    test(
      'optimistic ' +
          (skip ? 'skip' : 'toggle') +
          ' emits before storage completes and can be undone',
      () async {
        final habit = Habit.create(title: 'Read', type: const MorningHabit());
        final repository = PendingHabitsRepository(habit);
        final vm = HabitsViewModel(repository);
        vm.initialize();
        await vm.state.firstWhere((state) => state is HabitsLoaded);
        final changing = skip
            ? vm.skipHabit(habit, vm.selectedDate)
            : vm.toggleHabit(habit, vm.selectedDate);
        final optimistic = await vm.state.first as HabitsLoaded;
        expect(
          skip
              ? optimistic.habits.single.isSkipped
              : optimistic.habits.single.isCompleted,
          isTrue,
        );
        expect(repository.write.isCompleted, isFalse);
        repository.write.complete();
        await changing;
        repository.write = Completer<void>();
        final undoing = skip
            ? vm.skipHabit(habit, vm.selectedDate)
            : vm.toggleHabit(habit, vm.selectedDate);
        final undone = await vm.state.first as HabitsLoaded;
        expect(
          skip
              ? undone.habits.single.isSkipped
              : undone.habits.single.isCompleted,
          isFalse,
        );
        repository.write.complete();
        await undoing;
        await vm.dispose();
      },
    );
  }
}
