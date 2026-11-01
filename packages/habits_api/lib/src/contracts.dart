import 'habit_model.dart';
import 'habit_entry_model.dart';

abstract interface class HabitsQueries {
  Stream<List<Habit>> watchActiveHabits();
  Stream<List<HabitEntry>> watchAllEntries();
  Future<List<Habit>> getAllHabits();
  Future<Habit?> getHabitById(String id);
}

abstract interface class HabitsCommands {
  Future<void> addHabit(Habit habit);
  Future<void> updateHabit(Habit habit);
  Future<void> archiveHabit(String id);
  Future<void> deleteHabit(String id);
  Future<void> setEntryStatus(
    String habitId,
    String dateKey,
    HabitEntryStatus status,
  );
}

abstract interface class HabitsApi implements HabitsQueries, HabitsCommands {}
