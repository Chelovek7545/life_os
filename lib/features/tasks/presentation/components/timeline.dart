import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/fixed_fade_mask.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

import 'mini_task_form.dart';

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

const _minDayWidthScale = 0.5;
const _maxDayWidthScale = 3.0;

const _kDraftFormWidth = 260.0;
const _kDraftFormHeight = 170.0;

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

  TimeOfDay get startTime =>
      TimeOfDay(hour: (startMinutes ~/ 60) % 24, minute: startMinutes % 60);

  TimeOfDay get endTime =>
      TimeOfDay(hour: (endMinutes ~/ 60) % 24, minute: endMinutes % 60);

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
    this.taskFormProjects,
    this.onSubmitNewTask,
  });

  final List<TaskEvent> events;
  final double topPadding;
  final DateTime? weekStart;
  final DateTime? anchorDate;
  final ValueChanged<DateTime>? onWeekChange;
  final Stream<List<Project>>? taskFormProjects;
  final Future<void> Function(Task task)? onSubmitNewTask;
  final void Function(
    Task task, {
    int? startMinutes,
    int? durationMinutes,
    DateTime? newDate,
  })
  onEventChanged;
  final void Function(Task task) onToggleTask;

  @override
  State<TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<TimelineBody>
    with SingleTickerProviderStateMixin {
  static const _totalMinutes = (_endHour - _startHour) * 60;

  // Width-only pinch (для шапки дней)
  final Map<int, Offset> _widthPinchPointers = {};
  double _widthPinchStartDistance = 0;
  double _widthPinchStartScale = 1.0;
  bool _widthPinching = false;

  // Width-only pan-zoom (для шапки дней)
  bool _widthPanZooming = false;
  double _widthPanZoomStartScale = 1.0;
  Timer? _widthPanZoomSafetyTimer;

  double _hourHeight = _defaultHourHeight;
  double get _totalHeight => (_endHour - _startHour) * _hourHeight;

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;
  final GlobalKey _verticalScrollKey = GlobalKey();

  // Pinch & Zoom State
  final Map<int, Offset> _pinchPointers = {};
  double _pinchStartDistance = 0;
  double _pinchStartHeight = _defaultHourHeight;
  bool _pinching = false;
  bool _panZooming = false;
  double _panZoomStartHeight = _defaultHourHeight;
  Timer? _panZoomSafetyTimer;
  late final AnimationController _zoomAnimationController;
  double _zoomFromHeight = _defaultHourHeight;
  double _zoomTargetHeight = _defaultHourHeight;
  double? _zoomFocalLocalDy;

  // Drag & Resize State
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

  // Layout Tracking (Для правильного ресайза)
  double _lastColumnWidth = 0;
  DateTime? _lastWeekStart;
  bool _pendingHeaderWeekChange = false;

  // Выделение области для создания новой задачи
  bool _isSelecting = false;
  int _selDayIndex = 0;
  int _selStartMinutes = 0;
  int _selEndMinutes = 0;
  bool _showDraftForm = false;
  double _lastMaxWidth = 0;
  double _lastDayViewWidth = 0;

  void _handleHeaderWeekChange(DateTime date) {
    _pendingHeaderWeekChange = true;
    widget.onWeekChange?.call(date);
  }

  // --- Создание задачи выделением области (long-press + drag) ---

  int _localDyToMinutes(double dy) {
    return (dy / _hourHeight * 60)
        .round()
        .clamp(_startHour * 60, _endHour * 60)
        .toInt();
  }

  Rect? _eventRect(TaskEvent event) {
    final top = (event.startMinutes - _startHour * 60) / 60 * _hourHeight;
    final height = math.max(
      30.0,
      event.durationMinutes / 60 * _hourHeight + 4.0,
    );
    if (widget.weekStart != null) {
      final date = event.date;
      if (date == null) return null;
      final visibleStart = _visibleStart(widget.weekStart!);
      final dayIndex = _daysBetween(visibleStart, date);
      if (dayIndex < 0 || dayIndex >= _weekTotalDays) return null;
      final colW = _lastColumnWidth;
      final innerLeft = dayIndex * colW + 3;
      final innerWidth = math.max(0.0, colW - 6);
      final width = math.max(18.0, innerWidth - 2);
      return Rect.fromLTWH(innerLeft + 1, top + 2, width, height);
    }
    final width = math.max(0.0, _lastDayViewWidth - 4);
    return Rect.fromLTWH(_leftLabelWidth + 12, top + 2, width, height);
  }

  bool _eventAt(Offset localPosition) {
    return widget.events.any(
      (event) => _eventRect(event)?.contains(localPosition) ?? false,
    );
  }

  Rect _selectionGhostRect() {
    final top = (_selStartMinutes - _startHour * 60) / 60 * _hourHeight;
    final height = math.max(
      30.0,
      (_selEndMinutes - _selStartMinutes) / 60 * _hourHeight + 4.0,
    );
    if (widget.weekStart != null) {
      final colW = _lastColumnWidth;
      final left = _selDayIndex * colW + 3;
      final width = math.max(0.0, colW - 6);
      return Rect.fromLTWH(left, top + 2, width, height);
    }
    final width = math.max(0.0, _lastDayViewWidth - 4);
    return Rect.fromLTWH(_leftLabelWidth + 12, top + 2, width, height);
  }

  void _onSelectionLongPressStart(LongPressStartDetails details) {
    if (_isInteracting || _showDraftForm) return;
    final pos = details.localPosition;
    if (_eventAt(pos)) return;
    final center =
        (_localDyToMinutes(pos.dy) / _snapMinutes).round() * _snapMinutes;
    final start = center
        .clamp(
          _startHour * 60,
          math.max(_startHour * 60, _endHour * 60 - _minDurationMinutes),
        )
        .toInt();
    final dayIndex = widget.weekStart != null
        ? (pos.dx / _lastColumnWidth)
              .floor()
              .clamp(0, _weekTotalDays - 1)
              .toInt()
        : 0;
    setState(() {
      _isSelecting = true;
      _selDayIndex = dayIndex;
      _selStartMinutes = start;
      _selEndMinutes = math.min(_endHour * 60, start + 60);
      _showDraftForm = false;
    });
  }

  void _onSelectionLongPressMove(LongPressMoveUpdateDetails details) {
    if (!_isSelecting) return;
    final end =
        (_localDyToMinutes(details.localPosition.dy) / _snapMinutes).round() *
        _snapMinutes;
    setState(() {
      _selEndMinutes = math.min(
        _endHour * 60,
        math.max(_selStartMinutes + _minDurationMinutes, end),
      );
    });
  }

  void _onSelectionLongPressEnd(LongPressEndDetails details) {
    if (!_isSelecting) return;
    setState(() {
      _isSelecting = false;
      _showDraftForm = true;
    });
  }

  DateTime _selectionStartDateTime() {
    final day = widget.weekStart != null
        ? _addDays(_visibleStart(widget.weekStart!), _selDayIndex)
        : _dateOnly(widget.anchorDate ?? DateTime.now());
    return DateTime(
      day.year,
      day.month,
      day.day,
      _selStartMinutes ~/ 60,
      _selStartMinutes % 60,
    );
  }

  void _clearDraftForm() {
    setState(() {
      _isSelecting = false;
      _showDraftForm = false;
      _selDayIndex = 0;
      _selStartMinutes = 0;
      _selEndMinutes = 0;
    });
  }

  Widget _buildSelectionGhost() {
    if (!_isSelecting && !_showDraftForm) return const SizedBox.shrink();
    final rect = _selectionGhostRect();
    final start = TimeOfDay(
      hour: (_selStartMinutes ~/ 60) % 24,
      minute: _selStartMinutes % 60,
    );
    final end = TimeOfDay(
      hour: (_selEndMinutes ~/ 60) % 24,
      minute: _selEndMinutes % 60,
    );
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            color: _orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _orange.withValues(alpha: 0.7)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                '${_formatTime(start)} – ${_formatTime(end)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftFormOverlay() {
    if (!_showDraftForm) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([
        _verticalController,
        _horizontalController,
      ]),
      builder: (context, _) {
        final ghost = _selectionGhostRect();
        final vOffset = _verticalController.hasClients
            ? _verticalController.offset
            : 0.0;
        final hOffset = _horizontalController.hasClients
            ? _horizontalController.offset
            : 0.0;
        final topPad = widget.weekStart == null ? widget.topPadding : 200.0;

        final ghostLeft = widget.weekStart == null
            ? ghost.left
            : _leftLabelWidth + ghost.left - hOffset;
        final ghostTop = topPad + ghost.top - vOffset;

        final double left = (ghostLeft + ghost.width + 12)
            .clamp(8.0, math.max(0.0, _lastMaxWidth - _kDraftFormWidth - 8))
            .toDouble();
        final maxTop = _verticalController.hasClients
            ? math.max(
                0.0,
                _verticalController.position.viewportDimension -
                    _kDraftFormHeight -
                    8,
              )
            : 0.0;
        final double top = ghostTop.clamp(8.0, maxTop).toDouble();

        final start = _selectionStartDateTime();
        final end = start.add(
          Duration(minutes: _selEndMinutes - _selStartMinutes),
        );

        return Positioned(
          left: left,
          top: top,
          child: MiniTaskForm(
            width: _kDraftFormWidth,
            start: start,
            end: end,
            projects: widget.taskFormProjects,
            onSubmit: (task) {
              widget.onSubmitNewTask?.call(task);
              _clearDraftForm();
            },
            onCancel: _clearDraftForm,
          ),
        );
      },
    );
  }

  bool get _isInteracting =>
      _draggingId != null ||
      _resizingId != null ||
      _pinching ||
      _panZooming ||
      _widthPinching ||
      _widthPanZooming ||
      _zoomAnimationController.isAnimating;

  // Ширина (горизонтальный зум)
  double _dayWidthScale = 1.0;
  double _pinchStartWidthScale = 1.0;
  double _panZoomStartWidthScale = 1.0;

  // Анимация зума ширины
  double _zoomFromWidthScale = 1.0;
  double _zoomTargetWidthScale = 1.0;

  void _cancelDrag() {
    setState(() {
      _draggingId = null;
      _ghostStart = null;
      _ghostDuration = null;
      _ghostDayOffset = 0;
    });
  }

  void _cancelResize() {
    setState(() {
      _resizingId = null;
      _ghostStart = null;
      _ghostDuration = null;
    });
  }

  @override
  void initState() {
    super.initState();
    final initialVerticalOffset = math.max(
      0.0,
      DateTime.now().hour * _defaultHourHeight - 120.0,
    );
    final initialHorizontalOffset = _minDayWidth * 7;
    _verticalController = ScrollController(
      initialScrollOffset: initialVerticalOffset,
    );
    _horizontalController = ScrollController(
      initialScrollOffset: initialHorizontalOffset,
    );

    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..addListener(_handleZoomAnimation);
  }

  void _handleZoomAnimation() {
    final t = Curves.easeOutCubic.transform(_zoomAnimationController.value);

    final height = _zoomFromHeight + (_zoomTargetHeight - _zoomFromHeight) * t;
    _applyHourHeight(height, focalLocalDy: _zoomFocalLocalDy);

    final widthScale =
        _zoomFromWidthScale + (_zoomTargetWidthScale - _zoomFromWidthScale) * t;
    _applyDayWidthScale(widthScale);
  }

  void _applyDayWidthScale(double value) {
    final clamped = value
        .clamp(_minDayWidthScale, _maxDayWidthScale)
        .toDouble();
    if (clamped == _dayWidthScale) return;
    setState(() => _dayWidthScale = clamped);
    // LayoutBuilder пересчитает columnWidth и _syncHorizontalOffset
    // автоматически скорректирует горизонтальный скролл.
  }

  @override
  void didUpdateWidget(covariant TimelineBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart == widget.weekStart) {
      _pendingHeaderWeekChange = false;
    } else {
      _showDraftForm = false;
      _isSelecting = false;
    }
  }

  @override
  void dispose() {
    _panZoomSafetyTimer?.cancel();
    _widthPanZoomSafetyTimer?.cancel();
    _zoomAnimationController.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  /// Ключевой метод для исправления бага с "криво"
  /// При изменении размера экрана или смене недели мы математически вычисляем,
  /// какой день был в фокусе, и пересчитываем новый offset.
  void _syncHorizontalOffset({
    required DateTime oldVisibleStart,
    required DateTime newVisibleStart,
    required double oldColumnWidth,
    required double newColumnWidth,
    required double viewportWidth,
  }) {
    if (!_horizontalController.hasClients) return;
    final position = _horizontalController.position;
    if (!position.hasPixels) return;

    double currentOffset = position.pixels;
    double dayIndex = currentOffset / oldColumnWidth;

    // Если пользователь не тащит скролл руками, выравниваем по сетке дней
    if (!_isInteracting) {
      dayIndex = dayIndex.roundToDouble();
    }

    final focusedDate = _addDays(oldVisibleStart, dayIndex.floor());
    final fractionalOffset = dayIndex - dayIndex.floor();

    final newDayIndex = _daysBetween(newVisibleStart, focusedDate);
    final newOffset = (newDayIndex + fractionalOffset) * newColumnWidth;

    final maxExtent = math.max(
      0.0,
      _weekTotalDays * newColumnWidth - viewportWidth,
    );
    final clampedOffset = newOffset.clamp(0.0, maxExtent);

    if ((currentOffset - clampedOffset).abs() > 0.5) {
      position.correctPixels(clampedOffset);
    }
  }

  // --- Layout Calculation ---

  Map<String, _EventLayoutInfo> _computeLayout(List<TaskEvent> events) {
    if (events.isEmpty) return const {};

    // Сортируем по оригинальному времени, чтобы при драге колонки не прыгали
    final originalStarts = {
      for (var e in widget.events) e.task.id: e.startMinutes,
    };

    final sorted = List<TaskEvent>.from(events)
      ..sort((a, b) {
        final startA = originalStarts[a.task.id] ?? a.startMinutes;
        final startB = originalStarts[b.task.id] ?? b.startMinutes;
        final cmp = startA.compareTo(startB);
        return cmp != 0 ? cmp : a.endMinutes.compareTo(b.endMinutes);
      });

    final layout = <String, _EventLayoutInfo>{};
    final clusters = <List<TaskEvent>>[];
    var currentCluster = <TaskEvent>[];
    int? clusterEnd;

    for (final event in sorted) {
      if (currentCluster.isEmpty || event.startMinutes < clusterEnd!) {
        currentCluster.add(event);
        clusterEnd = clusterEnd == null
            ? event.endMinutes
            : math.max(clusterEnd, event.endMinutes);
      } else {
        clusters.add(currentCluster);
        currentCluster = [event];
        clusterEnd = event.endMinutes;
      }
    }
    if (currentCluster.isNotEmpty) clusters.add(currentCluster);

    for (final cluster in clusters) {
      final columns = <List<TaskEvent>>[];
      for (final event in cluster) {
        final colIndex = columns.indexWhere(
          (col) => col.last.endMinutes <= event.startMinutes,
        );
        if (colIndex == -1) {
          columns.add([event]);
        } else {
          columns[colIndex].add(event);
        }
      }
      final totalCols = columns.length;
      for (var i = 0; i < totalCols; i++) {
        for (final event in columns[i]) {
          layout[event.task.id] = _EventLayoutInfo(
            i / totalCols,
            1 / totalCols,
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
      if (event.date == null) continue;
      final day = _dateOnly(event.date!);
      if (day.isBefore(visibleStart) || day.isAfter(visibleEnd)) continue;
      byDay.putIfAbsent(_daysBetween(visibleStart, day), () => []).add(event);
    }

    final layout = <String, _EventLayoutInfo>{};
    for (final dayEvents in byDay.values) {
      layout.addAll(_computeLayout(dayEvents));
    }
    return layout;
  }

  // --- Zoom & Pinch Handlers ---

  void _zoomIn() => _animateZoom(_hourHeight * 1.2, _dayWidthScale);
  void _zoomOut() => _animateZoom(_hourHeight / 1.2, _dayWidthScale);
  void _zoomWidthIn() => _animateZoom(_hourHeight, _dayWidthScale * 1.2);
  void _zoomWidthOut() => _animateZoom(_hourHeight, _dayWidthScale / 1.2);

  void _animateZoom(double targetHeight, double targetWidthScale) {
    final clampedHeight = targetHeight
        .clamp(_minHourHeight, _maxHourHeight)
        .toDouble();
    final clampedWidth = targetWidthScale
        .clamp(_minDayWidthScale, _maxDayWidthScale)
        .toDouble();

    if (clampedHeight == _hourHeight && clampedWidth == _dayWidthScale) return;

    _zoomFromHeight = _hourHeight;
    _zoomTargetHeight = clampedHeight;
    _zoomFromWidthScale = _dayWidthScale;
    _zoomTargetWidthScale = clampedWidth;
    _zoomFocalLocalDy = _currentViewportCenterLocalDy();

    _zoomAnimationController.forward(from: 0.0);
  }

  void _applyHourHeight(double value, {double? focalLocalDy}) {
    final clamped = value.clamp(_minHourHeight, _maxHourHeight).toDouble();
    if (clamped == _hourHeight) return;

    final oldHeight = _hourHeight;
    final topInset = widget.weekStart == null ? widget.topPadding : 0.0;
    double? targetPixels;

    if (_verticalController.hasClients) {
      final pos = _verticalController.position;
      if (pos.hasPixels && pos.hasViewportDimension) {
        final focal = focalLocalDy ?? pos.viewportDimension / 2;
        final focalContent = pos.pixels + focal;
        final focalGrid = math.max(0.0, focalContent - topInset);
        final focalMinutes = focalGrid / oldHeight * 60.0;
        targetPixels = focalMinutes / 60.0 * clamped + topInset - focal;
      }
    }

    setState(() => _hourHeight = clamped);

    if (targetPixels != null) {
      final pos = _verticalController.position;
      final viewport = pos.hasViewportDimension ? pos.viewportDimension : 0.0;
      final contentHeight = (_endHour - _startHour) * clamped + 24.0 + topInset;
      final maxExtent = math.max(0.0, contentHeight - viewport);
      pos.correctPixels(targetPixels.clamp(0.0, maxExtent).toDouble());
    }
  }

  double? _currentViewportCenterLocalDy() {
    if (!_verticalController.hasClients) return null;
    final pos = _verticalController.position;
    if (!pos.hasViewportDimension) return null;
    return pos.viewportDimension / 2;
  }

  double? _verticalFocalLocalDy(double globalDy) {
    final context = _verticalScrollKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return null;
    return renderObject.globalToLocal(Offset(0, globalDy)).dy;
  }

  // ─── Width-only pinch (шапка дней) ───

  void _handleWidthPinchPointerDown(PointerDownEvent event) {
    _widthPinchPointers[event.pointer] = event.position;
    if (_widthPinchPointers.length == 2) {
      _zoomAnimationController.stop();
      final positions = _widthPinchPointers.values.toList();
      _widthPinchStartDistance = (positions[0] - positions[1]).distance;
      _widthPinchStartScale = _dayWidthScale;
      setState(() => _widthPinching = true);
    }
  }

  void _handleWidthPinchPointerMove(PointerMoveEvent event) {
    if (!_widthPinchPointers.containsKey(event.pointer)) return;
    _widthPinchPointers[event.pointer] = event.position;
    if (_widthPinchPointers.length < 2 || _widthPinchStartDistance <= 0) return;

    final positions = _widthPinchPointers.values.toList();
    final scale =
        (positions[0] - positions[1]).distance / _widthPinchStartDistance;
    _applyDayWidthScale(_widthPinchStartScale * scale);
  }

  void _handleWidthPinchPointerUp(PointerUpEvent event) {
    _widthPinchPointers.remove(event.pointer);
    if (_widthPinchPointers.length < 2 && _widthPinching) {
      setState(() => _widthPinching = false);
    }
  }

  void _handleWidthPinchPointerCancel(PointerCancelEvent event) {
    _widthPinchPointers.remove(event.pointer);
    if (_widthPinchPointers.length < 2 && _widthPinching) {
      setState(() => _widthPinching = false);
    }
    if (_widthPanZooming) setState(() => _widthPanZooming = false);
  }

  // ─── Width-only pan-zoom (шапка дней) ───

  void _armWidthPanZoomSafetyReset() {
    _widthPanZoomSafetyTimer?.cancel();
    _widthPanZoomSafetyTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _widthPanZooming) setState(() => _widthPanZooming = false);
    });
  }

  void _handleWidthPanZoomStart(PointerPanZoomStartEvent event) {
    _zoomAnimationController.stop();
    _widthPanZoomStartScale = _dayWidthScale;
    _armWidthPanZoomSafetyReset();
  }

  void _handleWidthPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (event.scale <= 0) return;
    final shouldZoom = (event.scale - 1.0).abs() > 0.005 || _widthPanZooming;
    if (!shouldZoom) return;

    if (!_widthPanZooming) {
      setState(() {
        _widthPanZooming = true;
        _widthPanZoomStartScale = _dayWidthScale / event.scale;
      });
    }
    _armWidthPanZoomSafetyReset();
    _applyDayWidthScale(_widthPanZoomStartScale * event.scale);
  }

  void _handleWidthPanZoomEnd(PointerPanZoomEndEvent event) {
    _widthPanZoomSafetyTimer?.cancel();
    if (_widthPanZooming) setState(() => _widthPanZooming = false);
  }

  // ─── Width-only pointer signal (шапка дней) ───

  void _handleWidthPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasCtrl =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);

    if (!hasCtrl || event.scrollDelta.dy == 0) return;

    _zoomAnimationController.stop();
    final factor = math.exp(-event.scrollDelta.dy / 240.0);
    _applyDayWidthScale(_dayWidthScale * factor);
  }

  void _handlePinchPointerDown(PointerDownEvent event) {
    _pinchPointers[event.pointer] = event.position;
    if (_pinchPointers.length == 2) {
      _zoomAnimationController.stop();
      final positions = _pinchPointers.values.toList();
      _pinchStartDistance = (positions[0] - positions[1]).distance;
      _pinchStartHeight = _hourHeight;
      _pinchStartWidthScale = _dayWidthScale;
      setState(() => _pinching = true);
    }
  }

  void _handlePinchPointerMove(PointerMoveEvent event) {
    if (!_pinchPointers.containsKey(event.pointer)) return;
    _pinchPointers[event.pointer] = event.position;
    if (_pinchPointers.length < 2 || _pinchStartDistance <= 0) return;
    if (_draggingId != null || _resizingId != null) return;

    final positions = _pinchPointers.values.toList();
    final scale = (positions[0] - positions[1]).distance / _pinchStartDistance;
    final focalLocalDy = _verticalFocalLocalDy(
      (positions[0].dy + positions[1].dy) / 2.0,
    );

    // Только высота
    _applyHourHeight(_pinchStartHeight * scale, focalLocalDy: focalLocalDy);
  }

  void _handlePinchPointerUp(PointerUpEvent event) {
    _pinchPointers.remove(event.pointer);
    if (_pinchPointers.length < 2 && _pinching)
      setState(() => _pinching = false);
  }

  void _handlePinchPointerCancel(PointerCancelEvent event) {
    _pinchPointers.remove(event.pointer);
    if (_pinchPointers.length < 2 && _pinching)
      setState(() => _pinching = false);
    if (_panZooming) setState(() => _panZooming = false);
  }

  void _armPanZoomSafetyReset() {
    _panZoomSafetyTimer?.cancel();
    _panZoomSafetyTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted && _panZooming) setState(() => _panZooming = false);
    });
  }

  void _handlePanZoomStart(PointerPanZoomStartEvent event) {
    _zoomAnimationController.stop();
    _panZoomStartHeight = _hourHeight;
    _panZoomStartWidthScale = _dayWidthScale;
    _armPanZoomSafetyReset();
  }

  void _handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    if (event.scale <= 0) return;
    final shouldZoom = (event.scale - 1.0).abs() > 0.005 || _panZooming;
    if (!shouldZoom) return;

    if (!_panZooming) {
      setState(() {
        _panZooming = true;
        _panZoomStartHeight = _hourHeight / event.scale;
      });
    }
    _armPanZoomSafetyReset();

    final focalLocalDy = _verticalFocalLocalDy(event.position.dy);
    // Только высота
    _applyHourHeight(
      _panZoomStartHeight * event.scale,
      focalLocalDy: focalLocalDy,
    );
  }

  void _handlePanZoomEnd(PointerPanZoomEndEvent event) {
    _panZoomSafetyTimer?.cancel();
    if (_panZooming) setState(() => _panZooming = false);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final hasCtrl =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);

    if (!hasCtrl || event.scrollDelta.dy == 0) return;

    _zoomAnimationController.stop();
    final factor = math.exp(-event.scrollDelta.dy / 240.0);
    final focalLocalDy = _verticalFocalLocalDy(event.position.dy);

    // Только высота
    _applyHourHeight(_hourHeight * factor, focalLocalDy: focalLocalDy);
  } // --- Drag & Resize Handlers ---

  void _onDragStart(TaskEvent event, DragStartDetails details) {
    // Не начинаем drag если уже идёт pinch, pan-zoom или width-zoom
    if (_pinching || _panZooming || _widthPinching || _widthPanZooming) return;
    if (_pinchPointers.length > 1 || _widthPinchPointers.length > 1) return;

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
    // Если начался pinch/pan-zoom во время drag — отменяем drag
    if (_pinching ||
        _panZooming ||
        _widthPinching ||
        _widthPanZooming ||
        _pinchPointers.length > 1 ||
        _widthPinchPointers.length > 1) {
      _cancelDrag();
      return;
    }

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
    if (widget.weekStart != null &&
        event.date != null &&
        _lastColumnWidth > 0) {
      final dxDelta = details.globalPosition.dx - _dragStartDx;
      final rawOffset = dxDelta / _lastColumnWidth;
      final roundedOffset = rawOffset >= 0
          ? rawOffset.floorToDouble()
          : rawOffset.ceilToDouble();
      final finalOffset = rawOffset.abs() > 0.7
          ? rawOffset.roundToDouble()
          : roundedOffset;

      final visibleStart = _visibleStart(widget.weekStart!);
      final visibleEnd = _visibleEnd(widget.weekStart!);
      final originalDay = _dateOnly(event.date!);
      var targetDay = _addDays(originalDay, finalOffset.toInt());
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
    if (_ghostStart != null) {
      final date = event.date;
      if (date != null && _ghostDayOffset != 0) {
        widget.onEventChanged(
          event.task,
          startMinutes: _ghostStart,
          durationMinutes: _ghostDuration,
          newDate: _addDays(_dateOnly(date), _ghostDayOffset),
        );
      } else {
        widget.onEventChanged(
          event.task,
          startMinutes: _ghostStart,
          durationMinutes: _ghostDuration,
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
    if (_pinching || _panZooming || _widthPinching || _widthPanZooming) return;
    if (_pinchPointers.length > 1 || _widthPinchPointers.length > 1) return;

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
    if (_pinching ||
        _panZooming ||
        _widthPinching ||
        _widthPanZooming ||
        _pinchPointers.length > 1 ||
        _widthPinchPointers.length > 1) {
      _cancelResize();
      return;
    }

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
    if (_ghostDuration != null)
      widget.onEventChanged(event.task, durationMinutes: _ghostDuration);
    setState(() {
      _resizingId = null;
      _ghostStart = null;
      _ghostDuration = null;
    });
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
    if (weekStart == null || onWeekChange == null || _lastColumnWidth <= 0)
      return;

    final viewportWidth = _lastColumnWidth * 7;
    final centerDayIndex = _clampInt(
      ((offset + viewportWidth / 2) / _lastColumnWidth).floor(),
      0,
      _weekTotalDays - 1,
    );
    final currentStart = _weekBufferDays;
    final currentEnd = _weekBufferDays + 6;

    if (centerDayIndex >= currentStart && centerDayIndex <= currentEnd) return;

    final targetDate = centerDayIndex < currentStart
        ? _addDays(weekStart, -7)
        : _addDays(weekStart, 7);
    onWeekChange(targetDate);
  }

  ScrollPhysics _verticalPhysics() => _isInteracting
      ? const NeverScrollableScrollPhysics()
      : const ClampingScrollPhysics();
  ScrollPhysics _horizontalPhysics(double columnWidth, double viewportWidth) {
    if (_isInteracting || columnWidth <= 0)
      return const NeverScrollableScrollPhysics();
    return _FlexibleSnapScrollPhysics(
      columnWidth: columnWidth,
      viewportWidth: viewportWidth,
      parent: const ClampingScrollPhysics(),
    );
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 1200.0;
        final isWeekMode = widget.weekStart != null;

        final displayEvents = widget.events
            .map((event) {
              final isInteracting =
                  event.task.id == _draggingId || event.task.id == _resizingId;
              if (!isInteracting) return event;

              // УДАЛИТЕ ЭТОТ БЛОК:
              // DateTime? displayDate = event.date;
              // if (event.date != null && _draggingId == event.task.id && _ghostDayOffset != 0) {
              //   displayDate = _addDays(event.date!, _ghostDayOffset);
              // }

              return event.copyWith(
                startMinutes: _ghostStart ?? event.startMinutes,
                durationMinutes: _ghostDuration ?? event.durationMinutes,
                // date больше не передаём - используем оригинальный
              );
            })
            .toList(growable: false);

        if (isWeekMode) return _buildWeekView(displayEvents, maxWidth);
        return _buildDayView(displayEvents, maxWidth);
      },
    );
  }

  Widget _buildWeekView(List<TaskEvent> events, double maxWidth) {
    final weekStart = widget.weekStart!;
    final viewportWidth = math.max(0.0, maxWidth - _leftLabelWidth);
    final baseColumnWidth = viewportWidth / 7.0;
    final columnWidth = math.max(
      _minDayWidth,
      baseColumnWidth * _dayWidthScale,
    );

    // Синхронизация offset при ресайзе или смене недели
    if (_horizontalController.hasClients &&
        _lastColumnWidth > 0 &&
        columnWidth > 0) {
      final oldWeekStart = _lastWeekStart ?? weekStart;
      final oldVisibleStart = _visibleStart(oldWeekStart);
      final newVisibleStart = _visibleStart(weekStart);
      final bool weekChanged = oldWeekStart != weekStart;
      final bool sizeChanged = (_lastColumnWidth - columnWidth).abs() > 0.1;

      if (weekChanged || sizeChanged) {
        if (weekChanged && _pendingHeaderWeekChange) {
          _pendingHeaderWeekChange = false;
          final maxExtent = math.max(
            0.0,
            _weekTotalDays * columnWidth - viewportWidth,
          );
          final target = (_weekBufferDays * columnWidth)
              .clamp(0.0, maxExtent)
              .toDouble();
          final pos = _horizontalController.position;
          if ((pos.pixels - target).abs() > 0.5) {
            pos.correctPixels(target);
          }
        } else {
          _syncHorizontalOffset(
            oldVisibleStart: oldVisibleStart,
            newVisibleStart: newVisibleStart,
            oldColumnWidth: _lastColumnWidth,
            newColumnWidth: columnWidth,
            viewportWidth: viewportWidth,
          );
        }
      }
    }

    _lastColumnWidth = columnWidth;
    _lastWeekStart = weekStart;
    _lastMaxWidth = maxWidth;
    final layouts = _computeWeekLayout(events, weekStart);

    return Stack(
      //crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Таймлайн: зум ВЫСОТЫ ───
        FixedVerticalFadeMask(
          topFade: 200,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _handlePinchPointerDown,
            onPointerMove: _handlePinchPointerMove,
            onPointerUp: _handlePinchPointerUp,
            onPointerCancel: _handlePinchPointerCancel,
            onPointerPanZoomStart: _handlePanZoomStart,
            onPointerPanZoomUpdate: _handlePanZoomUpdate,
            onPointerPanZoomEnd: _handlePanZoomEnd,
            onPointerSignal: _handlePointerSignal,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: 200),
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
                      child: Stack(children: _buildWeekHourLabels()),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _handleHorizontalScrollNotification,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _horizontalController,
                          physics: _horizontalPhysics(
                            columnWidth,
                            viewportWidth,
                          ),
                          child: SizedBox(
                            width: _weekTotalDays * columnWidth,
                            height: _totalHeight + 24,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onLongPressStart: _onSelectionLongPressStart,
                              onLongPressMoveUpdate: _onSelectionLongPressMove,
                              onLongPressEnd: _onSelectionLongPressEnd,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  ..._buildWeekColumnBackground(
                                    columnWidth,
                                    weekStart,
                                  ),
                                  ..._buildWeekHourGridlines(),
                                  ...events.map((event) {
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
                                  _buildWeekNowLine(weekStart, columnWidth),
                                  _buildSelectionGhost(),
                                ],
                              ),
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
        ),
        // ─── Шапка дней: зум ШИРИНЫ ───
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handleWidthPinchPointerDown,
          onPointerMove: _handleWidthPinchPointerMove,
          onPointerUp: _handleWidthPinchPointerUp,
          onPointerCancel: _handleWidthPinchPointerCancel,
          onPointerPanZoomStart: _handleWidthPanZoomStart,
          onPointerPanZoomUpdate: _handleWidthPanZoomUpdate,
          onPointerPanZoomEnd: _handleWidthPanZoomEnd,
          onPointerSignal: _handleWidthPointerSignal,
          child: _WeekGridHeader(
            weekStart: weekStart,
            anchorDate: widget.anchorDate ?? weekStart,
            topPadding: widget.topPadding,
            columnWidth: columnWidth,
            horizontalController: _horizontalController,
            onWeekChange: _handleHeaderWeekChange,
            onZoomIn: _zoomIn,
            onZoomOut: _zoomOut,
            onWidthZoomIn: _zoomWidthIn,
            onWidthZoomOut: _zoomWidthOut,
          ),
        ),
        _buildDraftFormOverlay(),
      ],
    );
  }

  Widget _buildDayView(List<TaskEvent> events, double maxWidth) {
    final availableWidth = math.max(0.0, maxWidth - _leftLabelWidth - 24.0);
    _lastDayViewWidth = availableWidth;
    _lastMaxWidth = maxWidth;
    final layouts = _computeLayout(events);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _handlePinchPointerDown,
          onPointerMove: _handlePinchPointerMove,
          onPointerUp: _handlePinchPointerUp,
          onPointerCancel: _handlePinchPointerCancel,
          onPointerPanZoomStart: _handlePanZoomStart,
          onPointerPanZoomUpdate: _handlePanZoomUpdate,
          onPointerPanZoomEnd: _handlePanZoomEnd,
          onPointerSignal: _handlePointerSignal,
          child: SingleChildScrollView(
            key: _verticalScrollKey,
            controller: _verticalController,
            physics: _verticalPhysics(),
            padding: EdgeInsets.only(top: widget.topPadding),
            child: SizedBox(
              width: maxWidth,
              height: _totalHeight + 24,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onLongPressStart: _onSelectionLongPressStart,
                onLongPressMoveUpdate: _onSelectionLongPressMove,
                onLongPressEnd: _onSelectionLongPressEnd,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ..._buildHourRows(),
                    ...events.map((event) {
                      final layout =
                          layouts[event.task.id] ??
                          const _EventLayoutInfo(0, 1);
                      return _buildDraggableEvent(
                        event,
                        layout,
                        availableWidth,
                      );
                    }),
                    _buildNowLine(),
                    _buildSelectionGhost(),
                  ],
                ),
              ),
            ),
          ),
        ),
        _buildDraftFormOverlay(),
      ],
    );
  }
  // --- UI Builders ---

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
                style: const TextStyle(color: Colors.white38, fontSize: 11),
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
          style: const TextStyle(color: Colors.white38, fontSize: 11),
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
    return isWeekend ? const Color(0x06FFFFFF) : Colors.transparent;
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
            color: _weekColumnColor(_addDays(visibleStart, i), i == todayIndex),
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
    final y = (now.hour * 60 + now.minute - _startHour * 60) / 60 * _hourHeight;
    return Positioned(
      top: y,
      left: 0,
      right: 0,
      child: Row(
        children: [
          SizedBox(width: includeGutterOffset ? _leftLabelWidth + 4 : 0),
          const DecoratedBox(
            decoration: BoxDecoration(color: _orange, shape: BoxShape.circle),
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
    if (todayIndex < 0 || todayIndex >= _weekTotalDays)
      return const SizedBox.shrink();

    final y = (now.hour * 60 + now.minute - _startHour * 60) / 60 * _hourHeight;
    return Positioned(
      top: y,
      left: todayIndex * columnWidth,
      width: columnWidth,
      child: Row(
        children: [
          const SizedBox(width: 6),
          const DecoratedBox(
            decoration: BoxDecoration(color: _orange, shape: BoxShape.circle),
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
    final visualHeight = math.max(
      30.0,
      displayDuration / 60 * _hourHeight + 4.0,
    );

    double eventLeft;
    double eventWidth;

    if (widget.weekStart != null &&
        weekColumnWidth != null &&
        weekColumnWidth > 0) {
      final date = event.date;
      if (date == null) return const SizedBox.shrink();

      final visibleStart = _visibleStart(widget.weekStart!);
      final baseDayIndex = _daysBetween(visibleStart, date);
      final dayIndex = isDragging
          ? baseDayIndex + _ghostDayOffset
          : baseDayIndex;

      if (dayIndex < 0 || dayIndex >= _weekTotalDays)
        return const SizedBox.shrink();

      final innerLeft = dayIndex * weekColumnWidth + 3;
      final innerWidth = math.max(0.0, weekColumnWidth - 6);

      if (isDragging) {
        eventLeft = innerLeft + 1;
        eventWidth = math.max(18.0, innerWidth - 2);
      } else {
        eventWidth = math.max(18.0, innerWidth * layout.widthFactor - 2);
        eventLeft = innerLeft + innerWidth * layout.leftFactor + 1;
      }
    } else {
      eventWidth = isDragging
          ? availableWidth
          : math.max(0.0, availableWidth * layout.widthFactor - 4);
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
        opacity: isDragging ? 0.8 : 1.0,
        child: _EventTile(
          event: event,
          height: visualHeight,
          isDragging: isDragging,
          isResizing: isResizing,
          onDragStart: (d) => _onDragStart(event, d),
          onDragUpdate: (d) => _onDragUpdate(event, d),
          onDragEnd: (d) => _onDragEnd(event, d),
          onResizeStart: (d) => _onResizeStart(event, d),
          onResizeUpdate: (d) => _onResizeUpdate(event, d),
          onResizeEnd: (d) => _onResizeEnd(event, d),
          onToggleTask: () => widget.onToggleTask(event.task),
          ghostStart: isInteracting ? _ghostStart : null,
          ghostDuration: isInteracting ? _ghostDuration : null,
        ),
      ),
    );
  }
}

// --- Вспомогательные классы и виджеты ---

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

  TimeOfDay _minutesToTime(int minutes) =>
      TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60);

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
          behavior: HitTestBehavior.translucent,
          dragStartBehavior: DragStartBehavior.down,
          onPanStart: onDragStart,
          onPanUpdate: onDragUpdate,
          onPanEnd: onDragEnd,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Container(
              color: AppColors.surfaceContainerLow,

              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.fromLTRB(20, 2, 10, 2),
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomCenter,
                    colors: [
                      if (event.isCompleted)
                        Colors.white.withOpacity(0.05)
                      else
                        accent.withOpacity(0.22),
                      Colors.white.withOpacity(0.06),
                      Colors.black.withOpacity(0.01),
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
            behavior: HitTestBehavior.translucent,
            dragStartBehavior: DragStartBehavior.down,
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
                  color: Colors.white.withOpacity(isInteracting ? 0.55 : 0.16),
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
                  BoxShadow(color: accent.withOpacity(0.35), blurRadius: 6),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekGridHeader extends StatefulWidget {
  const _WeekGridHeader({
    required this.weekStart,
    required this.anchorDate,
    required this.topPadding,
    required this.columnWidth,
    required this.horizontalController,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onWidthZoomIn,
    required this.onWidthZoomOut,
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
  final VoidCallback onWidthZoomIn;
  final VoidCallback onWidthZoomOut;

  @override
  State<_WeekGridHeader> createState() => _WeekGridHeaderState();
}

class _WeekGridHeaderState extends State<_WeekGridHeader>
    with SingleTickerProviderStateMixin {
  // Анимация плавного "перетекания" выделенной недели при её смене.
  // Неделя описывается непрерывным центром окна в абсолютных днях.
  late final AnimationController _weekShiftController;
  double _centerFrom = 0;
  double _centerTo = 0;

  static int _absDay(DateTime date) => _daysBetween(DateTime(2000), date);

  double get _currentCenterAbs =>
      _centerFrom +
      (_centerTo - _centerFrom) *
          Curves.easeOutCubic.transform(_weekShiftController.value);

  // Насколько день (по абсолютному номеру) принадлежит анимированному
  // недельному окну шириной 7 дней: 0..1.
  double _weekMembership(double dayAbs) {
    final overlap =
        math.min(dayAbs + 0.5, _currentCenterAbs + 3.5) -
        math.max(dayAbs - 0.5, _currentCenterAbs - 3.5);
    return overlap.clamp(0.0, 1.0).toDouble();
  }

  @override
  void initState() {
    super.initState();
    _weekShiftController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    final center = _absDay(widget.weekStart) + 3.0;
    _centerFrom = center;
    _centerTo = center;
    _weekShiftController.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _WeekGridHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weekStart != widget.weekStart) {
      _centerFrom = _currentCenterAbs;
      _centerTo = _absDay(widget.weekStart) + 3.0;
      _weekShiftController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _weekShiftController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: widget.anchorDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2140),
    );
    if (date != null) widget.onWeekChange?.call(date);
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
    print("Start of week: ${widget.weekStart}");
    final weekEnd = _addDays(widget.weekStart, 6);
    final visibleStart = _addDays(widget.weekStart, -_weekBufferDays);
    final hasNav = widget.onWeekChange != null;
    final isCurrentWeek =
        _isSameDay(today, widget.weekStart) ||
        _isSameDay(today, weekEnd) ||
        (today.isAfter(widget.weekStart) && today.isBefore(weekEnd));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: widget.topPadding),
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
                      () =>
                          widget.onWeekChange!(_addDays(widget.weekStart, -7)),
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
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) {
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
                                          key: const ValueKey('this_week_text'),
                                          style: AppTypography.codeLabel,
                                        )
                                      : const SizedBox.shrink(
                                          key: ValueKey('empty_space'),
                                        ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_twoDigit(widget.weekStart.day)}.${_twoDigit(widget.weekStart.month)} – ${_twoDigit(weekEnd.day)}.${_twoDigit(weekEnd.month)}',
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
                      () => widget.onWeekChange!(_addDays(widget.weekStart, 7)),
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
                animation: Listenable.merge([
                  widget.horizontalController,
                  _weekShiftController,
                ]),
                builder: (context, child) {
                  final offset = widget.horizontalController.hasClients
                      ? widget.horizontalController.offset
                      : _weekBufferDays * widget.columnWidth;
                  return Stack(
                    clipBehavior: Clip.hardEdge,
                    children: [
                      Positioned(
                        left: -offset,
                        top: 0,
                        bottom: 0,
                        width: _weekTotalDays * widget.columnWidth,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_weekTotalDays, (index) {
                            final date = _addDays(visibleStart, index);
                            final isToday = _isSameDay(date, today);
                            final isAnchor = _isSameDay(
                              date,
                              widget.anchorDate,
                            );
                            final membership = _weekMembership(
                              _absDay(date).toDouble(),
                            );

                            return SizedBox(
                              width: widget.columnWidth,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: hasNav
                                      ? () => widget.onWeekChange!(date)
                                      : null,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(
                                        0.04 + 0.16 * membership,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: GlassPanel(
                                      borderColor: isAnchor
                                          ? Colors.white.withOpacity(0.6)
                                          : null,
                                      borderRadius: 12,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 2,
                                                  ),
                                              child: Text(
                                                getWeekDayName(
                                                  date.weekday,
                                                ).toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: isToday
                                                      ? _orange
                                                      : Colors.white
                                                            .withOpacity(0.55),
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
                                                        _orange.withOpacity(
                                                          0.85,
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                              boxShadow: isToday
                                                  ? [
                                                      BoxShadow(
                                                        color: _orange
                                                            .withOpacity(0.35),
                                                        blurRadius: 10,
                                                        offset: const Offset(
                                                          0,
                                                          3,
                                                        ),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Text(
                                              '${date.day}',
                                              style: TextStyle(
                                                color: isToday
                                                    ? Colors.black
                                                    : Colors.white.withOpacity(
                                                        0.85,
                                                      ),
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
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
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
            border: Border.all(color: Colors.white.withOpacity(0.14)),
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

class _FlexibleSnapScrollPhysics extends ScrollPhysics {
  const _FlexibleSnapScrollPhysics({
    required this.columnWidth,
    required this.viewportWidth,
    ScrollPhysics? parent,
  }) : super(parent: parent);

  final double columnWidth;
  final double viewportWidth;

  @override
  _FlexibleSnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _FlexibleSnapScrollPhysics(
      columnWidth: columnWidth,
      viewportWidth: viewportWidth,
      parent: buildParent(ancestor),
    );
  }

  /// Вычисляет "умный" шаг снаппинга на основе того,
  /// сколько дней помещается в видимую область.
  double get _snapStep {
    if (columnWidth <= 0 || viewportWidth <= 0) return columnWidth;

    final daysInView = viewportWidth / columnWidth;

    // Адаптивный шаг:
    // - Если помещается много дней — снапим по целым дням
    // - Если помещается около 1 дня — снапим по половине
    // - Если экран очень узкий — снапим по трети дня
    if (daysInView >= 1.5) {
      return columnWidth;
    } else if (daysInView >= 0.75) {
      return columnWidth / 2;
    } else {
      return columnWidth / 3;
    }
  }

  double _getTargetPixels(
    ScrollMetrics position,
    Tolerance tolerance,
    double velocity,
  ) {
    final step = _snapStep;
    if (step <= 0) return position.pixels;

    double page = position.pixels / step;

    // Учитываем скорость броска для более естественного снаппинга.
    // Если пользователь бросил скролл с большой скоростью,
    // продолжаем движение в том же направлении до следующей границы.
    final velocityThreshold = tolerance.velocity * 2.5;

    if (velocity.abs() > velocityThreshold) {
      // Большая скорость — снапим в направлении движения
      page = velocity > 0 ? page.ceilToDouble() : page.floorToDouble();
    } else {
      // Маленькая скорость — снапим к ближайшей границе
      page = page.roundToDouble();
    }

    return page * step;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // Если вышли за границы — используем стандартную физику для отскока
    if (position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final step = _snapStep;
    if (step <= 0) {
      return super.createBallisticSimulation(position, velocity);
    }

    const tolerance = Tolerance.defaultTolerance;
    final target = _getTargetPixels(position, tolerance, velocity);

    // Если текущая позиция уже достаточно близка к цели — ничего не делаем
    if ((target - position.pixels).abs() < tolerance.distance) {
      return null;
    }

    // Иначе запускаем плавную анимацию к целевой позиции
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
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
        Offset((startX + _dashWidth).clamp(0.0, size.width), size.height / 2),
        paint,
      );
      startX += _dashWidth + _dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      color != oldDelegate.color;
}

class _EventLayoutInfo {
  const _EventLayoutInfo(this.leftFactor, this.widthFactor);
  final double leftFactor;
  final double widthFactor;
}

// --- Helpers ---

int _snapToGrid(int minutes) => (minutes / _snapMinutes).round() * _snapMinutes;
int _clampInt(int value, int min, int max) => value.clamp(min, max);
DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime _addDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
int _daysBetween(DateTime a, DateTime b) =>
    _dateOnly(b).difference(_dateOnly(a)).inDays;
DateTime _visibleStart(DateTime weekStart) =>
    _addDays(_dateOnly(weekStart), -_weekBufferDays);
DateTime _visibleEnd(DateTime weekStart) =>
    _addDays(_visibleStart(weekStart), _weekTotalDays - 1);
String _formatTime(TimeOfDay time) =>
    '${time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod}:${time.minute.toString().padLeft(2, '0')} ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _twoDigit(int value) => value.toString().padLeft(2, '0');
