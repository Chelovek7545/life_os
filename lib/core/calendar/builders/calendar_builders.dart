import 'package:flutter/material.dart';

import '../layout/calendar_event_layout.dart';
import '../models/calendar_draft_event.dart';
import '../models/calendar_event.dart';

typedef CalendarEventBuilder<T> =
    Widget Function(
      BuildContext context,
      CalendarEvent<T> event,
      CalendarEventLayout layout,
    );
typedef CalendarGhostBuilder =
    Widget Function(BuildContext context, CalendarDraftEvent draft);
typedef CalendarCreateEventFormBuilder =
    Widget Function(
      BuildContext context,
      CalendarDraftEvent draft,
      VoidCallback dismiss,
    );
typedef CalendarDayHeaderBuilder =
    Widget Function(BuildContext context, DateTime date, bool isToday);
typedef CalendarTimeLabelBuilder =
    Widget Function(BuildContext context, int hour);
typedef CalendarAllDayEventBuilder<T> =
    Widget Function(BuildContext context, CalendarEvent<T> event);
typedef CalendarContextMenuBuilder<T> =
    Widget Function(
      BuildContext context,
      CalendarEvent<T> event,
      Offset position,
    );
