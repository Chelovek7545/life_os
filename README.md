# life_os

## Reusable calendar component

`CalendarView<T>` is a standalone, null-safe week calendar in
`lib/core/calendar`. It accepts a plain `List<CalendarEvent<T>>`, so it is not
coupled to a database, backend, or state-management library. The desktop week
timeline in this app uses this component and supplies its glass styling through
builders.

### Installation and basic usage

```dart
import 'package:life_os/core/calendar/calendar.dart';

final controller = CalendarController();

CalendarView<String>(
  controller: controller,
  initialDate: DateTime.now(),
  events: [
    CalendarEvent(
      id: 'standup', data: 'Daily stand-up',
      start: DateTime(2026, 8, 19, 10),
      end: DateTime(2026, 8, 19, 10, 30),
    ),
  ],
  onEventMoved: (event, start, end) {
    // Replace the corresponding item in your own event list.
  },
)
```

For pub.dev extraction, move `lib/core/calendar` into a package `lib/`
directory and export `calendar.dart`; the component has no third-party
dependency.

### Controller

`CalendarController` supports `goToDate()`, `goToWeek()`, `nextWeek()`,
`previousWeek()`, `scrollToTime(hour: 9, minute: 30)`, and
`zoomTo(hourHeight: 120, dayWidth: 210)`. Calls before the view mounts are
retained and applied after attachment.

### Event model and builders

`CalendarEvent<T>` is immutable (`id`, `start`, `end`, `data`, `isAllDay`).
`CalendarDraftEvent` describes an in-progress selection. All UI is replaceable:

```dart
CalendarView<MyTask>(
  events: events,
  eventBuilder: (context, event, layout) => MyTaskTile(event.data),
  ghostBuilder: (context, draft) => const ColoredBox(color: Color(0x5575A7FF)),
  createEventFormBuilder: (context, draft, dismiss) => AlertDialog(
    title: const Text('New event'),
    actions: [TextButton(onPressed: dismiss, child: const Text('Close'))],
  ),
  dayHeaderBuilder: (context, date, isToday) => MyDayHeader(date: date),
  allDayEventBuilder: (context, event) => MyAllDayChip(event.data),
)
```

The form builder is optional and is presented after `onEventCreated`. Also
available: `timeLabelBuilder` and `contextMenuBuilder`.

### Interaction and callbacks

Event dragging reports `onEventMoved`; dragging the bottom resize handle
reports `onEventResized`; creation reports `onEventCreated`. The API also has
`onEventUpdated`, `onEventDeleted`, `onEventTapped`, `onDayTapped`,
`onEmptySlotTapped`, `onDateChanged`, and `onVisibleRangeChanged`.

`snapDuration` controls all drag/resize/create snapping (15 minutes by
default). Touch creation is long-press; on desktop draw directly on an empty
time grid to create a ghost. The creation form builder is placed next to that
ghost. Set `desktopCreateRequiresShift: true` in `CalendarGesturePolicy` if
your product prefers Shift-drag. Ctrl/Command + mouse wheel and pinch/trackpad
scale zoom; hover cursors, secondary-click menus, and Left/Right/+/- keyboard
navigation are supported on desktop. Hovering the day header and using the
wheel scrolls weeks horizontally; Ctrl/Command-wheel or pinch there changes
day width only.

### All-day, overlaps, and performance

Set `isAllDay: true` to render an event in the pinned header; use
`showAllDayEvents`, `showWeekends`, and `firstDayOfWeek` to configure the
visible week. Timed overlaps are automatically laid out in stable side-by-side
columns.

The time grid is a single `CustomPainter`, not thousands of slot widgets. The
horizontal axis has a 20,001-day virtual coordinate space and only events near
the viewport are built. For an exceptionally large source list, prefilter it
to a reasonable date range and replace only changed event instances.

### Example

Run the standalone demo from [`example/`](example/): it includes custom tiles,
ghosts, a creation form, all-day events, moving, resizing, controller controls,
and overlap layout.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
