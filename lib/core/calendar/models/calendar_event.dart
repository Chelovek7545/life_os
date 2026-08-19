import 'package:flutter/foundation.dart';

/// An immutable timed or all-day event rendered by [CalendarView].
@immutable
class CalendarEvent<T> {
  CalendarEvent({
    required this.id,
    required this.start,
    required this.end,
    required this.data,
    this.isAllDay = false,
  }) : assert(!end.isBefore(start), 'end must not be before start');

  final String id;
  final DateTime start;
  final DateTime end;
  final T data;
  final bool isAllDay;

  Duration get duration => end.difference(start);

  CalendarEvent<T> copyWith({
    DateTime? start,
    DateTime? end,
    T? data,
    bool? isAllDay,
  }) => CalendarEvent<T>(
    id: id,
    start: start ?? this.start,
    end: end ?? this.end,
    data: data ?? this.data,
    isAllDay: isAllDay ?? this.isAllDay,
  );
}
