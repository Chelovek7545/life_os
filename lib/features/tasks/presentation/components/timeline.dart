import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

const _orange = Color(0xFFFF5C00);
const _startHour = 0;
const _endHour = 24;
const _hourHeight = 140.0;
const _leftLabelWidth = 52.0;
const _snapMinutes = 15;
const _resizeHandleHeight = 18.0;
const _minDurationMinutes = 15;

class TaskEvent {
  const TaskEvent({
    required this.task,
    required this.title,
    required this.startMinutes,
    required this.durationMinutes,
    this.isActive = false,
    this.accentColor = const Color(0xFF2A2A2A),
  });

  final Task task;
  final String title;
  final int startMinutes;
  final int durationMinutes;
  final bool isActive;
  final Color accentColor;

  int get endMinutes => startMinutes + durationMinutes;

  TimeOfDay get startTime =>
      TimeOfDay(hour: startMinutes ~/ 60, minute: startMinutes % 60);

  TimeOfDay get endTime =>
      TimeOfDay(hour: endMinutes ~/ 60, minute: endMinutes % 60);

  TaskEvent copyWith({int? startMinutes, int? durationMinutes}) {
    return TaskEvent(
      task: task,
      title: title,
      startMinutes: startMinutes ?? this.startMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      isActive: isActive,
      accentColor: accentColor,
    );
  }
}

class TimelineBody extends StatefulWidget {
  const TimelineBody({
    super.key,
    required this.events,
    required this.onEventChanged,
    required this.topPadding,
  });

  final List<TaskEvent> events;
  final double topPadding;
  final void Function(Task task, {int? startMinutes, int? durationMinutes})
  onEventChanged;

  @override
  State<TimelineBody> createState() => _TimelineBodyState();
}

class _TimelineBodyState extends State<TimelineBody> {
  static const _totalMinutes = (_endHour - _startHour) * 60;
  static const _totalHeight = (_endHour - _startHour) * _hourHeight;

  String? _draggingId;
  double _dragStartDy = 0;
  int _dragStartMinutes = 0;

  String? _resizingId;
  double _resizeStartDy = 0;
  int _resizeStartDuration = 0;

  int? _ghostStart;
  int? _ghostDuration;

  Map<String, _EventLayoutInfo> _computeLayout(List<TaskEvent> events) {
    if (events.isEmpty) {
      return const {};
    }

    final originalStartById = {
      for (final event in widget.events) event.task.id: event.startMinutes,
    };
    final sorted = List<TaskEvent>.of(events)
      ..sort((a, b) {
        final startCompare = (originalStartById[a.task.id] ?? a.startMinutes)
            .compareTo(originalStartById[b.task.id] ?? b.startMinutes);
        if (startCompare != 0) {
          return startCompare;
        }
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

  void _onDragStart(TaskEvent event, DragStartDetails details) {
    HapticFeedback.lightImpact();
    setState(() {
      _draggingId = event.task.id;
      _dragStartDy = details.globalPosition.dy;
      _dragStartMinutes = event.startMinutes;
      _ghostStart = event.startMinutes;
      _ghostDuration = event.durationMinutes;
    });
  }

  void _onDragUpdate(TaskEvent event, DragUpdateDetails details) {
    final dyDelta = details.globalPosition.dy - _dragStartDy;
    final minutesDelta = (dyDelta / _hourHeight * 60).round();
    final newStart = _snapToGrid(
      _dragStartMinutes + minutesDelta,
    ).clamp(_startHour * 60, _endHour * 60 - event.durationMinutes);

    setState(() => _ghostStart = newStart);
  }

  void _onDragEnd(TaskEvent event, DragEndDetails details) {
    final ghostStart = _ghostStart;
    if (ghostStart != null) {
      widget.onEventChanged(event.task, startMinutes: ghostStart);
    }

    setState(() {
      _draggingId = null;
      _ghostStart = null;
      _ghostDuration = null;
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
    final minutesDelta = (dyDelta / _hourHeight * 60).round();
    final maxDuration = _endHour * 60 - event.startMinutes;
    final newDuration = _snapToGrid(_resizeStartDuration + minutesDelta).clamp(
      _minDurationMinutes,
      maxDuration.clamp(_minDurationMinutes, _totalMinutes),
    );

    setState(() => _ghostDuration = newDuration);
  }

  void _onResizeEnd(TaskEvent event, DragEndDetails details) {
    final ghostDuration = _ghostDuration;
    if (ghostDuration != null) {
      widget.onEventChanged(event.task, durationMinutes: ghostDuration);
    }

    setState(() {
      _resizingId = null;
      _ghostStart = null;
      _ghostDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final displayEvents = widget.events
        .map((event) {
          final isInteracting =
              event.task.id == _draggingId || event.task.id == _resizingId;
          if (!isInteracting) {
            return event;
          }

          return event.copyWith(
            startMinutes: _ghostStart,
            durationMinutes: _ghostDuration,
          );
        })
        .toList(growable: false);
    final layouts = _computeLayout(displayEvents);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = (constraints.maxWidth - _leftLabelWidth - 24)
            .clamp(0.0, double.infinity)
            .toDouble();

        return SingleChildScrollView(
          physics: _draggingId != null || _resizingId != null
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
          padding: EdgeInsets.only(top: widget.topPadding),
          child: SizedBox(
            height: _totalHeight + 24,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ..._buildHourRows(),
                ...widget.events.map((event) {
                  final layout =
                      layouts[event.task.id] ?? const _EventLayoutInfo(0, 1);
                  return _buildDraggableEvent(event, layout, availableWidth);
                }),
                _buildNowLine(),
              ],
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

  Widget _buildNowLine() {
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final y = (nowMinutes - _startHour * 60) / 60 * _hourHeight;

    return Positioned(
      top: y,
      left: 0,
      right: 0,
      child: Row(
        children: [
          const SizedBox(width: _leftLabelWidth + 4),
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

  Widget _buildDraggableEvent(
    TaskEvent event,
    _EventLayoutInfo layout,
    double availableWidth,
  ) {
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
    final height = displayDuration / 60 * _hourHeight;
    final eventWidth = availableWidth * layout.widthFactor;
    final eventLeft =
        _leftLabelWidth + 12 + (availableWidth * layout.leftFactor);

    return Positioned(
      top: top + 6,
      left: isDragging ? _leftLabelWidth + 12 : eventLeft + 2,
      width: isDragging
          ? availableWidth
          : (eventWidth - 4).clamp(0.0, eventWidth),
      height: height + 4,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: isDragging ? 0.75 : 1,
        child: _EventTile(
          event: event,
          height: height + 4,
          isDragging: isDragging,
          isResizing: isResizing,
          onDragStart: (details) => _onDragStart(event, details),
          onDragUpdate: (details) => _onDragUpdate(event, details),
          onDragEnd: (details) => _onDragEnd(event, details),
          onResizeStart: (details) => _onResizeStart(event, details),
          onResizeUpdate: (details) => _onResizeUpdate(event, details),
          onResizeEnd: (details) => _onResizeEnd(event, details),
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
  final int? ghostStart;
  final int? ghostDuration;

  TimeOfDay _minutesToTime(int minutes) {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  @override
  Widget build(BuildContext context) {
    final accent = event.accentColor;
    final isInteracting = isDragging || isResizing;
    final start = ghostStart == null
        ? event.startTime
        : _minutesToTime(ghostStart!);
    final end = switch ((ghostStart, ghostDuration)) {
      (final int startMinutes, final int durationMinutes) => _minutesToTime(
        startMinutes + durationMinutes,
      ),
      (null, final int durationMinutes) => _minutesToTime(
        event.startMinutes + durationMinutes,
      ),
      _ => event.endTime,
    };

    return Stack(
      children: [
        GestureDetector(
          onVerticalDragStart: onDragStart,
          onVerticalDragUpdate: onDragUpdate,
          onVerticalDragEnd: onDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
            decoration: BoxDecoration(
              color: event.isActive
                  ? const Color(0xFF1C1006)
                  : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isInteracting ? accent.withValues(alpha: 0.9) : accent,
                width: isInteracting ? 2 : (event.isActive ? 1.5 : 1),
              ),
              boxShadow: isInteracting
                  ? [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                _StatusDot(isActive: event.isActive, accent: accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (height > 36)
                        Text(
                          event.title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: event.isActive ? accent : Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      if (height > 52) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${_formatTime(start)} - ${_formatTime(end)}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isInteracting
                                ? Colors.white70
                                : Colors.white54,
                            fontSize: 12,
                            fontWeight: isInteracting
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (height > 36)
                  const Icon(
                    Icons.drag_indicator,
                    color: Colors.white24,
                    size: 16,
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _resizeHandleHeight,
          child: GestureDetector(
            onVerticalDragStart: onResizeStart,
            onVerticalDragUpdate: onResizeUpdate,
            onVerticalDragEnd: onResizeEnd,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Center(child: SizedBox(width: 32, height: 3)),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.isActive, required this.accent});

  final bool isActive;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? accent : Colors.white38,
          width: 1.5,
        ),
      ),
      child: isActive
          ? Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox(width: 8, height: 8),
              ),
            )
          : null,
    );
  }
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

String _formatTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
