import 'package:life_os/features/habits/data/habit_model_extension.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';

class HabitsRepository {
  HabitsRepository(this._dao);

  final HabitsDao _dao;

  Stream<List<Habit>> watchActiveHabits() => _dao.watchActiveHabits();

  Stream<List<HabitEntry>> watchAllEntries() => _dao.watchAllEntries();

  Future<List<Habit>> getAllHabits() => _dao.getAllHabits();

  Future<Habit?> getHabitById(String id) async =>
      (await _dao.getHabitById(id))?.toDomain();

  Future<void> addHabit(Habit habit) async {
    try {
      await _dao.createHabit(habit.toDrift());
    } catch (error) {
      throw StorageException('Failed to save habit.', error);
    }
  }

  Future<void> updateHabit(Habit habit) async {
    try {
      await _dao.updateHabit(habit);
    } catch (error) {
      throw StorageException('Failed to update habit.', error);
    }
  }

  Future<void> archiveHabit(String id) async {
    try {
      await _dao.archiveHabit(id);
    } catch (error) {
      throw StorageException('Failed to archive habit.', error);
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      await _dao.deleteHabit(id);
    } catch (error) {
      throw StorageException('Failed to delete habit.', error);
    }
  }

  Future<void> setEntryStatus(
    String habitId,
    String dateKey,
    HabitEntryStatus status,
  ) async {
    try {
      await _dao.setEntryStatus(habitId, dateKey, status);
    } catch (error) {
      throw StorageException('Failed to update habit entry.', error);
    }
  }
}
