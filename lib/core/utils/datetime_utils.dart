bool isDateInSameWeek(DateTime date, DateTime anchorDate) {
  // Find Monday of the anchor date's week
  final anchorWeekStart = getWeekStart(anchorDate);
  // Week ends on Sunday (start + 6 days)
  final anchorWeekEnd = anchorWeekStart.add(const Duration(days: 6));
  
  // Check if date falls within [anchorWeekStart, anchorWeekEnd]
  return !date.isBefore(anchorWeekStart) && !date.isAfter(anchorWeekEnd);
}

/// Returns the start of the week (Monday) for a given date
DateTime getWeekStart(DateTime date) {
  final weekday = date.weekday; // 1 = Monday, 7 = Sunday
  return DateTime(date.year, date.month, date.day - (weekday - 1));
}

List<DateTime> getDatesForWeek(DateTime anchorDate) {
  final weekStart = getWeekStart(anchorDate);
  return List.generate(7, (index) => weekStart.add(Duration(days: index)));
}

extension DateTimeStartOfDay on DateTime {
  // Возвращает дату в начале дня (00:00:00), чтобы сравнивать только дни
  DateTime get startOfDay => DateTime(year, month, day);
}

extension DateTimeDurationInMinutes on DateTime {
  //Пишет длительность в минутах дня(времени)
  int get durationInMinutes => hour * 60 + minute;
}

extension IsDateOnly on DateTime {
  bool get isDateOnly => millisecond == 1 && second == 0 && minute == 0 && hour == 0; 
}