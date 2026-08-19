import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../builders/calendar_builders.dart';
import '../controller/calendar_controller.dart';
import '../gestures/calendar_gesture_policy.dart';
import '../layout/calendar_event_layout.dart';
import '../models/calendar_draft_event.dart';
import '../models/calendar_event.dart';
import '../rendering/calendar_grid_painter.dart';

const _timeRulerWidth = 56.0;
const _virtualDayCount = 20001;
const _virtualCenter = _virtualDayCount ~/ 2;

/// A virtualized, keyboard-accessible week calendar.
///
/// Events are controlled by the caller: callbacks report proposed changes and
/// the caller replaces [events] with its new immutable list.
class CalendarView<T> extends StatefulWidget {
  CalendarView({
    super.key,
    required this.events,
    this.controller,
    this.initialDate,
    this.initialHour = 8,
    this.startHour = 0,
    this.endHour = 24,
    this.initialHourHeight = 80,
    this.minHourHeight = 32,
    this.maxHourHeight = 240,
    this.initialDayWidth = 160,
    this.minDayWidth = 88,
    this.maxDayWidth = 420,
    this.snapDuration = const Duration(minutes: 15),
    this.showAllDayEvents = true,
    this.showWeekends = true,
    this.firstDayOfWeek = DateTime.monday,
    this.gesturePolicy = const CalendarGesturePolicy(),
    this.eventBuilder,
    this.ghostBuilder,
    this.createEventFormBuilder,
    this.dayHeaderBuilder,
    this.timeLabelBuilder,
    this.allDayEventBuilder,
    this.contextMenuBuilder,
    this.onEventCreated,
    this.onEventMoved,
    this.onEventResized,
    this.onEventUpdated,
    this.onEventDeleted,
    this.onEventTapped,
    this.onDayTapped,
    this.onEmptySlotTapped,
    this.onDateChanged,
    this.onVisibleRangeChanged,
    this.backgroundColor,
    this.gridLineColor = const Color(0x1FFFFFFF),
  }) : assert(endHour > startHour),
       assert(
         initialHourHeight >= minHourHeight &&
             initialHourHeight <= maxHourHeight,
       ),
       assert(initialDayWidth >= minDayWidth && initialDayWidth <= maxDayWidth),
       assert(snapDuration.inMinutes > 0);

  final List<CalendarEvent<T>> events;
  final CalendarController? controller;
  final DateTime? initialDate;
  final int initialHour;
  final int startHour;
  final int endHour;
  final double initialHourHeight;
  final double minHourHeight;
  final double maxHourHeight;
  final double initialDayWidth;
  final double minDayWidth;
  final double maxDayWidth;
  final Duration snapDuration;
  final bool showAllDayEvents;
  final bool showWeekends;
  final int firstDayOfWeek;
  final CalendarGesturePolicy gesturePolicy;
  final CalendarEventBuilder<T>? eventBuilder;
  final CalendarGhostBuilder? ghostBuilder;
  final CalendarCreateEventFormBuilder? createEventFormBuilder;
  final CalendarDayHeaderBuilder? dayHeaderBuilder;
  final CalendarTimeLabelBuilder? timeLabelBuilder;
  final CalendarAllDayEventBuilder<T>? allDayEventBuilder;
  final CalendarContextMenuBuilder<T>? contextMenuBuilder;
  final ValueChanged<CalendarDraftEvent>? onEventCreated;
  final void Function(CalendarEvent<T> event, DateTime start, DateTime end)?
  onEventMoved;
  final void Function(CalendarEvent<T> event, DateTime start, DateTime end)?
  onEventResized;
  final ValueChanged<CalendarEvent<T>>? onEventUpdated;
  final ValueChanged<CalendarEvent<T>>? onEventDeleted;
  final ValueChanged<CalendarEvent<T>>? onEventTapped;
  final ValueChanged<DateTime>? onDayTapped;
  final ValueChanged<DateTime>? onEmptySlotTapped;
  final ValueChanged<DateTime>? onDateChanged;
  final void Function(DateTime start, DateTime end)? onVisibleRangeChanged;
  final Color? backgroundColor;
  final Color gridLineColor;

  @override
  State<CalendarView<T>> createState() => _CalendarViewState<T>();
}

class _CalendarViewState<T> extends State<CalendarView<T>>
    implements CalendarControllerDelegate {
  late final ScrollController _vertical;
  late final ScrollController _horizontal;
  late DateTime _originDate;
  late DateTime _focusedDate;
  late double _hourHeight;
  late double _dayWidth;
  CalendarDraftEvent? _draft;
  String? _selectedId;
  _EventInteraction<T>? _interaction;
  int? _createPointer;
  Offset? _createOrigin;
  DateTime? _lastReportedRangeStart;
  bool _didInitialPosition = false;
  double _scaleStartHourHeight = 0;
  double _scaleStartDayWidth = 0;
  double _headerScaleStartDayWidth = 0;
  bool _draftFormVisible = false;

  @override
  DateTime get focusedDate => _focusedDate;

  @override
  void initState() {
    super.initState();
    _focusedDate = _dateOnly(widget.initialDate ?? DateTime.now());
    _originDate = _startOfWeek(_focusedDate).subtract(
      Duration(
        days: widget.showWeekends ? _virtualCenter : (_virtualCenter ~/ 5) * 7,
      ),
    );
    _hourHeight = widget.initialHourHeight;
    _dayWidth = widget.initialDayWidth;
    _vertical = ScrollController();
    _horizontal = ScrollController();
    _horizontal.addListener(_reportVisibleRange);
    widget.controller?.attach(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialPosition());
  }

  @override
  void didUpdateWidget(covariant CalendarView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _horizontal.removeListener(_reportVisibleRange);
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  void _initialPosition() {
    if (!mounted || _didInitialPosition) return;
    _didInitialPosition = true;
    _horizontal.jumpTo(_indexFor(_startOfWeek(_focusedDate)) * _dayWidth);
    scrollToMinutes(widget.initialHour * 60, animated: false);
  }

  @override
  void goToDate(DateTime date) {
    final normalized = _dateOnly(date);
    setState(() => _focusedDate = normalized);
    widget.onDateChanged?.call(normalized);
    if (_horizontal.hasClients) {
      _horizontal.animateTo(
        _indexFor(_startOfWeek(normalized)) * _dayWidth,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void scrollToMinutes(int minutes, {required bool animated}) {
    if (!_vertical.hasClients) return;
    final target = ((minutes - widget.startHour * 60) / 60 * _hourHeight)
        .clamp(0.0, _vertical.position.maxScrollExtent)
        .toDouble();
    if (animated) {
      _vertical.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _vertical.jumpTo(target);
    }
  }

  @override
  void zoomTo({double? hourHeight, double? dayWidth, required bool animated}) {
    final nextHeight = (hourHeight ?? _hourHeight)
        .clamp(widget.minHourHeight, widget.maxHourHeight)
        .toDouble();
    final nextWidth = (dayWidth ?? _dayWidth)
        .clamp(widget.minDayWidth, widget.maxDayWidth)
        .toDouble();
    if (nextHeight == _hourHeight && nextWidth == _dayWidth) return;
    final anchorMinutes = _vertical.hasClients
        ? _vertical.offset / _hourHeight * 60
        : 0.0;
    final anchorDay = _horizontal.hasClients
        ? _horizontal.offset / _dayWidth
        : _virtualCenter.toDouble();
    setState(() {
      _hourHeight = nextHeight;
      _dayWidth = nextWidth;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_vertical.hasClients || !_horizontal.hasClients) return;
      _vertical.jumpTo(
        (anchorMinutes / 60 * _hourHeight).clamp(
          0.0,
          _vertical.position.maxScrollExtent,
        ),
      );
      _horizontal.jumpTo(
        (anchorDay * _dayWidth).clamp(
          0.0,
          _horizontal.position.maxScrollExtent,
        ),
      );
    });
  }

  int get _displayedDays => widget.showWeekends ? 7 : 5;
  double get _contentHeight =>
      (widget.endHour - widget.startHour) * _hourHeight;
  int _indexFor(DateTime date) {
    final days = _dateOnly(date).difference(_originDate).inDays;
    if (widget.showWeekends) return days;
    return (days ~/ 7) * 5 + math.min(days % 7, 4);
  }

  DateTime _dateAt(int index) {
    if (widget.showWeekends) return _originDate.add(Duration(days: index));
    return _originDate.add(Duration(days: (index ~/ 5) * 7 + index % 5));
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = _dateOnly(date);
    final offset = (normalized.weekday - widget.firstDayOfWeek + 7) % 7;
    return normalized.subtract(Duration(days: offset));
  }

  void _reportVisibleRange() {
    if (!_horizontal.hasClients) return;
    final firstIndex = (_horizontal.offset / _dayWidth).floor();
    final start = _dateAt(firstIndex);
    if (_lastReportedRangeStart == start) return;
    _lastReportedRangeStart = start;
    final end = _dateAt(
      firstIndex + (_horizontal.position.viewportDimension / _dayWidth).ceil(),
    );
    widget.onVisibleRangeChanged?.call(start, end);
    final week = _startOfWeek(start);
    if (!_isSameDay(week, _focusedDate)) {
      _focusedDate = week;
      widget.onDateChanged?.call(week);
    }
    setState(() {});
  }

  int _minuteForLocalY(double y) {
    final raw = widget.startHour * 60 + y / _hourHeight * 60;
    final snap = widget.snapDuration.inMinutes;
    final result = (raw / snap).round() * snap;
    return result.clamp(widget.startHour * 60, widget.endHour * 60 - snap);
  }

  DateTime _dateTimeFor(Offset local) {
    final index = ((_horizontal.offset + local.dx) / _dayWidth).floor();
    final minute = _minuteForLocalY(_vertical.offset + local.dy);
    final date = _dateAt(index);
    return DateTime(date.year, date.month, date.day, minute ~/ 60, minute % 60);
  }

  void _onGridPointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        widget.gesturePolicy.desktopCreateRequiresShift &&
        !_hasShift)
      return;
    if (event.buttons != kPrimaryButton) return;
    if (_eventAt(event.localPosition) != null) return;
    _createPointer = event.pointer;
    _createOrigin = event.localPosition;
  }

  CalendarEvent<T>? _eventAt(Offset local) {
    final index = ((_horizontal.offset + local.dx) / _dayWidth).floor();
    final minute = _minuteForLocalY(_vertical.offset + local.dy);
    final date = _dateAt(index);
    final t = DateTime(
      date.year,
      date.month,
      date.day,
      minute ~/ 60,
      minute % 60,
    );
    for (final event in widget.events) {
      if (event.isAllDay) continue;
      if (!_isSameDay(event.start, t)) continue;
      if (!event.start.isAfter(t) && event.end.isAfter(t)) return event;
    }
    return null;
  }

  void _onGridPointerMove(PointerMoveEvent event) {
    if (event.pointer != _createPointer || _createOrigin == null) return;
    if (_interaction != null) return;
    if (event.kind == PointerDeviceKind.touch)
      return; // touch uses long press so scroll remains natural.
    final start = _dateTimeFor(_createOrigin!);
    final end = _dateTimeFor(event.localPosition);
    if (start.day != end.day ||
        (event.localPosition - _createOrigin!).distance < 4)
      return;
    setState(
      () => _draft = CalendarDraftEvent(
        start: start.isBefore(end) ? start : end,
        end: (start.isBefore(end) ? end : start).add(
          widget.gesturePolicy.minimumEventDuration,
        ),
      ),
    );
  }

  void _onGridPointerUp(PointerEvent event) {
    if (event.pointer != _createPointer) return;
    _createPointer = null;
    _createOrigin = null;
    final draft = _draft;
    if (draft != null) _completeDraft(draft);
  }

  bool get _hasShift =>
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftLeft,
      ) ||
      HardwareKeyboard.instance.logicalKeysPressed.contains(
        LogicalKeyboardKey.shiftRight,
      );
  bool get _hasZoomModifier {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_hasZoomModifier) return;
    final factor = math.exp(-event.scrollDelta.dy / 360);
    zoomTo(
      hourHeight: _hourHeight * factor,
      dayWidth: _dayWidth * factor,
      animated: false,
    );
  }

  void _onHeaderPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_horizontal.hasClients) return;
    if (_hasZoomModifier) {
      final factor = math.exp(-event.scrollDelta.dy / 360);
      zoomTo(dayWidth: _dayWidth * factor, animated: false);
      return;
    }
    final position = _horizontal.position;
    final target = (position.pixels + event.scrollDelta.dy)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    _horizontal.jumpTo(target);
  }

  void _completeDraft(CalendarDraftEvent draft) {
    widget.onEventCreated?.call(draft);
    setState(() {
      _draftFormVisible = widget.createEventFormBuilder != null;
      if (!_draftFormVisible) _draft = null;
    });
  }

  void _dismissDraft() => setState(() {
    _draft = null;
    _draftFormVisible = false;
  });

  void _startInteraction(CalendarEvent<T> event, Offset global, bool resize) {
    _interaction = _EventInteraction(
      event: event,
      startGlobal: global,
      resizing: resize,
    );
    setState(() => _selectedId = event.id);
  }

  void _updateInteraction(DragUpdateDetails details) {
    final active = _interaction;
    if (active == null) return;
    final minuteDelta = _snapDelta(
      details.globalPosition.dy - active.startGlobal.dy,
    );
    final dayDelta =
        ((details.globalPosition.dx - active.startGlobal.dx) / _dayWidth)
            .round();
    final start = active.event.start.add(
      Duration(
        days: active.resizing ? 0 : dayDelta,
        minutes: active.resizing ? 0 : minuteDelta,
      ),
    );
    final end = active.resizing
        ? active.event.end.add(Duration(minutes: minuteDelta))
        : active.event.end.add(Duration(days: dayDelta, minutes: minuteDelta));
    if (!end.isAfter(start.add(widget.gesturePolicy.minimumEventDuration)))
      return;
    setState(() => _interaction = active.copyWith(start: start, end: end));
  }

  int _snapDelta(double pixels) {
    final minutes = pixels / _hourHeight * 60;
    final snap = widget.snapDuration.inMinutes;
    return (minutes / snap).round() * snap;
  }

  void _endInteraction() {
    final active = _interaction;
    if (active == null) return;
    _interaction = null;
    setState(() {});
    if (active.resizing) {
      widget.onEventResized?.call(
        active.event,
        active.start ?? active.event.start,
        active.end ?? active.event.end,
      );
    } else {
      widget.onEventMoved?.call(
        active.event,
        active.start ?? active.event.start,
        active.end ?? active.event.end,
      );
    }
  }

  void _openContextMenu(CalendarEvent<T> event, Offset position) {
    final builder = widget.contextMenuBuilder;
    showMenu<void>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      items: builder != null
          ? [
              PopupMenuItem(
                enabled: false,
                padding: EdgeInsets.zero,
                child: builder(context, event, position),
              ),
            ]
          : [
              PopupMenuItem(
                onTap: () => widget.onEventUpdated?.call(event),
                child: const Text('Edit'),
              ),
              PopupMenuItem(
                onTap: () => widget.onEventDeleted?.call(event),
                child: const Text('Delete'),
              ),
            ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleStart = _horizontal.hasClients
        ? _dateAt((_horizontal.offset / _dayWidth).floor())
        : _startOfWeek(_focusedDate);
    final days = List<DateTime>.generate(
      _displayedDays,
      (i) => visibleStart.add(Duration(days: i)),
    );
    final allDayHeight = widget.showAllDayEvents ? _allDayHeight(days) : 0.0;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          goToDate(_focusedDate.subtract(const Duration(days: 7)));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          goToDate(_focusedDate.add(const Duration(days: 7)));
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.add ||
            event.logicalKey == LogicalKeyboardKey.equal) {
          zoomTo(
            hourHeight: _hourHeight * 1.15,
            dayWidth: _dayWidth * 1.15,
            animated: true,
          );
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.minus) {
          zoomTo(
            hourHeight: _hourHeight / 1.15,
            dayWidth: _dayWidth / 1.15,
            animated: true,
          );
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.escape && _draft != null) {
          _dismissDraft();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ColoredBox(
        color: widget.backgroundColor ?? Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerSignal: _onHeaderPointerSignal,
              child: GestureDetector(
                onScaleStart: (_) => _headerScaleStartDayWidth = _dayWidth,
                onScaleUpdate: (details) {
                  if (details.scale != 1) {
                    zoomTo(
                      dayWidth: _headerScaleStartDayWidth * details.scale,
                      animated: false,
                    );
                  }
                },
                child: SizedBox(
                  height: 62 + allDayHeight,
                  child: LayoutBuilder(
                    builder: (context, constraints) => AnimatedBuilder(
                      animation: _horizontal,
                      builder: (context, _) => _buildPinnedHeader(
                        days,
                        allDayHeight,
                        constraints.maxWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: _timeRulerWidth,
                    child: _TimeRuler(
                      hourHeight: _hourHeight,
                      startHour: widget.startHour,
                      endHour: widget.endHour,
                      builder: widget.timeLabelBuilder,
                    ),
                  ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerSignal: _onPointerSignal,
                      onPointerDown: _onGridPointerDown,
                      onPointerMove: _onGridPointerMove,
                      onPointerUp: _onGridPointerUp,
                      onPointerCancel: _onGridPointerUp,
                      child: GestureDetector(
                        onScaleStart: (_) {
                          _scaleStartHourHeight = _hourHeight;
                          _scaleStartDayWidth = _dayWidth;
                        },
                        onScaleUpdate: (details) {
                          if (details.scale != 1) {
                            zoomTo(
                              hourHeight: _scaleStartHourHeight * details.scale,
                              dayWidth: _scaleStartDayWidth * details.scale,
                              animated: false,
                            );
                          }
                        },
                        onLongPressStart: (details) {
                          if (_eventAt(details.localPosition) != null) return;
                          setState(
                            () => _draft = CalendarDraftEvent(
                              start: _dateTimeFor(details.localPosition),
                              end: _dateTimeFor(
                                details.localPosition,
                              ).add(widget.gesturePolicy.minimumEventDuration),
                            ),
                          );
                        },
                        onLongPressEnd: (_) {
                          final draft = _draft;
                          if (draft != null) _completeDraft(draft);
                        },
                        onTapUp: (details) {
                          if (_eventAt(details.localPosition) != null) return;
                          final date = _dateTimeFor(details.localPosition);
                          widget.onEmptySlotTapped?.call(date);
                          widget.onDayTapped?.call(_dateOnly(date));
                        },
                        child: SingleChildScrollView(
                          controller: _vertical,
                          child: SingleChildScrollView(
                            controller: _horizontal,
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: _virtualDayCount * _dayWidth,
                              height: _contentHeight,
                              child: _buildGrid(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _allDayHeight(List<DateTime> days) {
    final max = days
        .map(
          (day) => widget.events
              .where((event) => event.isAllDay && _occupiesDay(event, day))
              .length,
        )
        .fold<int>(0, math.max);
    return max == 0 ? 0 : math.min(3, max) * 25.0 + 4;
  }

  Widget _buildPinnedHeader(
    List<DateTime> visibleDays,
    double allDayHeight,
    double viewport,
  ) {
    final offset = _horizontal.hasClients
        ? _horizontal.offset
        : _indexFor(_startOfWeek(_focusedDate)) * _dayWidth;
    final first = (offset / _dayWidth).floor();
    final count = (viewport / _dayWidth).ceil() + 3;
    return Stack(
      children: [
        for (var i = 0; i < count; i++)
          _DayHeaderColumn<T>(
            left: (first + i) * _dayWidth - offset,
            width: _dayWidth,
            date: _dateAt(first + i),
            allDayHeight: allDayHeight,
            events: widget.showAllDayEvents
                ? widget.events
                      .where(
                        (event) =>
                            event.isAllDay &&
                            _occupiesDay(event, _dateAt(first + i)),
                      )
                      .toList(growable: false)
                : const [],
            dayHeaderBuilder: widget.dayHeaderBuilder,
            allDayBuilder: widget.allDayEventBuilder,
          ),
      ],
    );
  }

  Widget _buildGrid() {
    final first = _horizontal.hasClients
        ? (_horizontal.offset / _dayWidth).floor()
        : _indexFor(_startOfWeek(_focusedDate));
    final span = _horizontal.hasClients
        ? (_horizontal.position.viewportDimension / _dayWidth).ceil() + 4
        : 10;
    final startIndex = math.max(0, first - 2);
    final endIndex = math.min(_virtualDayCount, first + span);
    final rangeStart = _dateAt(startIndex);
    final rangeEnd = _dateAt(endIndex + 1);
    final timed = widget.events
        .where(
          (event) =>
              !event.isAllDay &&
              event.start.isBefore(rangeEnd) &&
              event.end.isAfter(rangeStart),
        )
        .toList(growable: false);
    final byDay = <DateTime, List<CalendarEvent<T>>>{};
    for (final event in timed) {
      byDay.putIfAbsent(_dateOnly(event.start), () => []).add(event);
    }
    final layouts = <String, CalendarEventLayout>{};
    for (final entries in byDay.values) {
      layouts.addAll(layoutOverlappingEvents(entries));
    }
    final current = _interaction;
    return Stack(
      children: [
        RepaintBoundary(
          child: CustomPaint(
            size: Size(_virtualDayCount * _dayWidth, _contentHeight),
            painter: CalendarGridPainter(
              hourHeight: _hourHeight,
              startHour: widget.startHour,
              endHour: widget.endHour,
              dayWidth: _dayWidth,
              dayCount: _virtualDayCount,
              lineColor: widget.gridLineColor,
              todayIndex: _indexFor(DateTime.now()),
            ),
          ),
        ),
        for (final event in timed)
          _buildEvent(
            event,
            layouts[event.id] ??
                const CalendarEventLayout(column: 0, columns: 1),
            current?.event.id == event.id ? current : null,
          ),
        if (_draft != null) _buildDraft(_draft!),
        if (_draft != null && _draftFormVisible) _buildDraftForm(_draft!),
      ],
    );
  }

  Widget _buildEvent(
    CalendarEvent<T> event,
    CalendarEventLayout layout,
    _EventInteraction<T>? interaction,
  ) {
    final displayStart = interaction?.start ?? event.start;
    final displayEnd = interaction?.end ?? event.end;
    final x =
        _indexFor(displayStart) * _dayWidth +
        3 +
        layout.leftFraction * (_dayWidth - 6);
    final y =
        ((displayStart.hour * 60 +
                    displayStart.minute -
                    widget.startHour * 60) /
                60) *
            _hourHeight +
        2;
    final height = math.max(
      22.0,
      displayEnd.difference(displayStart).inMinutes / 60 * _hourHeight - 3,
    );
    final width = math.max(18.0, (_dayWidth - 8) * layout.widthFraction);
    return Positioned(
      left: x,
      top: y,
      width: width,
      height: height,
      child: _CalendarEventSurface<T>(
        event: event,
        selected: _selectedId == event.id,
        child:
            widget.eventBuilder?.call(context, event, layout) ??
            _DefaultEvent(event: event),
        onTap: () {
          setState(() => _selectedId = event.id);
          widget.onEventTapped?.call(event);
        },
        onContextMenu: (position) => _openContextMenu(event, position),
        onMoveStart: (position) => _startInteraction(event, position, false),
        onResizeStart: (position) => _startInteraction(event, position, true),
        onUpdate: _updateInteraction,
        onEnd: _endInteraction,
      ),
    );
  }

  Widget _buildDraft(CalendarDraftEvent draft) {
    final x = _indexFor(draft.start) * _dayWidth + 4;
    final y =
        ((draft.start.hour * 60 + draft.start.minute - widget.startHour * 60) /
            60) *
        _hourHeight;
    final height = math.max(22.0, draft.duration.inMinutes / 60 * _hourHeight);
    return Positioned(
      left: x,
      top: y,
      width: _dayWidth - 8,
      height: height,
      child: IgnorePointer(
        child:
            widget.ghostBuilder?.call(context, draft) ??
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0x5575A7FF),
                borderRadius: BorderRadius.all(Radius.circular(6)),
              ),
            ),
      ),
    );
  }

  Widget _buildDraftForm(CalendarDraftEvent draft) {
    final form = widget.createEventFormBuilder;
    if (form == null) return const SizedBox.shrink();
    final x = _indexFor(draft.start) * _dayWidth + _dayWidth + 10;
    final y =
        ((draft.start.hour * 60 + draft.start.minute - widget.startHour * 60) /
            60) *
        _hourHeight;
    return Positioned(
      left: x,
      top: y,
      width: 280,
      child: Material(
        type: MaterialType.transparency,
        child: form(context, draft, _dismissDraft),
      ),
    );
  }
}

class _EventInteraction<T> {
  const _EventInteraction({
    required this.event,
    required this.startGlobal,
    required this.resizing,
    this.start,
    this.end,
  });
  final CalendarEvent<T> event;
  final Offset startGlobal;
  final bool resizing;
  final DateTime? start;
  final DateTime? end;
  _EventInteraction<T> copyWith({DateTime? start, DateTime? end}) =>
      _EventInteraction(
        event: event,
        startGlobal: startGlobal,
        resizing: resizing,
        start: start ?? this.start,
        end: end ?? this.end,
      );
}

class _CalendarEventSurface<T> extends StatelessWidget {
  const _CalendarEventSurface({
    required this.event,
    required this.child,
    required this.selected,
    required this.onTap,
    required this.onContextMenu,
    required this.onMoveStart,
    required this.onResizeStart,
    required this.onUpdate,
    required this.onEnd,
  });
  final CalendarEvent<T> event;
  final Widget child;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<Offset> onContextMenu;
  final ValueChanged<Offset> onMoveStart;
  final ValueChanged<Offset> onResizeStart;
  final ValueChanged<DragUpdateDetails> onUpdate;
  final VoidCallback onEnd;
  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.grab,
    child: Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onTap,
            onSecondaryTapDown: (d) => onContextMenu(d.globalPosition),
            onPanStart: (d) => onMoveStart(d.globalPosition),
            onPanUpdate: onUpdate,
            onPanEnd: (_) => onEnd(),
            child: DecoratedBox(
              decoration: selected
                  ? BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    )
                  : const BoxDecoration(),
              child: child,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeUpDown,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) => onResizeStart(d.globalPosition),
              onPanUpdate: onUpdate,
              onPanEnd: (_) => onEnd(),
              child: const SizedBox(height: 10, width: double.infinity),
            ),
          ),
        ),
      ],
    ),
  );
}

class _DefaultEvent<T> extends StatelessWidget {
  const _DefaultEvent({required this.event});
  final CalendarEvent<T> event;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Text(
        event.data.toString(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

class _TimeRuler extends StatelessWidget {
  const _TimeRuler({
    required this.hourHeight,
    required this.startHour,
    required this.endHour,
    required this.builder,
  });
  final double hourHeight;
  final int startHour;
  final int endHour;
  final CalendarTimeLabelBuilder? builder;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: (endHour - startHour) * hourHeight,
    child: Stack(
      children: [
        for (var hour = startHour; hour <= endHour; hour++)
          Positioned(
            top: hourHeight * (hour - startHour) - 7,
            right: 8,
            child:
                builder?.call(context, hour) ??
                Text(
                  '${hour.toString().padLeft(2, '0')}:00',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
          ),
      ],
    ),
  );
}

class _DayHeaderColumn<T> extends StatelessWidget {
  const _DayHeaderColumn({
    required this.left,
    required this.width,
    required this.date,
    required this.allDayHeight,
    required this.events,
    required this.dayHeaderBuilder,
    required this.allDayBuilder,
  });
  final double left;
  final double width;
  final DateTime date;
  final double allDayHeight;
  final List<CalendarEvent<T>> events;
  final CalendarDayHeaderBuilder? dayHeaderBuilder;
  final CalendarAllDayEventBuilder<T>? allDayBuilder;
  @override
  Widget build(BuildContext context) {
    final today = _isSameDay(date, DateTime.now());
    return Positioned(
      left: left,
      width: width,
      top: 0,
      bottom: 0,
      child: Column(
        children: [
          SizedBox(
            height: 62,
            child:
                dayHeaderBuilder?.call(context, date, today) ??
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        MaterialLocalizations.of(
                          context,
                        ).narrowWeekdays[date.weekday % 7].toUpperCase(),
                      ),
                      const SizedBox(height: 3),
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: today
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        child: Text('${date.day}'),
                      ),
                    ],
                  ),
                ),
          ),
          if (allDayHeight > 0)
            SizedBox(
              height: allDayHeight,
              child: Column(
                children: events
                    .take(3)
                    .map(
                      (event) => SizedBox(
                        height: 24,
                        child:
                            allDayBuilder?.call(context, event) ??
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: Text(
                                  event.data.toString(),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _occupiesDay<T>(CalendarEvent<T> event, DateTime day) {
  final start = _dateOnly(event.start);
  final end = _dateOnly(event.end);
  return !day.isBefore(start) && (end == start || day.isBefore(end));
}
