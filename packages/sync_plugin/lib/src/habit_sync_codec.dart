import 'dart:convert';

import 'package:habits_api/habits_api.dart';

class HabitSyncCodec {
  static String habit(Habit value) => jsonEncode({
    'id': value.id,
    'title': value.title,
    'type': value.type.kind.name,
    'time': value.type.timeLabel,
    'days': value.schedule.daysOfWeek,
    'durationWeeks': value.schedule.durationWeeks,
    'icon': value.icon,
    'color': value.colorHex,
    'reminderTime': value.reminderTime == null
        ? null
        : formatStoredTime(value.reminderTime!),
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    'updatedAt': value.updatedAt.toUtc().toIso8601String(),
    'isArchived': value.isArchived,
  });

  static Habit decodeHabit(String text) {
    final map = jsonDecode(text) as Map<String, dynamic>;
    final reminder = map['reminderTime'] as String?;
    final result = Habit(
      id: map['id'] as String,
      title: map['title'] as String,
      type: habitTypeFromStorage(
        HabitTypeKind.values.byName(map['type'] as String),
        time: map['time'] as String?,
      ),
      schedule: HabitSchedule(
        daysOfWeek: (map['days'] as List).cast<int>(),
        durationWeeks: map['durationWeeks'] as int?,
      ),
      icon: map['icon'] as String,
      colorHex: map['color'] as String,
      reminderTime: reminder == null ? null : parseStoredTime(reminder),
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updatedAt'] as String).toLocal(),
      isArchived: map['isArchived'] as bool,
    );
    if (result.schedule.daysOfWeek.join(',') !=
            decodeDaysOfWeek(
              encodeDaysOfWeek(result.schedule.daysOfWeek),
            ).join(',') ||
        habit(result) != text) {
      throw const FormatException('Noncanonical habit.');
    }
    return result;
  }

  static String entryId(String habitId, String dateKey) => '$habitId/$dateKey';

  static String entry(HabitEntry value) => jsonEncode({
    'habitId': value.habitId,
    'dateKey': value.dateKey,
    'status': value.status.name,
    'createdAt': value.createdAt.toUtc().toIso8601String(),
    'completedAt': value.completedAt?.toUtc().toIso8601String(),
  });

  static HabitEntry decodeEntry(String text) {
    final map = jsonDecode(text) as Map<String, dynamic>;
    final habitId = map['habitId'] as String;
    final dateKey = map['dateKey'] as String;
    final day = DateTime.tryParse(dateKey);
    final completed = map['completedAt'] as String?;
    final result = HabitEntry(
      id: entryId(habitId, dateKey),
      habitId: habitId,
      dateKey: dateKey,
      status: HabitEntryStatus.values.byName(map['status'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
      completedAt: completed == null
          ? null
          : DateTime.parse(completed).toLocal(),
    );
    if (habitId.isEmpty ||
        day == null ||
        formatDateKey(day) != dateKey ||
        entry(result) != text) {
      throw const FormatException('Noncanonical habit entry.');
    }
    return result;
  }
}
