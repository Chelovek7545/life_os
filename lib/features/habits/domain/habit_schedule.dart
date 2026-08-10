/// Расписание привычки: в какие дни недели она показывается и сколько недель.
class HabitSchedule {
  const HabitSchedule({required this.daysOfWeek, this.durationWeeks});

  /// Дни недели 1..7 (DateTime.monday .. DateTime.sunday).
  final List<int> daysOfWeek;

  /// Сколько недель привычка показывается. null = без ограничения.
  final int? durationWeeks;

  bool get isRepeating => durationWeeks == null;

  /// Показывается ли привычка в указанный день недели.
  bool isScheduledOn(DateTime date) => daysOfWeek.contains(date.weekday);

  /// Активна ли привычка в указанную дату (с учётом createdAt и durationWeeks).
  bool isActiveOn(DateTime date, {required DateTime createdAt}) {
    final start = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day.isBefore(start)) return false;
    if (durationWeeks == null) return true;
    final end = start.add(Duration(days: durationWeeks! * 7 - 1));
    return !day.isAfter(end);
  }

  HabitSchedule copyWith({
    List<int>? daysOfWeek,
    int? durationWeeks,
    bool clearDurationWeeks = false,
  }) {
    return HabitSchedule(
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
      durationWeeks: clearDurationWeeks ? null : (durationWeeks ?? this.durationWeeks),
    );
  }
}

/// Шифрует дни недели в битовую маску (бит = 1 << weekday).
int encodeDaysOfWeek(List<int> days) {
  return days.fold(0, (acc, day) => acc | (1 << day));
}

/// Декодирует битовую маску дней недели в список 1..7.
List<int> decodeDaysOfWeek(int mask) {
  final result = <int>[];
  for (var day = 1; day <= 7; day++) {
    if (mask & (1 << day) != 0) result.add(day);
  }
  return result.isEmpty ? const [1, 2, 3, 4, 5, 6, 7] : result;
}

const List<int> kAllWeekdays = [1, 2, 3, 4, 5, 6, 7];
