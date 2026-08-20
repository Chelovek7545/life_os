import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/habits/data/habits_repository.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';

void main() {
  Future<HabitsLoaded> waitForLoaded(
    List<HabitsScreenState> states,
  ) async {
    while (true) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final last = states.isEmpty ? null : states.last;
      if (last is HabitsLoaded && last.habits.isNotEmpty) return last;
    }
  }

  Future<(HabitsViewModel, AppDatabase)> createVm() async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db));
    final weekday = DateTime.now().weekday;
    await repo.addHabit(
      Habit.create(
        title: 'Read',
        type: const MorningHabit(),
        schedule: HabitSchedule(daysOfWeek: [weekday]),
      ),
    );
    return (HabitsViewModel(repo), db);
  }

  test('toggleHabit updates state synchronously (optimistic)', () async {
    final (vm, db) = await createVm();
    final states = <HabitsScreenState>[];
    final sub = vm.state.listen(states.add);
    vm.initialize();
    final loaded = await waitForLoaded(states);
    final habit = loaded.habits.single.habit;
    expect(loaded.habits.single.isCompleted, isFalse);

    // Без единого await состояние уже должно быть обновлено.
    final future = vm.toggleHabit(habit, vm.selectedDate);
    debugPrint('DBG after toggle: entries=${states.length} '
        'completed=${(states.last as HabitsLoaded).habits.single.isCompleted}');
    future.catchError((Object e) {
      debugPrint('DBG future error: $e');
      return null;
    });
    expect(states.last, isA<HabitsLoaded>());
    await Future<void>.delayed(Duration.zero);
    debugPrint('DBG after zero delay: entries=${states.length} '
        'completed=${(states.last as HabitsLoaded).habits.single.isCompleted}');
    await future;
    debugPrint('DBG after await future: entries=${states.length} '
        'completed=${(states.last as HabitsLoaded).habits.single.isCompleted}');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    debugPrint('DBG after 30ms: entries=${states.length} '
        'completed=${(states.last as HabitsLoaded).habits.single.isCompleted}');

    // Повторный вызов возвращает в pending.
    final future2 = vm.toggleHabit(habit, vm.selectedDate);
    expect((states.last as HabitsLoaded).habits.single.isCompleted, isFalse);
    await future2;

    await sub.cancel();
    vm.dispose();
    await db.close();
  });

  test('skipHabit updates state synchronously and is toggleable back', () async {
    final (vm, db) = await createVm();
    final states = <HabitsScreenState>[];
    final sub = vm.state.listen(states.add);
    vm.initialize();
    final loaded = await waitForLoaded(states);
    final habit = loaded.habits.single.habit;

    final future = vm.skipHabit(habit, vm.selectedDate);
    expect((states.last as HabitsLoaded).habits.single.isSkipped, isTrue);
    await future;

    final future2 = vm.skipHabit(habit, vm.selectedDate);
    expect((states.last as HabitsLoaded).habits.single.isSkipped, isFalse);
    await future2;

    await sub.cancel();
    vm.dispose();
    await db.close();
  });
}
