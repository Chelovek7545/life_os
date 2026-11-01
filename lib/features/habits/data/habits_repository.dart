import 'package:habits_api/habits_api.dart';
import 'package:life_os/features/habits/data/habit_model_extension.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/core/storage/storage_exception.dart';

class HabitsRepository implements HabitsApi {
  HabitsRepository(this._dao);

  final HabitsDao _dao;

  @override
  Stream<List<Habit>> watchActiveHabits() => _dao.watchActiveHabits();

  @override
  Stream<List<HabitEntry>> watchAllEntries() => _dao.watchAllEntries();

  @override
  Future<List<Habit>> getAllHabits() => _dao.getAllHabits();

  @override
  Future<Habit?> getHabitById(String id) async =>
      (await _dao.getHabitById(id))?.toDomain();

  @override
  Future<void> addHabit(Habit habit) async {
    try {
      await _dao.createHabit(habit.toDrift());
    } catch (error) {
      throw StorageException('Failed to save habit.', error);
    }
  }

  @override
  Future<void> updateHabit(Habit habit) async {
    try {
      await _dao.updateHabit(habit);
    } catch (error) {
      throw StorageException('Failed to update habit.', error);
    }
  }

  @override
  Future<void> archiveHabit(String id) async {
    try {
      await _dao.archiveHabit(id);
    } catch (error) {
      throw StorageException('Failed to archive habit.', error);
    }
  }

  @override
  Future<void> deleteHabit(String id) async {
    try {
      await _dao.deleteHabit(id);
    } catch (error) {
      throw StorageException('Failed to delete habit.', error);
    }
  }

  @override
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
