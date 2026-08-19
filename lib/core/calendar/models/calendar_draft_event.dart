import 'package:flutter/foundation.dart';

/// A transient event used while the user is selecting an empty time range.
@immutable
class CalendarDraftEvent {
  const CalendarDraftEvent({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);
}
