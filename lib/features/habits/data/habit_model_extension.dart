import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';

extension HabitDataToDomain on HabitModel {
  Habit toDomain() {
    return Habit(
      id: id,
      title: title,
      type: habitTypeFromStorage(typeKind, time: timeOfDay),
      schedule: HabitSchedule(
        daysOfWeek: decodeDaysOfWeek(daysOfWeek),
        durationWeeks: durationWeeks,
      ),
      icon: icon,
      colorHex: color,
      reminderTime: reminderTime != null ? parseStoredTime(reminderTime) : null,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: isArchived,
    );
  }
}

extension HabitToDrift on Habit {
  HabitsCompanion toDrift() {
    return HabitsCompanion(
      id: Value(id),
      title: Value(title),
      icon: Value(icon),
      color: Value(colorHex),
      typeKind: Value(type.kind),
      timeOfDay: Value(
        type is TimeHabit ? (type as TimeHabit).formatTime : null,
      ),
      daysOfWeek: Value(encodeDaysOfWeek(schedule.daysOfWeek)),
      durationWeeks: Value(schedule.durationWeeks),
      reminderTime: Value(
        reminderTime != null ? formatStoredTime(reminderTime!) : null,
      ),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isArchived: Value(isArchived),
    );
  }
}

extension HabitEntryDataToDomain on HabitEntryModel {
  HabitEntry toDomain() {
    return HabitEntry(
      id: id,
      habitId: habitId,
      dateKey: dateKey,
      status: status,
      completedAt: completedAt,
      createdAt: createdAt,
    );
  }
}
