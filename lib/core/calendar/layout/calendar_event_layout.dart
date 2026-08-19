import '../models/calendar_event.dart';

/// Placement calculated for one event within a day's collision group.
class CalendarEventLayout {
  const CalendarEventLayout({required this.column, required this.columns});
  final int column;
  final int columns;
  double get leftFraction => column / columns;
  double get widthFraction => 1 / columns;
}

/// Calculates a stable, compact side-by-side layout for overlapping events.
Map<String, CalendarEventLayout> layoutOverlappingEvents<T>(
  Iterable<CalendarEvent<T>> events,
) {
  final sorted = events.where((e) => !e.isAllDay).toList()
    ..sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      return byStart != 0 ? byStart : a.end.compareTo(b.end);
    });
  final result = <String, CalendarEventLayout>{};
  var cluster = <CalendarEvent<T>>[];
  DateTime? clusterEnd;

  void resolveCluster() {
    if (cluster.isEmpty) return;
    final columns = <List<CalendarEvent<T>>>[];
    for (final event in cluster) {
      final index = columns.indexWhere(
        (column) => !column.last.end.isAfter(event.start),
      );
      if (index == -1) {
        columns.add([event]);
      } else {
        columns[index].add(event);
      }
    }
    for (var index = 0; index < columns.length; index++) {
      for (final event in columns[index]) {
        result[event.id] = CalendarEventLayout(
          column: index,
          columns: columns.length,
        );
      }
    }
    cluster = [];
    clusterEnd = null;
  }

  for (final event in sorted) {
    if (clusterEnd != null && !event.start.isBefore(clusterEnd!))
      resolveCluster();
    cluster.add(event);
    if (clusterEnd == null || event.end.isAfter(clusterEnd!))
      clusterEnd = event.end;
  }
  resolveCluster();
  return result;
}
