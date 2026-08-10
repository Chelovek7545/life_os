import 'dart:math';
import 'habit_entry_model.dart';
import 'habit_model.dart';

/// Текущая и лучшая серия привычки.
class HabitStreak {
  const HabitStreak({this.current = 0, this.best = 0});

  final int current;
  final int best;

  bool get hasCurrent => current > 0;
}

/// Считает серии (streak) привычки на основе записей.
///
/// Правила:
/// - учитываются только запланированные дни;
/// - осознанный пропуск (skipped) не ломает серию;
/// - незапланированный день не влияет на серию;
/// - незакрытый сегодняшний день не считается разрывом.
class HabitStreakCalculator {
  const HabitStreakCalculator();

  HabitStreak calculate({
    required Habit habit,
    required List<HabitEntry> entries,
    DateTime? today,
  }) {
    final now = today ?? DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);

    final entriesByKey = <String, HabitEntry>{
      for (final e in entries)
        if (e.habitId == habit.id) e.dateKey: e,
    };

    return HabitStreak(
      current: _currentStreak(
        habit,
        entriesByKey,
        todayDay,
      ),
      best: _bestStreak(habit, entriesByKey, todayDay),
    );
  }

  int _currentStreak(
    Habit habit,
    Map<String, HabitEntry> entries,
    DateTime today,
  ) {
    var streak = 0;
    var day = today;

    for (var guard = 0; guard < 3650; guard++) {
      if (day.isBefore(DateTime(habit.createdAt.year, habit.createdAt.month,
          habit.createdAt.day))) {
        break;
      }

      final isScheduled = habit.schedule.isScheduledOn(day);
      final entry = entries[formatDateKey(day)];

      if (entry != null && entry.status == HabitEntryStatus.completed) {
        streak++;
      } else if (isScheduled) {
        if (entry != null && entry.status == HabitEntryStatus.skipped) {
          // осознанный пропуск не ломает серию
        } else if (day.isBefore(today)) {
          // запланированный день в прошлом без выполнения — разрыв
          break;
        } else {
          // сегодня ещё не выполнено — серия просто ещё не продлена
        }
      }

      day = day.subtract(const Duration(days: 1));
    }

    return streak;
  }

  int _bestStreak(
    Habit habit,
    Map<String, HabitEntry> entries,
    DateTime today,
  ) {
    var best = 0;
    var run = 0;

    final start = DateTime(
      habit.createdAt.year,
      habit.createdAt.month,
      habit.createdAt.day,
    );
    for (var day = start; !day.isAfter(today); day =
        day.add(const Duration(days: 1))) {
      if (!habit.schedule.isScheduledOn(day)) continue;

      final entry = entries[formatDateKey(day)];
      if (entry != null && entry.status == HabitEntryStatus.completed) {
        run++;
        best = max(best, run);
      } else if (entry == null || entry.status == HabitEntryStatus.pending) {
        run = 0;
      }
      // skipped — нейтральный день, серия сохраняется
    }

    return best;
  }
}
