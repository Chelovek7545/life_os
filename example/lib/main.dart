import 'package:flutter/material.dart';
import 'package:life_os/core/calendar/calendar.dart';

void main() => runApp(const CalendarExampleApp());

class CalendarExampleApp extends StatelessWidget {
  const CalendarExampleApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: const CalendarExamplePage(),
  );
}

class CalendarExamplePage extends StatefulWidget {
  const CalendarExamplePage({super.key});
  @override
  State<CalendarExamplePage> createState() => _CalendarExamplePageState();
}

class _CalendarExamplePageState extends State<CalendarExamplePage> {
  final _controller = CalendarController();
  late List<CalendarEvent<String>> _events;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _events = [
      CalendarEvent(
        id: 'planning',
        data: 'Planning',
        start: DateTime(today.year, today.month, today.day, 9),
        end: DateTime(today.year, today.month, today.day, 10),
      ),
      CalendarEvent(
        id: 'review',
        data: 'Design review',
        start: DateTime(today.year, today.month, today.day, 9, 30),
        end: DateTime(today.year, today.month, today.day, 11),
      ),
      CalendarEvent(
        id: 'launch',
        data: 'Launch day',
        isAllDay: true,
        start: DateTime(today.year, today.month, today.day + 1),
        end: DateTime(today.year, today.month, today.day + 2),
      ),
    ];
  }

  void _replace(String id, DateTime start, DateTime end) => setState(
    () => _events = [
      for (final event in _events)
        if (event.id == id) event.copyWith(start: start, end: end) else event,
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('CalendarView example'),
      actions: [
        IconButton(
          onPressed: _controller.previousWeek,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: _controller.nextWeek,
          icon: const Icon(Icons.chevron_right),
        ),
        IconButton(
          onPressed: () => _controller.zoomTo(hourHeight: 110, dayWidth: 210),
          icon: const Icon(Icons.zoom_in),
        ),
      ],
    ),
    body: CalendarView<String>(
      controller: _controller,
      events: _events,
      eventBuilder: (context, event, layout) => Card(
        margin: EdgeInsets.zero,
        color: Colors.indigo.withOpacity(.75),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(event.data),
        ),
      ),
      ghostBuilder: (context, draft) =>
          const ColoredBox(color: Color(0x6675A7FF)),
      createEventFormBuilder: (context, draft, dismiss) => AlertDialog(
        title: Text(
          'Create at ${TimeOfDay.fromDateTime(draft.start).format(context)}',
        ),
        actions: [TextButton(onPressed: dismiss, child: const Text('Done'))],
      ),
      onEventCreated: (draft) => setState(
        () => _events = [
          ..._events,
          CalendarEvent(
            id: 'event-${DateTime.now().microsecondsSinceEpoch}',
            data: 'New event',
            start: draft.start,
            end: draft.end,
          ),
        ],
      ),
      onEventMoved: (event, start, end) => _replace(event.id, start, end),
      onEventResized: (event, start, end) => _replace(event.id, start, end),
    ),
  );
}
