import 'package:habits_api/habits_api.dart';

/// Привычка вместе с её записью за выбранный день и серией.
class HabitWithEntry {
  const HabitWithEntry({
    required this.habit,
    required this.entry,
    required this.streak,
    required this.isScheduled,
    required this.isExpired,
  });

  final Habit habit;
  final HabitEntry? entry;
  final HabitStreak streak;
  final bool isScheduled;
  final bool isExpired;

  bool get isCompleted => entry?.status == HabitEntryStatus.completed;

  bool get isSkipped => entry?.status == HabitEntryStatus.skipped;
}

sealed class HabitsScreenState {
  const HabitsScreenState();

  R when<R>({
    required R Function() loading,
    required R Function(List<HabitWithEntry> habits) loaded,
    required R Function(String message) error,
  }) {
    return switch (this) {
      HabitsLoading() => loading(),
      HabitsLoaded(habits: final habits) => loaded(habits),
      HabitsError(message: final message) => error(message),
    };
  }

  R? maybeWhen<R>({
    R Function()? loading,
    R Function(List<HabitWithEntry> habits)? loaded,
    R Function(String message)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      HabitsLoading() => loading?.call() ?? orElse(),
      HabitsLoaded(habits: final habits) => loaded?.call(habits) ?? orElse(),
      HabitsError(message: final message) => error?.call(message) ?? orElse(),
    };
  }
}

final class HabitsLoading extends HabitsScreenState {
  const HabitsLoading();
}

final class HabitsLoaded extends HabitsScreenState {
  HabitsLoaded({required List<HabitWithEntry> habits})
    : habits = List.unmodifiable(habits);

  final List<HabitWithEntry> habits;
}

final class HabitsError extends HabitsScreenState {
  const HabitsError(this.message);

  final String message;
}
