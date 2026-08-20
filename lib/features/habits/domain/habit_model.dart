import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'habit_schedule.dart';
import 'habit_type.dart';

/// Привычка — регулярное действие без конечной точки.
class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.type,
    required this.schedule,
    this.icon = 'task_alt',
    this.colorHex = '#FF5C00',
    this.reminderTime,
    required this.createdAt,
    required this.updatedAt,
    this.isArchived = false,
  });

  final String id;
  final String title;
  final HabitType type;
  final HabitSchedule schedule;
  final String icon;
  final String colorHex;
  final TimeOfDay? reminderTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;

  factory Habit.create({
    required String title,
    required HabitType type,
    HabitSchedule? schedule,
    String icon = 'task_alt',
    String colorHex = '#FF5C00',
    TimeOfDay? reminderTime,
  }) {
    final now = DateTime.now();
    return Habit(
      id: const Uuid().v4(),
      title: title,
      type: type,
      schedule: schedule ?? const HabitSchedule(daysOfWeek: kAllWeekdays),
      icon: icon,
      colorHex: colorHex,
      reminderTime: reminderTime,
      createdAt: now,
      updatedAt: now,
    );
  }

  Habit copyWith({
    String? title,
    HabitType? type,
    HabitSchedule? schedule,
    String? icon,
    String? colorHex,
    TimeOfDay? reminderTime,
    bool clearReminderTime = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isArchived,
  }) {
    return Habit(
      id: id,
      title: title ?? this.title,
      type: type ?? this.type,
      schedule: schedule ?? this.schedule,
      icon: icon ?? this.icon,
      colorHex: colorHex ?? this.colorHex,
      reminderTime: clearReminderTime
          ? null
          : (reminderTime ?? this.reminderTime),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isArchived: isArchived ?? this.isArchived,
    );
  }
}
