import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/habits/data/habit_model_extension.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:uuid/uuid.dart';

part 'habits_dao.g.dart';

@DriftAccessor(tables: [Habits, HabitEntries])
class HabitsDao extends DatabaseAccessor<AppDatabase> with _$HabitsDaoMixin {
  HabitsDao(super.db);

  // =============== HABITS: CREATE ===============

  Future<void> createHabit(HabitsCompanion habit) async {
    await into(habits).insert(habit);
  }

  // =============== HABITS: READ ===============

  Future<List<Habit>> getAllHabits() async {
    final rows = await (select(habits)..where((h) => h.isArchived.equals(false))).get();
    return rows.map((row) => row.toDomain()).toList();
  }

  Stream<List<Habit>> watchActiveHabits() {
    final query = select(habits)
      ..where((h) => h.isArchived.equals(false))
      ..orderBy([(h) => OrderingTerm(expression: h.createdAt)]);
    return query.watch().map(
      (rows) => rows.map((row) => row.toDomain()).toList(),
    );
  }

  Stream<List<Habit>> watchAllHabits() {
    return select(habits).watch().map(
      (rows) => rows.map((row) => row.toDomain()).toList(),
    );
  }

  Future<HabitModel?> getHabitById(String id) async {
    return (select(habits)..where((h) => h.id.equals(id))).getSingleOrNull();
  }

  // =============== HABITS: UPDATE ===============

  Future<void> updateHabit(Habit habit) async {
    await update(habits).replace(habit.toDrift());
  }

  Future<void> archiveHabit(String id) async {
    await (update(habits)..where((h) => h.id.equals(id))).write(
      HabitsCompanion(
        isArchived: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  // =============== HABITS: DELETE ===============

  Future<void> deleteHabit(String id) async {
    // Удаляем записи явно (drift не включает PRAGMA foreign_keys по умолчанию).
    await (delete(habitEntries)..where((e) => e.habitId.equals(id))).go();
    await (delete(habits)..where((h) => h.id.equals(id))).go();
  }

  // =============== ENTRIES ===============

  Future<HabitEntry?> getEntry(String habitId, String dateKey) async {
    final row = await (select(habitEntries)
          ..where((e) => e.habitId.equals(habitId) & e.dateKey.equals(dateKey)))
        .getSingleOrNull();
    return row?.toDomain();
  }

  Stream<List<HabitEntry>> watchAllEntries() {
    return select(habitEntries).watch().map(
      (rows) => rows.map((row) => row.toDomain()).toList(),
    );
  }

  /// Идемпотентно ставит статус записи на день (habitId + dateKey).
  Future<void> setEntryStatus(
    String habitId,
    String dateKey,
    HabitEntryStatus status,
  ) async {
    final existing = await getEntry(habitId, dateKey);
    if (existing == null) {
      await into(habitEntries).insert(
        HabitEntriesCompanion.insert(
          id: const Uuid().v4(),
          habitId: habitId,
          dateKey: dateKey,
          status: status,
          createdAt: DateTime.now(),
          completedAt: status == HabitEntryStatus.completed
              ? Value(DateTime.now())
              : const Value.absent(),
        ),
      );
    } else {
      await (update(habitEntries)..where((e) => e.id.equals(existing.id))).write(
        HabitEntriesCompanion(
          status: Value(status),
          completedAt: status == HabitEntryStatus.completed
              ? Value(DateTime.now())
              : const Value(null),
        ),
      );
    }
  }
}
