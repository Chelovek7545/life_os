import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';

extension HabitTypePresentation on HabitType {
  String get label => switch (kind) {
    HabitTypeKind.morning => 'Morning',
    HabitTypeKind.lunch => 'Lunch',
    HabitTypeKind.evening => 'Evening',
    HabitTypeKind.time => 'Time',
  };
  IconData get icon => switch (kind) {
    HabitTypeKind.morning => Icons.wb_sunny_outlined,
    HabitTypeKind.lunch => Icons.restaurant_outlined,
    HabitTypeKind.evening => Icons.nights_stay_outlined,
    HabitTypeKind.time => Icons.schedule,
  };
}

extension HabitTimePresentation on HabitTime {
  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);
}

HabitTime habitTimeFromTimeOfDay(TimeOfDay time) =>
    HabitTime(hour: time.hour, minute: time.minute);
