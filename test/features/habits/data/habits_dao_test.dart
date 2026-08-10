import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/habits/data/habit_model_extension.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';

void main() {
  late AppDatabase db;
  late HabitsDao dao;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    dao = HabitsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('create and read back a habit', () async {
    final habit = Habit.create(
      title: 'Read 20 pages',
      type: const EveningHabit(),
      schedule: const HabitSchedule(daysOfWeek: [1, 3, 5], durationWeeks: 2),
      icon: 'menu_book',
      colorHex: '#4FC3F7',
    );

    await dao.createHabit(habit.toDrift());
    final all = await dao.getAllHabits();

    expect(all, hasLength(1));
    final restored = all.first;
    expect(restored.title, 'Read 20 pages');
    expect(restored.type, isA<EveningHabit>());
    expect(restored.schedule.daysOfWeek, [1, 3, 5]);
    expect(restored.schedule.durationWeeks, 2);
    expect(restored.icon, 'menu_book');
    expect(restored.colorHex, '#4FC3F7');
  });

  test('set entry status creates then updates idempotently', () async {
    final habit = Habit.create(
      title: 'Water',
      type: const MorningHabit(),
    );
    await dao.createHabit(habit.toDrift());

    await dao.setEntryStatus(habit.id, '2026-08-10', HabitEntryStatus.completed);
    var entries = await dao.watchAllEntries().first;
    expect(entries, hasLength(1));
    expect(entries.first.status, HabitEntryStatus.completed);

    // повторная установка не должна плодить дубли
    await dao.setEntryStatus(habit.id, '2026-08-10', HabitEntryStatus.completed);
    entries = await dao.watchAllEntries().first;
    expect(entries, hasLength(1));

    await dao.setEntryStatus(habit.id, '2026-08-10', HabitEntryStatus.skipped);
    entries = await dao.watchAllEntries().first;
    expect(entries, hasLength(1));
    expect(entries.first.status, HabitEntryStatus.skipped);
  });

  test('deleting a habit cascades its entries', () async {
    final habit = Habit.create(
      title: 'Water',
      type: const MorningHabit(),
    );
    await dao.createHabit(habit.toDrift());
    await dao.setEntryStatus(habit.id, '2026-08-10', HabitEntryStatus.completed);

    await dao.deleteHabit(habit.id);

    final entries = await dao.watchAllEntries().first;
    expect(entries, isEmpty);
    expect(await dao.getAllHabits(), isEmpty);
  });
}
