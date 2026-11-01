/// A local wall-clock time without a date, timezone or UI dependency.
class HabitTime {
  const HabitTime({required this.hour, required this.minute})
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  @override
  bool operator ==(Object other) =>
      other is HabitTime && other.hour == hour && other.minute == minute;
  @override
  int get hashCode => Object.hash(hour, minute);
}
