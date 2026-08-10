import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_streak.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';

void main() {
  final calculator = HabitStreakCalculator();

  Habit habit({
    List<int> days = const [1, 2, 3, 4, 5, 6, 7],
    DateTime? createdAt,
  }) {
    return Habit(
      id: 'h1',
      title: 'Test',
      type: const MorningHabit(),
      schedule: HabitSchedule(daysOfWeek: days),
      createdAt: createdAt ?? DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  HabitEntry completed(String dateKey, {String habitId = 'h1'}) =>
      HabitEntry.create(
        habitId: habitId,
        dateKey: dateKey,
        status: HabitEntryStatus.completed,
      );

  Habit habit2() {
    return Habit(
      id: 'h2',
      title: 'Second',
      type: const LunchHabit(),
      schedule: const HabitSchedule(daysOfWeek: [1, 2, 3, 4, 5, 6, 7]),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  group('HabitStreakCalculator.current', () {
    test('empty entries -> zero', () {
      final result = calculator.calculate(
        habit: habit(),
        entries: const [],
        today: DateTime(2026, 8, 10),
      );
      expect(result.current, 0);
    });

    test('counts consecutive completed days including today', () {
      final entries = [
        completed('2026-08-08'),
        completed('2026-08-09'),
        completed('2026-08-10'),
      ];
      final result = calculator.calculate(
        habit: habit(),
        entries: entries,
        today: DateTime(2026, 8, 10),
      );
      expect(result.current, 3);
    });

    test('breaks on a missed scheduled day', () {
      final entries = [
        completed('2026-08-04'),
        completed('2026-08-05'),
        completed('2026-08-06'),
      ];
      final result = calculator.calculate(
        habit: habit(),
        entries: entries,
        today: DateTime(2026, 8, 10),
      );
      expect(result.current, 0);
    });

    test('unscheduled days do not break the streak', () {
      final habitMwf = habit(days: const [1, 3, 5]);
      final entries = [
        completed('2026-07-31'), // Friday
        completed('2026-08-03'), // Monday
      ];
      final result = calculator.calculate(
        habit: habitMwf,
        entries: entries,
        today: DateTime(2026, 8, 4), // Tuesday, not scheduled
      );
      expect(result.current, 2);
    });

    test('skipped day does not break the streak', () {
      final entries = [
        completed('2026-08-08'),
        HabitEntry.create(
          habitId: 'h1',
          dateKey: '2026-08-09',
          status: HabitEntryStatus.skipped,
        ),
        completed('2026-08-10'),
      ];
      final result = calculator.calculate(
        habit: habit(),
        entries: entries,
        today: DateTime(2026, 8, 10),
      );
      expect(result.current, 2);
    });

    test('today not yet completed keeps the running streak', () {
      final entries = [
        completed('2026-08-08'),
        completed('2026-08-09'),
      ];
      final result = calculator.calculate(
        habit: habit(),
        entries: entries,
        today: DateTime(2026, 8, 10),
      );
      expect(result.current, 2);
    });

    test('ignores entries of other habits on the same days', () {
      // h2 выполнен сегодня и вчера; у h1 сегодня записи нет.
      // Каждая привычка должна считать свою серию независимо.
      final entries = [
        completed('2026-08-08'), // h1
        completed('2026-08-09'), // h1
        completed('2026-08-09', habitId: 'h2'),
        completed('2026-08-10', habitId: 'h2'),
      ];
      final resultH1 = calculator.calculate(
        habit: habit(),
        entries: entries,
        today: DateTime(2026, 8, 10),
      );
      final resultH2 = calculator.calculate(
        habit: habit2(),
        entries: entries,
        today: DateTime(2026, 8, 10),
      );
      expect(resultH1.current, 2);
      expect(resultH2.current, 2);
    });
  });

  group('HabitStreakCalculator.best', () {
    test('tracks the longest run', () {
      final entries = [
        completed('2026-08-01'),
        completed('2026-08-02'),
        // gap on 08-03
        completed('2026-08-04'),
        completed('2026-08-05'),
        completed('2026-08-06'),
      ];
      final result = calculator.calculate(
        habit: habit(createdAt: DateTime(2026, 8, 1)),
        entries: entries,
        today: DateTime(2026, 8, 10),
      );
      expect(result.best, 3);
    });
  });
}
