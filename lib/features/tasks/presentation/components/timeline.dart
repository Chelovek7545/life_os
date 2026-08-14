import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

const _orange = Color(0xFFFF5C00);

const _startHour = 0;
const _endHour = 24;

const _defaultHourHeight = 140.0;
const _minHourHeight = 40.0;
const _maxHourHeight = 240.0;

const _leftLabelWidth = 52.0;
const _minDayWidth = 150.0;

const _snapMinutes = 15;
const _resizeHandleHeight = 18.0;
const _minDurationMinutes = 15;

const _weekBufferDays = 7;
const _weekTotalDays = _weekBufferDays * 2 + 7;

class TaskEvent {
  const TaskEvent({
    required this.task,
    required this.title,
    required this.startMinutes,
    required this.durationMinutes,
    this.date,
    this.isCompleted = false,
    this.accentColor = const Color(0xFF2A2A2A),
  });

  final Task task;
  final String title;
  final int startMinutes;
  final int durationMinutes;
  final DateTime? date;
  final bool isCompleted;
  final Color accentColor;

  int get endMinutes => startMinutes + durationMinutes;

  TimeOfDay get startTime => TimeOfDay(
        hour: (startMinutes ~/ 60) % 24,
        minute: startMinutes % 60,
      );

  TimeOfDay get endTime => TimeOfDay(
        hour: (endMinutes ~/ 60) % 24,
        minute: endMinutes % 60,
      );

  TaskEvent copyWith({
    int? startMinutes,
    int? durationMinutes,
    bool? isCompleted,
    DateTime? date,
  }) {
    return TaskEvent(
      task: task,
      title: title,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      accentColor: accentColor,
    );
  }
}

class TimelineBody extends StatefulWidget {
  const TimelineBody({
    super.key,
    required this.events,
    required this.onEventChanged,
    required this.onToggleTask,
    required this.topPadding,
    this.weekStart,
    this.anchorDate,
    this.onWeekChange,
  });

  final List<TaskEvent> events;
  final double topPadding;
  final DateTime? weekStart;
  final DateTime? anchorDate;
  final ValueChanged<DateTime>? onWeekChange;
  final void Function(
    Task task, {
    int? startMinutes,
    int? durationMinutes,
    DateTime? newDate,
  }) onEventChanged;
  final void Function(Task task) onToggleTask;

  @override
  State<TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<TimelineBody>
    with SingleTickerProviderStateMixin {
  static const _totalMinutes = (_endHour - _startHour) * 60;

  double _hourHeight = _defaultHourHeight;

  double get _totalHeight => (_endHour - _startHour) * _hourHeight;

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  late List<Widget> _hourRows;

  final Map<int, Offset> _pinchPointers = {};
  double _pinchStartDistance = 0;
  double _pinchStartHeight = _defaultHourHeight;
  bool _pinching = false;

  bool _panZooming = false;
  double _panZoomStartHeight = _defaultHourHeight;

  String? _draggingId;
  double _dragStartDy = 0;
  double _dragStartDx = 0;
  int _dragStartMinutes = 0;

  String? _resizingId;
  double _resizeStartDy = 0;
  int _resizeStartDuration = 0;

  int? _ghostStart;
  int? _ghostDuration;
  int _ghostDayOffset = 0;

  double _lastColumnWidth = 0;

  bool _needsHorizontalReset = true;
  bool _scheduledHorizontalReset = false;
  DateTime? _lastWeekChangeRequest;

  Timer? _panZoomSafetyTimer;

  double _lastViewportWidth = 0;

DateTime? _pendingLeftDate;
double _pendingLeftFraction = 0;

  bool _isWeekSwitching = false;
bool _weekSwitchHideScheduled = false;

final GlobalKey _verticalScrollKey = GlobalKey();

late final AnimationController _zoomAnimationController;

double _zoomFromHeight = _defaultHourHeight;
double _zoomTargetHeight = _defaultHourHeight;
double? _zoomFocalLocalDy;

@override
void initState() {
  super.initState();

  final initialOffset = math.max(
    0.0,
    DateTime.now().hour * _defaultHourHeight - 120.0,
  );

  _verticalController = ScrollController(initialScrollOffset: initialOffset);
  _horizontalController = ScrollController();

  _hourRows = _buildHourRows();

  _zoomAnimationController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  _zoomAnimationController.addListener(() {
    final t = Curves.easeOutCubic.transform(_zoomAnimationController.value);
    final height =
        _zoomFromHeight + (_zoomTargetHeight - _zoomFromHeight) * t;

    _applyHourHeight(height, focalLocalDy: _zoomFocalLocalDy);
  });

  _needsHorizontalReset = true;
  _scheduleHorizontalReset();
}
@override
void didUpdateWidget(covariant TimelineBody oldWidget) {
  super.didUpdateWidget(oldWidget);

  if (widget.weekStart != oldWidget.weekStart) {
    final wasScrollDrivenChange = _lastWeekChangeRequest != null;

    _lastWeekChangeRequest = null;

    double target;

    if (wasScrollDrivenChange &&
        widget.weekStart != null &&
        _pendingLeftDate != null &&
        _lastColumnWidth > 0) {
      final newVisibleStart = _visibleStart(widget.weekStart!);

      final baseIndex = _daysBetween(newVisibleStart, _pendingLeftDate!);
      final dayOffset = baseIndex + _pendingLeftFraction;

      target = dayOffset * _lastColumnWidth;
    } else {
      target = _weekBufferDays * _lastColumnWidth;

      _pendingLeftDate = null;
      _pendingLeftFraction = 0;
    }

    if (wasScrollDrivenChange) {
      _isWeekSwitching = true;

      if (!_weekSwitchHideScheduled) {
        _weekSwitchHideScheduled = true;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _weekSwitchHideScheduled = false;

          if (mounted && _isWeekSwitching) {
            setState(() {
              _isWeekSwitching = false;
            });
          }
        });
      }
    }

    if (widget.weekStart != null &&
        _horizontalController.hasClients &&
        _lastColumnWidth > 0) {
      final position = _horizontalController.position;

      final maxExtent = position.hasContentDimensions
          ? position.maxScrollExtent
          : double.infinity;

      final clampedMax =
          maxExtent.isFinite ? math.max(0.0, maxExtent) : target;

      position.correctPixels(
        target.clamp(0.0, clampedMax).toDouble(),
      );
    }

    _needsHorizontalReset = true;
    _scheduleHorizontalReset();
  }
}

@override
void dispose() {
  _panZoomSafetyTimer?.cancel();
  _zoomAnimationController.dispose();
  _verticalController.dispose();
  _horizontalController.dispose();
  super.dispose();
}

bool get _isInteracting =>
    _draggingId != null ||
    _resizingId != null ||
    _pinching ||
    _panZooming ||
    _zoomAnimationController.isAnimating;
void _scheduleHorizontalReset() {
  if (_scheduledHorizontalReset) return;

  _scheduledHorizontalReset = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _scheduledHorizontalReset = false;

    if (!mounted) return;
    if (!_needsHorizontalReset) return;
    if (!_horizontalController.hasClients || _lastColumnWidth <= 0) return;

    double target;
    final weekStart = widget.weekStart;

    if (weekStart != null && _pendingLeftDate != null) {
      final visibleStart = _visibleStart(weekStart);

      final baseIndex = _daysBetween(visibleStart, _pendingLeftDate!);
      final dayOffset = baseIndex + _pendingLeftFraction;

      target = dayOffset * _lastColumnWidth;
    } else {
      target = _weekBufferDays * _lastColumnWidth;
    }

    final maxExtent = _horizontalController.position.maxScrollExtent;
    final clampedMax = maxExtent.isFinite ? math.max(0.0, maxExtent) : target;

    _horizontalController.jumpTo(
      target.clamp(0.0, clampedMax).toDouble(),
    );

    _pendingLeftDate = null;
    _pendingLeftFraction = 0;
    _needsHorizontalReset = false;
  });
}

  Map<String, _EventLayoutInfo> _computeLayout(List<TaskEvent> events) {
    if (events.isEmpty) return const {};

    final originalStartById = <String, int>{
      for (final event in widget.events) event.task.id: event.startMinutes,
    };

    final sorted = List<TaskEvent>.of(events)
      ..sort((a, b) {
        final startA = originalStartById[a.task.id] ?? a.startMinutes;
        final startB = originalStartById[b.task.id] ?? b.startMinutes;

        final startCompare = startA.compareTo(startB);
        if (startCompare != 0) return startCompare;

        return a.endMinutes.compareTo(b.endMinutes);
      });

    final clusters = <List<TaskEvent>>[];
    var currentCluster = <TaskEvent>[];
    int? clusterEndMinutes;

    for (final event in sorted) {
      if (currentCluster.isEmpty) {
        currentCluster = [event];
        clusterEndMinutes = event.endMinutes;
        continue;
      }

      if (event.startMinutes < clusterEndMinutes!) {
        currentCluster.add(event);
        clusterEndMinutes = event.endMinutes > clusterEndMinutes
            ? event.endMinutes
            : clusterEndMinutes;
      } else {
        clusters.add(currentCluster);
        currentCluster = [event];
        clusterEndMinutes = event.endMinutes;
      }
    }

    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final layout = <String, _EventLayoutInfo>{};

    for (final cluster in clusters) {
      final columns = <List<TaskEvent>>[];

      for (final event in cluster) {
        final columnIndex = columns.indexWhere(
          (column) => column.last.endMinutes <= event.startMinutes,
        );

        if (columnIndex == -1) {
          columns.add([event]);
        } else {
          columns[columnIndex].add(event);
        }
      }

      final totalColumns = columns.length;

      for (var index = 0; index < totalColumns; index++) {
        for (final event in columns[index]) {
          layout[event.task.id] = _EventLayoutInfo(
            index / totalColumns,
            1 / totalColumns,
          );
        }
      }
    }

    return layout;
  }

  Map<String, _EventLayoutInfo> _computeWeekLayout(
    List<TaskEvent> events,
    DateTime weekStart,
  ) {
    if (events.isEmpty) return const {};

    final visibleStart = _visibleStart(weekStart);
    final visibleEnd = _visibleEnd(weekStart);

    final byDay = <int, List<TaskEvent>>{};

    for (final event in events) {
      final date = event.date;
      if (date == null) continue;

      final day = _dateOnly(date);
      if (day.isBefore(visibleStart) || day.isAfter(visibleEnd)) continue;

      final dayIndex = _daysBetween(visibleStart, day);
      byDay.putIfAbsent(dayIndex, () => []).add(event);
    }

    final layout = <String, _EventLayoutInfo>{};

    for (final dayEvents in byDay.values) {
      layout.addAll(_computeLayout(dayEvents));
    }

    return layout;
  }

  ScrollPhysics _verticalPhysics() {
    return _isInteracting
        ? const NeverScrollableScrollPhysics()
        : const ClampingScrollPhysics();
  }

  ScrollPhysics _horizontalPhysics(double itemExtent) {
    if (_isInteracting || itemExtent <= 0) {
      return const NeverScrollableScrollPhysics();
    }

    return _DaySnapScrollPhysics(
      itemExtent: itemExtent,
      parent: const ClampingScrollPhysics(),
    );
  }


void _zoomIn() => _animateZoom(_hourHeight * 1.2);

void _zoomOut() => _animateZoom(_hourHeight / 1.2);

void _animateZoom(double target) {
  final clamped = target.clamp(_minHourHeight, _maxHourHeight).toDouble();

  if (clamped == _hourHeight) return;

  _zoomFromHeight = _hourHeight;
  _zoomTargetHeight = clamped;
  _zoomFocalLocalDy = _currentViewportCenterLocalDy();

  _zoomAnimationController.forward(from: 0.0);
}

double? _currentViewportCenterLocalDy() {
  if (!_verticalController.hasClients) return null;

  final position = _verticalController.position;

  if (!position.hasViewportDimension) return null;

  final viewport = position.viewportDimension;

  if (!viewport.isFinite || viewport <= 0) return null;

  return viewport / 2;
}

double? _verticalFocalLocalDy(double globalDy) {
  final context = _verticalScrollKey.currentContext;
  if (context == null) return null;

  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox) return null;

  final localDy = renderObject.globalToLocal(Offset(0, globalDy)).dy;

  if (!_verticalController.hasClients) return math.max(0.0, localDy);

  final position = _verticalController.position;

  if (!position.hasViewportDimension) return math.max(0.0, localDy);

  final viewport = position.viewportDimension;

  if (!viewport.isFinite || viewport <= 0) {
    return math.max(0.0, localDy);
  }

  return localDy.clamp(0.0, viewport).toDouble();
}

void _applyHourHeight(
  double value, {
  double? focalLocalDy,
}) {
  final clamped = value.clamp(_minHourHeight, _maxHourHeight).toDouble();

  if (clamped == _hourHeight) return;

  final oldHeight = _hourHeight;

  final topInset = widget.weekStart == null ? widget.topPadding : 0.0;

  ScrollPosition? position;
  double? targetPixels;

  if (_verticalController.hasClients) {
    position = _verticalController.position;

    if (position.hasPixels) {
      final viewport = position.hasViewportDimension
          ? position.viewportDimension
          : 0.0;

      final focal = focalLocalDy ??
          (viewport.isFinite && viewport > 0 ? viewport / 2 : 0.0);

      final focalContent = position.pixels + focal;
      final focalGrid = math.max(0.0, focalContent - topInset);

      final focalMinutes = focalGrid / oldHeight * 60.0;

      targetPixels = focalMinutes / 60.0 * clamped + topInset - focal;
    }
  }

  setState(() {
    _hourHeight = clamped;
    _hourRows = _buildHourRows();
  });

  if (position != null && targetPixels != null) {
    final viewport = position.hasViewportDimension
        ? position.viewportDimension
        : 0.0;

    double maxExtent;

    if (viewport.isFinite && viewport > 0) {
      final contentHeight =
          (_endHour - _startHour) * clamped + 24.0 + topInset;

      maxExtent = math.max(0.0, contentHeight - viewport);
    } else {
      maxExtent = position.hasContentDimensions
          ? math.max(0.0, position.maxScrollExtent)
          : 0.0;
    }

    position.correctPixels(
      targetPixels.clamp(0.0, maxExtent).toDouble(),
    );
  }
}
void _handlePinchPointerDown(PointerDownEvent event) {
  _pinchPointers[event.pointer] = event.position;

  if (_pinchPointers.length == 2) {
    _zoomAnimationController.stop();

    final positions = _pinchPointers.values.toList();
    _pinchStartDistance = (positions[0] - positions[1]).distance;
    _pinchStartHeight = _hourHeight;

    setState(() => _pinching = true);
  }
}

void _handlePinchPointerMove(PointerMoveEvent event) {
  if (!_pinchPointers.containsKey(event.pointer)) return;

  _pinchPointers[event.pointer] = event.position;

  if (_pinchPointers.length < 2 || _pinchStartDistance <= 0) return;
  if (_draggingId != null || _resizingId != null) return;

  final positions = _pinchPointers.values.toList();
  final distance = (positions[0] - positions[1]).distance;
  final scale = distance / _pinchStartDistance;

  final focalGlobalDy = (positions[0].dy + positions[1].dy) / 2.0;
  final focalLocalDy = _verticalFocalLocalDy(focalGlobalDy);

  _applyHourHeight(
    _pinchStartHeight * scale,
    focalLocalDy: focalLocalDy,
  );
}

  void _handlePinchPointerUp(PointerUpEvent event) {
    _pinchPointers.remove(event.pointer);

    if (_pinchPointers.length < 2 && _pinching) {
      setState(() => _pinching = false);
    }
  }

void _handlePinchPointerCancel(PointerCancelEvent event) {
  _pinchPointers.remove(event.pointer);

  if (_pinchPointers.length < 2 && _pinching) {
    setState(() => _pinching = false);
  }

  if (_panZooming) {
    setState(() => _panZooming = false);
  }
}

void _armPanZoomSafetyReset() {
  _panZoomSafetyTimer?.cancel();
  _panZoomSafetyTimer = Timer(const Duration(milliseconds: 350), () {
    if (!mounted) return;

    if (_panZooming) {
      setState(() => _panZooming = false);
    }
  });
}

void _handlePanZoomStart(PointerPanZoomStartEvent event) {
  _zoomAnimationController.stop();
  _panZoomStartHeight = _hourHeight;
  _armPanZoomSafetyReset();
}

void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
  if (event.scale <= 0) return;

  final shouldZoom = (event.scale - 1.0).abs() > 0.005 || _panZooming;
  if (!shouldZoom) return;

  if (!_panZooming) {
    setState(() {
      _panZooming = true;

      // Это убирает первый резкий скачок:
      // текущий масштаб принимаем как текущую высоту.
      _panZoomStartHeight = _hourHeight / event.scale;
    });
  }

  _armPanZoomSafetyReset();

  final focalLocalDy = _verticalFocalLocalDy(event.position.dy);

  _applyHourHeight(
    _panZoomStartHeight * event.scale,
    focalLocalDy: focalLocalDy,
  );
}
void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
  _panZoomSafetyTimer?.cancel();

  if (_panZooming) {
    setState(() => _panZooming = false);
  }
}

void _handlePointerSignal(PointerSignalEvent event) {
  if (event is! PointerScrollEvent) return;

  final pressed = HardwareKeyboard.instance.logicalKeysPressed;

  final hasZoomModifier =
      pressed.contains(LogicalKeyboardKey.controlLeft) ||
      pressed.contains(LogicalKeyboardKey.controlRight) ||
      pressed.contains(LogicalKeyboardKey.metaLeft) ||
      pressed.contains(LogicalKeyboardKey.metaRight);

  if (!hasZoomModifier || event.scrollDelta.dy == 0) return;

  _zoomAnimationController.stop();

  final factor = math.exp(-event.scrollDelta.dy / 240.0);
  final focalLocalDy = _verticalFocalLocalDy(event.position.dy);

  _applyHourHeight(
    _hourHeight * factor,
    focalLocalDy: focalLocalDy,
  );
}
  bool _handleHorizontalScrollNotification(ScrollNotification notification) {
    if (notification is ScrollEndNotification && !_isInteracting) {
      _maybeNotifyWeekChange(notification.metrics.pixels);
    }

    return false;
  }

void _maybeNotifyWeekChange(double offset) {
  final weekStart = widget.weekStart;
  final onWeekChange = widget.onWeekChange;

  if (weekStart == null || onWeekChange == null || _lastColumnWidth <= 0) {
    return;
  }

  final visibleStart = _visibleStart(weekStart);

  final viewportWidth = _lastViewportWidth > 0
      ? _lastViewportWidth
      : _lastColumnWidth * 7;

  final centerDayIndex = _clampInt(
    ((offset + viewportWidth / 2) / _lastColumnWidth).floor(),
    0,
    _weekTotalDays - 1,
  );

  final currentStart = _weekBufferDays;
  final currentEnd = _weekBufferDays + 6;

  // Если центр всё ещё внутри текущей недели — ничего не делаем.
  if (centerDayIndex >= currentStart && centerDayIndex <= currentEnd) {
    _lastWeekChangeRequest = null;
    _pendingLeftDate = null;
    _pendingLeftFraction = 0;
    return;
  }

  // Если центр ушёл в соседнюю неделю, просим родителя переключить неделю.
  final targetDate = centerDayIndex < currentStart
      ? _addDays(weekStart, -7)
      : _addDays(weekStart, 7);

  if (_lastWeekChangeRequest == targetDate) return;

  // Запоминаем текущую левую видимую позицию, чтобы после смены недели
  // не прыгнуть в начало, а остаться на том же месте.
  final firstDayIndex = _clampInt(
    (offset / _lastColumnWidth).floor(),
    0,
    _weekTotalDays - 1,
  );

  final fraction = (offset / _lastColumnWidth) - firstDayIndex;

  _pendingLeftDate = _addDays(visibleStart, firstDayIndex);
  _pendingLeftFraction = fraction;

  _needsHorizontalReset = true;
  _lastWeekChangeRequest = targetDate;

  onWeekChange(targetDate);
}
  void _onDragStart(TaskEvent event, DragStartDetails details) {
    HapticFeedback.lightImpact();

    setState(() {
      _draggingId = event.task.id;
      _dragStartDy = details.globalPosition.dy;
      _dragStartDx = details.globalPosition.dx;
      _dragStartMinutes = event.startMinutes;

      _ghostStart = event.startMinutes;
      _ghostDuration = event.durationMinutes;
      _ghostDayOffset = 0;
    });
  }

  void _onDragUpdate(TaskEvent event, DragUpdateDetails details) {
    final dyDelta = details.globalPosition.dy - _dragStartDy;
    final minutesDelta = (dyDelta / _hourHeight * 60.0).round();

    final minStart = _startHour * 60;
    final maxStart = _endHour * 60 - event.durationMinutes;

    final newStart = _clampInt(
      _snapToGrid(_dragStartMinutes + minutesDelta),
      minStart,
      math.max(minStart, maxStart),
    );

    var dayOffset = 0;

    final weekStart = widget.weekStart;
    final date = event.date;

    if (weekStart != null && date != null && _lastColumnWidth > 0) {
      final dxDelta = details.globalPosition.dx - _dragStartDx;
      final rawOffset = (dxDelta / _lastColumnWidth).round();

      final visibleStart = _visibleStart(weekStart);
      final visibleEnd = _visibleEnd(weekStart);

      final originalDay = _dateOnly(date);
      var targetDay = _addDays(originalDay, rawOffset);

      if (targetDay.isBefore(visibleStart)) targetDay = visibleStart;
      if (targetDay.isAfter(visibleEnd)) targetDay = visibleEnd;

      dayOffset = _daysBetween(originalDay, targetDay);
    }

    setState(() {
      _ghostStart = newStart;
      _ghostDayOffset = dayOffset;
    });
  }

  void _onDragEnd(TaskEvent event, DragEndDetails details) {
    final start = _ghostStart;
    final duration = _ghostDuration;

    if (start != null) {
      final date = event.date;

      if (date != null && _ghostDayOffset != 0) {
        widget.onEventChanged(
          event.task,
          startMinutes: start,
          durationMinutes: duration,
          newDate: _addDays(_dateOnly(date), _ghostDayOffset),
        );
      } else {
        widget.onEventChanged(
          event.task,
          startMinutes: start,
          durationMinutes: duration,
        );
      }
    }

    setState(() {
      _draggingId = null;
      _ghostStart = null;
      _ghostDuration = null;
      _ghostDayOffset = 0;
    });
  }

  void _onResizeStart(TaskEvent event, DragStartDetails details) {
    HapticFeedback.lightImpact();

    setState(() {
      _resizingId = event.task.id;
      _resizeStartDy = details.globalPosition.dy;
      _resizeStartDuration = event.durationMinutes;

      _ghostStart = event.startMinutes;
      _ghostDuration = event.durationMinutes;
    });
  }

  void _onResizeUpdate(TaskEvent event, DragUpdateDetails details) {
    final dyDelta = details.globalPosition.dy - _resizeStartDy;
    final minutesDelta = (dyDelta / _hourHeight * 60.0).round();

    final maxDuration = _endHour * 60 - event.startMinutes;

    final upperBound = math.max(
      _minDurationMinutes,
      math.min(maxDuration, _totalMinutes),
    );

    final newDuration = _clampInt(
      _snapToGrid(_resizeStartDuration + minutesDelta),
      _minDurationMinutes,
      upperBound,
    );

    setState(() => _ghostDuration = newDuration);
  }

  void _onResizeEnd(TaskEvent event, DragEndDetails details) {
    final duration = _ghostDuration;

    if (duration != null) {
      widget.onEventChanged(event.task, durationMinutes: duration);
    }

    setState(() {
      _resizingId = null;
      _ghostStart = null;
      _ghostDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1200.0;

        final displayEvents = widget.events.map((event) {
          final isInteracting =
              event.task.id == _draggingId || event.task.id == _resizingId;

          if (!isInteracting) return event;

          DateTime? displayDate = event.date;

          if (event.date != null &&
              _draggingId == event.task.id &&
              _ghostDayOffset != 0) {
            displayDate = _addDays(event.date!, _ghostDayOffset);
          }

          return event.copyWith(
            startMinutes: _ghostStart ?? event.startMinutes,
            durationMinutes: _ghostDuration ?? event.durationMinutes,
            date: displayDate,
          );
        }).toList(growable: false);

        final isWeekMode = widget.weekStart != null;

        if (isWeekMode) {
          final weekStart = widget.weekStart!;

          final viewportWidth = math.max(0.0, maxWidth - _leftLabelWidth);
final columnWidth = math.max(_minDayWidth, viewportWidth / 7.0);

final oldColumnWidth = _lastColumnWidth;
final oldViewportWidth = _lastViewportWidth;

final shouldRealignHorizontalOffset =
    !_needsHorizontalReset &&
    _pendingLeftDate == null &&
    _horizontalController.hasClients &&
    oldColumnWidth > 0 &&
    oldViewportWidth > 0 &&
    (columnWidth != oldColumnWidth || viewportWidth != oldViewportWidth);

if (shouldRealignHorizontalOffset) {
  final oldOffset = _horizontalController.position.pixels;

  final rawDayIndex = oldOffset / oldColumnWidth;

  // Если пользователь сейчас взаимодействует со скроллом,
  // сохраняем дробную позицию.
  // Иначе выравниваем по ближайшему дню.
  final alignedDayIndex = _isInteracting
      ? rawDayIndex
      : rawDayIndex.roundToDouble();

  final targetOffset = alignedDayIndex * columnWidth;

  final maxExtent = math.max(
    0.0,
    _weekTotalDays * columnWidth - viewportWidth,
  );

  _horizontalController.position.correctPixels(
    targetOffset.clamp(0.0, maxExtent).toDouble(),
  );
}

_lastColumnWidth = columnWidth;
_lastViewportWidth = viewportWidth;

          if (_needsHorizontalReset && !_scheduledHorizontalReset) {
            _scheduleHorizontalReset();
          }

          final layouts = _computeWeekLayout(displayEvents, weekStart);

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePinchPointerDown,
            onPointerMove: _handlePinchPointerMove,
            onPointerUp: _handlePinchPointerUp,
            onPointerCancel: _handlePinchPointerCancel,
            onPointerPanZoomStart: _handlePanZoomStart,
            onPointerPanZoomUpdate: _handlePanZoomUpdate,
            onPointerPanZoomEnd: _handlePanZoomEnd,
            //onPointerPanZoomCancel: _handlePanZoomCancel,
            onPointerSignal: _handlePointerSignal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _WeekGridHeader(
                  weekStart: weekStart,
                  anchorDate: widget.anchorDate ?? weekStart,
                  topPadding: widget.topPadding,
                  columnWidth: columnWidth,
                  horizontalController: _horizontalController,
                  onWeekChange: widget.onWeekChange,
                  onZoomIn: _zoomIn,
                  onZoomOut: _zoomOut,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    
  key: _verticalScrollKey,
                    controller: _verticalController,
                    physics: _verticalPhysics(),
                    child: SizedBox(
                      height: _totalHeight + 24,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: _leftLabelWidth,
                            height: _totalHeight + 24,
                            child: Stack(
                              children: _buildWeekHourLabels(),
                            ),
                          ),
                          Expanded(
                            child: NotificationListener<ScrollNotification>(
                              onNotification:
                                  _handleHorizontalScrollNotification,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                controller: _horizontalController,
                                physics: _horizontalPhysics(columnWidth),
                                child: SizedBox(
                                  width: _weekTotalDays * columnWidth,
                                  height: _totalHeight + 24,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ..._buildWeekColumnBackground(
                                        columnWidth,
                                        weekStart,
                                      ),
                                      ..._buildWeekHourGridlines(),
                                      ...widget.events.map((event) {
                                        final layout =
                                            layouts[event.task.id] ??
                                                const _EventLayoutInfo(0, 1);

                                        return _buildDraggableEvent(
                                          event,
                                          layout,
                                          viewportWidth,
                                          weekColumnWidth: columnWidth,
                                        );
                                      }),
                                      _buildWeekNowLine(
                                        weekStart,
                                        columnWidth,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final availableWidth = math.max(
          0.0,
          maxWidth - _leftLabelWidth - 24.0,
        );

        final layouts = _computeLayout(displayEvents);

        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePinchPointerDown,
          onPointerMove: _handlePinchPointerMove,
          onPointerUp: _handlePinchPointerUp,
          onPointerCancel: _handlePinchPointerCancel,
          onPointerPanZoomStart: _handlePanZoomStart,
          onPointerPanZoomUpdate: _handlePanZoomUpdate,
          onPointerPanZoomEnd: _handlePanZoomEnd,
          //onPointerPanZoomCancel: _handlePanZoomCancel,
          onPointerSignal: _handlePointerSignal,
          child: SingleChildScrollView(
            
  key: _verticalScrollKey,
            controller: _verticalController,
            physics: _verticalPhysics(),
            padding: EdgeInsets.only(top: widget.topPadding),
            child: SizedBox(
              height: _totalHeight + 24,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ..._hourRows,
                  ...widget.events.map((event) {
                    final layout =
                        layouts[event.task.id] ?? const _EventLayoutInfo(0, 1);

                    return _buildDraggableEvent(
                      event,
                      layout,
                      availableWidth,
                    );
                  }),
                  _buildNowLine(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildHourRows() {
    return List.generate(_endHour - _startHour + 1, (index) {
      final hour = _startHour + index;

      return Positioned(
        top: index * _hourHeight,
        left: 0,
        right: 0,
        child: Row(
          children: [
            SizedBox(
              width: _leftLabelWidth,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: ColoredBox(
                color: Color(0xFF2A2A2A),
                child: SizedBox(height: 1),
              ),
            ),
          ],
        ),
      );
    });
  }

  List<Widget> _buildWeekHourLabels() {
    return List.generate(_endHour - _startHour + 1, (index) {
      final hour = _startHour + index;

      return Positioned(
        top: index * _hourHeight,
        left: 0,
        right: 0,
        child: Text(
          '${hour.toString().padLeft(2, '0')}:00',
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
      );
    });
  }

  List<Widget> _buildWeekHourGridlines() {
    return List.generate(_endHour - _startHour + 1, (index) {
      return Positioned(
        top: index * _hourHeight,
        left: 0,
        right: 0,
        child: const ColoredBox(
          color: Color(0xFF2A2A2A),
          child: SizedBox(height: 1),
        ),
      );
    });
  }

  Color _weekColumnColor(DateTime date, bool isToday) {
    if (isToday) return const Color(0x14FFFFFF);

    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    if (isWeekend) return const Color(0x06FFFFFF);

    return Colors.transparent;
  }

  List<Widget> _buildWeekColumnBackground(
    double columnWidth,
    DateTime weekStart,
  ) {
    final visibleStart = _visibleStart(weekStart);
    final today = DateTime.now();
    final todayIndex = _daysBetween(visibleStart, today);

    return [
      for (var i = 0; i < _weekTotalDays; i++)
        Positioned(
          left: i * columnWidth,
          top: 0,
          bottom: 0,
          width: columnWidth,
          child: ColoredBox(
            color: _weekColumnColor(
              _addDays(visibleStart, i),
              i == todayIndex,
            ),
          ),
        ),
      for (var i = 1; i < _weekTotalDays; i++)
        Positioned(
          left: i * columnWidth - 0.5,
          top: 0,
          bottom: 0,
          width: 1,
          child: const ColoredBox(color: Color(0x14FFFFFF)),
        ),
    ];
  }

  Widget _buildNowLine({bool includeGutterOffset = true}) {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final y = (nowMinutes - _startHour * 60) / 60 * _hourHeight;

    return Positioned(
      top: y,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(
            width: includeGutterOffset ? _leftLabelWidth + 4 : 0,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: _orange,
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 10, height: 10),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 1.5),
              painter: const _DashedLinePainter(color: _orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNowLine(DateTime weekStart, double columnWidth) {
    final visibleStart = _visibleStart(weekStart);
    final now = DateTime.now();

    final todayIndex = _daysBetween(visibleStart, now);
    if (todayIndex < 0 || todayIndex >= _weekTotalDays) {
      return const SizedBox.shrink();
    }

    final nowMinutes = now.hour * 60 + now.minute;
    final y = (nowMinutes - _startHour * 60) / 60 * _hourHeight;

    return Positioned(
      top: y,
      left: todayIndex * columnWidth,
      width: columnWidth,
      child: Row(
        children: [
          const SizedBox(width: 6),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: _orange,
              shape: BoxShape.circle,
            ),
            child: SizedBox(width: 10, height: 10),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 1.5),
              painter: const _DashedLinePainter(color: _orange),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _buildDraggableEvent(
    TaskEvent event,
    _EventLayoutInfo layout,
    double availableWidth, {
    double? weekColumnWidth,
  }) {
    final isDragging = _draggingId == event.task.id;
    final isResizing = _resizingId == event.task.id;
    final isInteracting = isDragging || isResizing;

    final displayStart = isInteracting
        ? (_ghostStart ?? event.startMinutes)
        : event.startMinutes;

    final displayDuration = isInteracting
        ? (_ghostDuration ?? event.durationMinutes)
        : event.durationMinutes;

    final top = (displayStart - _startHour * 60) / 60 * _hourHeight;
    final rawHeight = displayDuration / 60 * _hourHeight;
    final visualHeight = math.max(30.0, rawHeight + 4.0);

    final isWeekMode = widget.weekStart != null;

    double eventLeft;
    double eventWidth;

    if (isWeekMode) {
      final columnWidth = weekColumnWidth ?? _lastColumnWidth;
      if (columnWidth <= 0) return const SizedBox.shrink();

      final date = event.date;
      if (date == null) return const SizedBox.shrink();

      final weekStart = widget.weekStart!;
      final visibleStart = _visibleStart(weekStart);

      final baseDayIndex = _daysBetween(visibleStart, date);
      final dayIndex =
          isDragging ? baseDayIndex + _ghostDayOffset : baseDayIndex;

      if (dayIndex < 0 || dayIndex >= _weekTotalDays) {
        return const SizedBox.shrink();
      }

      final innerLeft = dayIndex * columnWidth + 3;
      final innerWidth = math.max(0.0, columnWidth - 6);

      if (isDragging) {
        eventLeft = innerLeft + 1;
        eventWidth = math.max(18.0, innerWidth - 2)
            .clamp(0.0, innerWidth)
            .toDouble();
      } else {
        final slotWidth = innerWidth * layout.widthFactor;

        eventWidth = math.max(18.0, slotWidth - 2)
            .clamp(0.0, innerWidth)
            .toDouble();

        eventLeft = innerLeft +
            (innerWidth * layout.leftFactor).clamp(0.0, innerWidth).toDouble() +
            1;
      }
    } else {
      final eventWidthComputed = availableWidth * layout.widthFactor;

      eventWidth = isDragging
          ? availableWidth
          : math.max(0.0, eventWidthComputed - 4);

      eventLeft = isDragging
          ? _leftLabelWidth + 12
          : _leftLabelWidth + 12 + availableWidth * layout.leftFactor + 2;
    }

return Positioned(
  key: ValueKey(event.task.id),
  top: top + 2,
  left: eventLeft,
  width: eventWidth,
  height: visualHeight,
  child: AnimatedOpacity(
    duration: const Duration(milliseconds: 120),
    opacity: _isWeekSwitching ? 0.0 : (isDragging ? 0.8 : 1.0),
    child: _EventTile(
      event: event,
      height: visualHeight,
      isDragging: isDragging,
      isResizing: isResizing,
      onDragStart: (details) => _onDragStart(event, details),
      onDragUpdate: (details) => _onDragUpdate(event, details),
      onDragEnd: (details) => _onDragEnd(event, details),
      onResizeStart: (details) => _onResizeStart(event, details),
      onResizeUpdate: (details) => _onResizeUpdate(event, details),
      onResizeEnd: (details) => _onResizeEnd(event, details),
      onToggleTask: () => widget.onToggleTask(event.task),
      ghostStart: isInteracting ? _ghostStart : null,
      ghostDuration: isInteracting ? _ghostDuration : null,
    ),
  ),
);
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.height,
    required this.isDragging,
    required this.isResizing,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onResizeStart,
    required this.onResizeUpdate,
    required this.onResizeEnd,
    required this.onToggleTask,
    this.ghostStart,
    this.ghostDuration,
  });

  final TaskEvent event;
  final double height;
  final bool isDragging;
  final bool isResizing;

  final ValueChanged<DragStartDetails> onDragStart;
  final ValueChanged<DragUpdateDetails> onDragUpdate;
  final ValueChanged<DragEndDetails> onDragEnd;

  final ValueChanged<DragStartDetails> onResizeStart;
  final ValueChanged<DragUpdateDetails> onResizeUpdate;
  final ValueChanged<DragEndDetails> onResizeEnd;

  final VoidCallback onToggleTask;

  final int? ghostStart;
  final int? ghostDuration;

  TimeOfDay _minutesToTime(int minutes) {
    return TimeOfDay(
      hour: (minutes ~/ 60) % 24,
      minute: minutes % 60,
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = event.accentColor;
    final isInteracting = isDragging || isResizing;

    final start = ghostStart == null
        ? event.startTime
        : _minutesToTime(ghostStart!);

    final TimeOfDay end;

    if (ghostStart != null && ghostDuration != null) {
      end = _minutesToTime(ghostStart! + ghostDuration!);
    } else if (ghostDuration != null) {
      end = _minutesToTime(event.startMinutes + ghostDuration!);
    } else {
      end = event.endTime;
    }

    final borderRadius = BorderRadius.circular(14);

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: onDragStart,
          onPanUpdate: onDragUpdate,
          onPanEnd: onDragEnd,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.fromLTRB(20, 2, 10, 2),
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      if (event.isCompleted)
                        Colors.white.withOpacity(0.05)
                      else
                        accent.withOpacity(0.22),
                      Colors.white.withOpacity(0.05),
                      Colors.black.withOpacity(0.10),
                    ],
                  ),
                  border: Border.all(
                    color: isInteracting
                        ? accent.withOpacity(0.95)
                        : Colors.white.withOpacity(
                            event.isCompleted ? 0.08 : 0.14,
                          ),
                    width: isInteracting ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        isInteracting ? 0.35 : 0.18,
                      ),
                      blurRadius: isInteracting ? 22 : 10,
                      offset: const Offset(0, 8),
                    ),
                    if (isInteracting)
                      BoxShadow(
                        color: accent.withOpacity(0.25),
                        blurRadius: 18,
                      ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final showTitle = height > 34 && constraints.maxWidth > 40;
                    final showTime = height > 54 && constraints.maxWidth > 70;
                    final showDragHandle =
                        height > 36 && constraints.maxWidth > 88;

                    return Row(
                      children: [
                        CheckDot(
                          isCompleted: event.isCompleted,
                          onCheckChanged: onToggleTask,
                          isSelected: false,
                          isOverdue: false,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showTitle)
                                Text(
                                  event.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    decoration: event.isCompleted
                                        ? TextDecoration.lineThrough
                                        : TextDecoration.none,
                                    decorationColor: accent.withOpacity(0.8),
                                    decorationThickness: 1.6,
                                    color: event.isCompleted
                                        ? Colors.white.withOpacity(0.65)
                                        : Colors.white,
                                    fontWeight: event.isCompleted
                                        ? FontWeight.w400
                                        : FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              if (showTime) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '${_formatTime(start)} - ${_formatTime(end)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(
                                      isInteracting ? 0.8 : 0.55,
                                    ),
                                    fontSize: 11.5,
                                    fontWeight: isInteracting
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (showDragHandle)
                          const Icon(
                            Icons.drag_indicator,
                            color: Colors.white24,
                            size: 16,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _resizeHandleHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: onResizeStart,
            onVerticalDragUpdate: onResizeUpdate,
            onVerticalDragEnd: onResizeEnd,
            child: Container(
              color: Colors.transparent,
              alignment: Alignment.center,
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    isInteracting ? 0.55 : 0.16,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          bottom: 8,
          left: 6,
          child: IgnorePointer(
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: event.isCompleted ? accent.withOpacity(0.45) : accent,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekGridHeader extends StatelessWidget {
  const _WeekGridHeader({
    required this.weekStart,
    required this.anchorDate,
    required this.topPadding,
    required this.columnWidth,
    required this.horizontalController,
    required this.onZoomIn,
    required this.onZoomOut,
    this.onWeekChange,
  });

  final DateTime weekStart;
  final DateTime anchorDate;
  final double topPadding;
  final double columnWidth;
  final ScrollController horizontalController;
  final ValueChanged<DateTime>? onWeekChange;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: anchorDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2140),
    );

    if (date != null) {
      onWeekChange?.call(date);
    }
  }

  Widget _glassIconButton(
    IconData icon,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Tooltip(
      message: tooltip,
      child: _GlassBox(
        borderRadius: 999,
        child: Material(
          color: Colors.transparent,
          child: IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            icon: Icon(icon, color: Colors.white70, size: 20),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final weekEnd = _addDays(weekStart, 6);
    final visibleStart = _addDays(weekStart, -_weekBufferDays);

    final hasNav = onWeekChange != null;

    final isCurrentWeek = _isSameDay(today, weekStart) ||
        _isSameDay(today, weekEnd) ||
        (today.isAfter(weekStart) && today.isBefore(weekEnd));

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          color: AppColors.surfaceDim.withOpacity(0.55),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: topPadding),
              if (hasNav)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Center(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _glassIconButton(
                            Icons.chevron_left,
                            'Previous week',
                            () => onWeekChange!(_addDays(weekStart, -7)),
                          ),
                          const SizedBox(width: 10),
                          _GlassBox(
                            borderRadius: 999,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => _pickDate(context),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        transitionBuilder:
                                            (child, animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: SizeTransition(
                                              sizeFactor: animation,
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: isCurrentWeek
                                            ? Text(
                                                'THIS WEEK',
                                                key: const ValueKey(
                                                  'this_week_text',
                                                ),
                                                style: AppTypography.codeLabel,
                                              )
                                            : const SizedBox.shrink(
                                                key: ValueKey('empty_space'),
                                              ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_twoDigit(weekStart.day)}.${_twoDigit(weekStart.month)} '
                                        '– '
                                        '${_twoDigit(weekEnd.day)}.${_twoDigit(weekEnd.month)}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _glassIconButton(
                            Icons.chevron_right,
                            'Next week',
                            () => onWeekChange!(_addDays(weekStart, 7)),
                          ),
                          const SizedBox(width: 12),
                          _glassIconButton(
                            Icons.remove,
                            'Zoom out',
                            onZoomOut,
                          ),
                          const SizedBox(width: 6),
                          _glassIconButton(
                            Icons.add,
                            'Zoom in',
                            onZoomIn,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
  padding: const EdgeInsets.only(
    left: _leftLabelWidth,
    right: 0,
    bottom: 10,
  ),
  child: SizedBox(
    height: 58,
    child: ClipRect(
      child: AnimatedBuilder(
        animation: horizontalController,
        builder: (context, child) {
          final offset = horizontalController.hasClients
              ? horizontalController.offset
              : _weekBufferDays * columnWidth;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              Positioned(
                left: -offset,
                top: 0,
                bottom: 0,
                width: _weekTotalDays * columnWidth,
                child: child!,
              ),
            ],
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_weekTotalDays, (index) {
            final date = _addDays(visibleStart, index);
            final isToday = _isSameDay(date, today);
            final isAnchor = _isSameDay(date, anchorDate);
            final inCurrentWeek =
                index >= _weekBufferDays && index < _weekBufferDays + 7;

            return SizedBox(
              width: columnWidth,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: hasNav ? () => onWeekChange!(date) : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: inCurrentWeek
                          ? Colors.white.withOpacity(0.04)
                          : Colors.white.withOpacity(0.015),
                      borderRadius: BorderRadius.circular(12),
                      border: isAnchor
                          ? Border.all(
                              color: Colors.white.withOpacity(0.22),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              getWeekDayName(date.weekday).toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isToday
                                    ? _orange
                                    : Colors.white.withOpacity(0.55),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isToday
                                ? LinearGradient(
                                    colors: [
                                      _orange,
                                      _orange.withOpacity(0.85),
                                    ],
                                  )
                                : null,
                            boxShadow: isToday
                                ? [
                                    BoxShadow(
                                      color: _orange.withOpacity(0.35),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              color: isToday
                                  ? Colors.black
                                  : Colors.white.withOpacity(0.85),
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  ),
)],
          ),
        ),
      ),
    );
  }
}

class _GlassBox extends StatelessWidget {
  const _GlassBox({
    required this.child,
    this.borderRadius = 18,
    this.blur = 16,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double borderRadius;
  final double blur;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.10),
                Colors.white.withOpacity(0.04),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DaySnapScrollPhysics extends ScrollPhysics {
  const _DaySnapScrollPhysics({
    required this.itemExtent,
    ScrollPhysics? parent,
  }) : super(parent: parent);

  final double itemExtent;

  @override
  _DaySnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _DaySnapScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    if (itemExtent <= 0) return position.pixels;

    double page = position.pixels / itemExtent;

    if (velocity < -tolerance.velocity) {
      page = page.floorToDouble();
    } else if (velocity > tolerance.velocity) {
      page = page.ceilToDouble();
    } else {
      page = page.roundToDouble();
    }

    return (page * itemExtent).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (itemExtent <= 0 || position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    const tolerance = Tolerance.defaultTolerance;
    final target = _getTargetPixels(position, tolerance, velocity);

    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }

    return super.createBallisticSimulation(position, velocity);
  }

  @override
  bool get allowImplicitScrolling => true;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({required this.color});

  final Color color;

  static const _dashWidth = 6.0;
  static const _dashGap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(150)
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    var startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(
          (startX + _dashWidth).clamp(0.0, size.width),
          size.height / 2,
        ),
        paint,
      );

      startX += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class _EventLayoutInfo {
  const _EventLayoutInfo(this.leftFactor, this.widthFactor);

  final double leftFactor;
  final double widthFactor;
}

int _snapToGrid(int minutes) {
  return (minutes / _snapMinutes).round() * _snapMinutes;
}

int _clampInt(int value, int min, int max) {
  if (max < min) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

DateTime _addDays(DateTime date, int days) {
  return DateTime(date.year, date.month, date.day + days);
}

int _daysBetween(DateTime a, DateTime b) {
  final au = DateTime.utc(a.year, a.month, a.day);
  final bu = DateTime.utc(b.year, b.month, b.day);
  return bu.difference(au).inDays;
}

DateTime _visibleStart(DateTime weekStart) {
  return _addDays(_dateOnly(weekStart), -_weekBufferDays);
}

DateTime _visibleEnd(DateTime weekStart) {
  return _addDays(_visibleStart(weekStart), _weekTotalDays - 1);
}

String _formatTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';

  return '$hour:$minute $period';
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _twoDigit(int value) => value.toString().padLeft(2, '0');