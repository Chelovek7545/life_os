import 'package:flutter/material.dart';

/// Discriminator для хранения типа привычки в БД.
enum HabitTypeKind { morning, lunch, evening, time }

/// Абстрактный тип привычки.
///
/// Привычки разделены на несколько подтипов, унаследованных от одного
/// абстрактного класса, чтобы каждый тип мог нести своё время и метаданные.
abstract class HabitType {
  const HabitType();

  HabitTypeKind get kind;
  String get label;
  IconData get icon;

  /// Конкретное время, если тип привязан ко времени.
  TimeOfDay? get time;

  /// Подпись времени (например "09:30") или null.
  String? get timeLabel;

  @override
  bool operator ==(Object other) =>
      other is HabitType &&
      other.kind == kind &&
      (time == null ? other.time == null : other.time == time);

  @override
  int get hashCode => Object.hash(kind, time);
}

/// Привычка на утро.
class MorningHabit extends HabitType {
  const MorningHabit();

  @override
  HabitTypeKind get kind => HabitTypeKind.morning;

  @override
  String get label => 'Morning';

  @override
  IconData get icon => Icons.wb_sunny_outlined;

  @override
  TimeOfDay? get time => null;

  @override
  String? get timeLabel => null;
}

/// Привычка на обед.
class LunchHabit extends HabitType {
  const LunchHabit();

  @override
  HabitTypeKind get kind => HabitTypeKind.lunch;

  @override
  String get label => 'Lunch';

  @override
  IconData get icon => Icons.restaurant_outlined;

  @override
  TimeOfDay? get time => null;

  @override
  String? get timeLabel => null;
}

/// Привычка на вечер.
class EveningHabit extends HabitType {
  const EveningHabit();

  @override
  HabitTypeKind get kind => HabitTypeKind.evening;

  @override
  String get label => 'Evening';

  @override
  IconData get icon => Icons.nights_stay_outlined;

  @override
  TimeOfDay? get time => null;

  @override
  String? get timeLabel => null;
}

/// Привычка по конкретному времени.
class TimeHabit extends HabitType {
  const TimeHabit({required this.time});

  @override
  final TimeOfDay time;

  @override
  HabitTypeKind get kind => HabitTypeKind.time;

  @override
  String get label => 'Time';

  @override
  IconData get icon => Icons.schedule;

  String get formatTime =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  @override
  String? get timeLabel => formatTime;
}

/// Восстанавливает [HabitType] из дискриминатора и строки времени "HH:mm".
HabitType habitTypeFromStorage(HabitTypeKind kind, {String? time}) {
  return switch (kind) {
    HabitTypeKind.morning => const MorningHabit(),
    HabitTypeKind.lunch => const LunchHabit(),
    HabitTypeKind.evening => const EveningHabit(),
    HabitTypeKind.time => TimeHabit(time: parseStoredTime(time)),
  };
}

/// Парсит "HH:mm" в [TimeOfDay].
TimeOfDay parseStoredTime(String? value) {
  if (value == null || value.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
  final parts = value.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 9,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

/// Форматирует [TimeOfDay] в "HH:mm".
String formatStoredTime(TimeOfDay time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
