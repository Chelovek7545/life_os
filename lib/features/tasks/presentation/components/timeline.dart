import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';


// ── Constants ─────────────────────────────────────────────────────────────────

const _orange = Color(0xFFFF5C00);
const _startHour = 0;
const _endHour = 24;
const _hourHeight = 140.0; // px per hour
const _leftLabelWidth = 52.0;
const _snapMinutes = 15; // snap to 15-min grid

// ── Data model ────────────────────────────────────────────────────────────────

class _EventLayoutInfo {
  final double leftFactor; // Какую долю ширины отступить слева (0.0 до 1.0)
  final double widthFactor; // Какую долю ширины занять (0.0 до 1.0)

  _EventLayoutInfo(this.leftFactor, this.widthFactor);
}

class TaskEvent {
  final Task task;
  String title;
  int startMinutes; // minutes from midnight
  int durationMinutes;
  bool isActive;
  Color accentColor;

  TaskEvent({
    required this.task,
    required this.title,
    required this.startMinutes,
    required this.durationMinutes,
    this.isActive = false,
    this.accentColor = const Color(0xFF2A2A2A),
  });

  int get endMinutes => startMinutes + durationMinutes;

  TimeOfDay get startTime => TimeOfDay(
        hour: startMinutes ~/ 60,
        minute: startMinutes % 60,
      );

  TimeOfDay get endTime => TimeOfDay(
        hour: endMinutes ~/ 60,
        minute: endMinutes % 60,
      );

  double get topY => (startMinutes - _startHour * 60) / 60 * _hourHeight;
  double get height => durationMinutes / 60 * _hourHeight;

  TaskEvent copyWith({int? startMinutes, int? durationMinutes}) => TaskEvent(
        task: task,
        title: title,
        startMinutes: startMinutes ?? this.startMinutes,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        isActive: isActive,
        accentColor: accentColor,
      );
}

// ── Helper ────────────────────────────────────────────────────────────────────

int _snapToGrid(int minutes) {
  return (minutes / _snapMinutes).round() * _snapMinutes;
}

String _fmtTime(TimeOfDay t) {
  final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
  final m = t.minute.toString().padLeft(2, '0');
  final period = t.period == DayPeriod.am ? 'AM' : 'PM';
  return '$h:$m $period';
}

// ── Screen ────────────────────────────────────────────────────────────────────

// class TimelineScreen extends StatefulWidget {
//   const TimelineScreen({super.key});
//   @override
//   State<TimelineScreen> createState() => TimelineScreenState();
// }

// class _TimelineScreenState extends State<TimelineScreen> {
//   final List<TaskEvent> _events = [
//     TaskEvent(
//       id: '1',
//       title: 'Daily Standup Briefing',
//       startMinutes: 9 * 60,
//       durationMinutes: 30,
//       isActive: true,
//       accentColor: _orange,
//     ),
//     TaskEvent(
//       id: '2',
//       title: 'System Audit & Backup',
//       startMinutes: 10 * 60 + 30,
//       durationMinutes: 60,
//       accentColor: const Color(0xFF2A2A2A),
//     ),
//     TaskEvent(
//       id: '3',
//       title: 'UI/UX Review',
//       startMinutes: 14 * 60,
//       durationMinutes: 90,
//       accentColor: const Color(0xFF3B2F5E),
//     ),
//   ];
//   // void _updateEvent(String id, {int? startMinutes, int? durationMinutes}) {
//   //   setState(() {
//   //     final idx = _events.indexWhere((e) => e.id == id);
//   //     if (idx == -1) return;
//   //     final e = _events[idx];
//   //     _events[idx] = e.copyWith(
//   //       startMinutes: startMinutes,
//   //       durationMinutes: durationMinutes,
//   //     );
//   //   });
//   // }
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFF0E0E0E),
//       body: SafeArea(
//         child: Column(
//           children: [
//             const _DateHeader(),
//             Expanded(
//               child: TimelineBody(
//                 events: _events,
//                 onEventChanged: _updateEvent,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// ── Timeline body ─────────────────────────────────────────────────────────────

class TimelineBody extends StatefulWidget {
  final List<TaskEvent> events;
  final void Function(Task curTask, {int? startMinutes, int? durationMinutes})
      onEventChanged;

  const TimelineBody({required this.events, required this.onEventChanged});

  @override
  State<TimelineBody> createState() => TimelineBodyState();
}

class TimelineBodyState extends State<TimelineBody> {
  // Drag state
  String? _draggingId;
  double _dragStartDy = 0;
  int _dragStartMinutes = 0;

  // Resize state
  String? _resizingId;
  double _resizeStartDy = 0;
  int _resizeStartDuration = 0;

  // Ghost (preview) values while dragging/resizing
  int? _ghostStart;
  int? _ghostDuration;

  static const _totalMinutes = (_endHour - _startHour) * 60;
  static const _totalHeight = (_endHour - _startHour) * _hourHeight;
  static const _resizeHandleHeight = 18.0;
  static const _minDuration = 15; // min 15 min event

  Map<String, _EventLayoutInfo> _computeLayout(List<TaskEvent> events) {
    if (events.isEmpty) return {};

    final sorted = List<TaskEvent>.from(events);

    // ── КРИТИЧЕСКОЕ ИЗМЕНЕНИЕ ──────────────────────────────────────────────────
    // Сортируем события на основе их ИЗНАЧАЛЬНОГО положения в widget.events.
    // Это гарантирует, что относительный порядок колонок (кто левее, кто правее)
    // останется неизменным в процессе всего перетаскивания.
    sorted.sort((a, b) {
      final origA =
          widget.events.firstWhere((e) => e.task.id == a.task.id, orElse: () => a);
      final origB =
          widget.events.firstWhere((e) => e.task.id == b.task.id, orElse: () => b);
      return origA.startMinutes.compareTo(origB.startMinutes);
    });

    final Map<String, _EventLayoutInfo> layoutMap = {};

    // Группируем события в кластеры пересечений (используем текущие ghost-минуты)
    List<List<TaskEvent>> clusters = [];
    List<TaskEvent> currentCluster = [];
    int? clusterEndMinutes;

    for (var e in sorted) {
      if (currentCluster.isEmpty) {
        currentCluster.add(e);
        clusterEndMinutes = e.endMinutes;
      } else if (e.startMinutes < clusterEndMinutes!) {
        // Пересечение зафиксировано
        currentCluster.add(e);
        if (e.endMinutes > clusterEndMinutes) {
          clusterEndMinutes = e.endMinutes;
        }
      } else {
        clusters.add(currentCluster);
        currentCluster = [e];
        clusterEndMinutes = e.endMinutes;
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    // Распределяем по колонкам внутри кластера
    for (var cluster in clusters) {
      List<List<TaskEvent>> columns = [];

      for (var e in cluster) {
        bool placed = false;
        for (var col in columns) {
          if (col.last.endMinutes <= e.startMinutes) {
            col.add(e);
            placed = true;
            break;
          }
        }
        if (!placed) {
          columns.add([e]);
        }
      }

      int totalCols = columns.length;
      for (int i = 0; i < totalCols; i++) {
        for (var e in columns[i]) {
          layoutMap[e.task.id] = _EventLayoutInfo(
            i / totalCols,
            1.0 / totalCols,
          );
        }
      }
    }

    return layoutMap;
  }
  // ── Drag handlers ──────────────────────────────────────────────────────────

  void _onDragStart(TaskEvent e, DragStartDetails d) {
    HapticFeedback.lightImpact();
    setState(() {
      _draggingId = e.task.id;
      _dragStartDy = d.globalPosition.dy;
      _dragStartMinutes = e.startMinutes;
      _ghostStart = e.startMinutes;
      _ghostDuration = e.durationMinutes;
    });
  }

  void _onDragUpdate(TaskEvent e, DragUpdateDetails d) {
    final dyDelta = d.globalPosition.dy - _dragStartDy;
    final minutesDelta = (dyDelta / _hourHeight * 60).round();
    int newStart = _snapToGrid(_dragStartMinutes + minutesDelta);

    // Clamp within timeline
    newStart = newStart.clamp(
      _startHour * 60,
      _endHour * 60 - e.durationMinutes,
    );

    setState(() => _ghostStart = newStart);
  }

  void _onDragEnd(TaskEvent e, DragEndDetails d) {
    if (_ghostStart != null) {
      widget.onEventChanged(e.task, startMinutes: _ghostStart);
    }
    setState(() {
      _draggingId = null;
      _ghostStart = null;
      _ghostDuration = null;
    });
  }

  // ── Resize handlers ────────────────────────────────────────────────────────

  void _onResizeStart(TaskEvent e, DragStartDetails d) {
    HapticFeedback.lightImpact();
    setState(() {
      _resizingId = e.task.id;
      _resizeStartDy = d.globalPosition.dy;
      _resizeStartDuration = e.durationMinutes;
      _ghostStart = e.startMinutes;
      _ghostDuration = e.durationMinutes;
    });
  }

  void _onResizeUpdate(TaskEvent e, DragUpdateDetails d) {
    final dyDelta = d.globalPosition.dy -
        _resizeStartDy; // По сути длина события в пикселях
    final minutesDelta = (dyDelta / _hourHeight * 60).round(); //В минутах
    int newDuration = _snapToGrid(_resizeStartDuration + minutesDelta)
        .clamp(_minDuration, _totalMinutes);

    // Don't push past end of timeline
    final maxDuration = _endHour * 60 - e.startMinutes;
    newDuration = newDuration.clamp(_minDuration, maxDuration);

    setState(() => _ghostDuration = newDuration);
  }

  void _onResizeEnd(TaskEvent e, DragEndDetails d) {
    if (_ghostDuration != null) {
      widget.onEventChanged(e.task, durationMinutes: _ghostDuration);
    }
    setState(() {
      _resizingId = null;
      _ghostStart = null;
      _ghostDuration = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Для реактивного изменения сетки во время перетаскивания
    // подменяем исходные данные на ghost-значения интерактивного события
    final displayEvents = widget.events.map((e) {
      if (e.task.id == _draggingId || e.task.id == _resizingId) {
        return e.copyWith(
          startMinutes: _ghostStart,
          durationMinutes:  _ghostDuration,
        );
      }
      return e;
    }).toList();

    // Считаем геометрию для всех карточек
    final layouts = _computeLayout(displayEvents);

    return LayoutBuilder(builder: (context, constraints) {
      // Вычисляем доступную ширину для карточек (минус левый лейбл времени и отступы)
      final availableWidth = constraints.maxWidth - _leftLabelWidth - 24;

      return SingleChildScrollView(
        // Disable scroll while dragging/resizing so only the event moves
        physics: (_draggingId != null || _resizingId != null)
            ? const NeverScrollableScrollPhysics()
            : const ClampingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 8),
        child: SizedBox(
          height: _totalHeight + 24,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Hour grid
              ..._buildHourRows(),

              // Now line

              // Events
              ...widget.events.map((e) {
                final layout = layouts[e.task.id] ?? _EventLayoutInfo(0.0, 1.0);
                return _buildDraggableEvent(e, layout, availableWidth);
              }),
              _buildNowLine(),
            ],
          ),
        ),
      );
    });
  }

  // ── Hour grid ──────────────────────────────────────────────────────────────

  List<Widget> _buildHourRows() {
    final totalHours = _endHour - _startHour;
    return List.generate(totalHours + 1, (i) {
      final hour = _startHour + i;
      final y = i * _hourHeight;
      return Positioned(
        top: y,
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
            Expanded(
                child: Container(height: 1, color: const Color(0xFF2A2A2A))),
          ],
        ),
      );
    });
  }

  // ── Now line ─────────────────────────────────────────────────────────────────

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
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: _orange,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 1.5),
              painter: _DashedLinePainter(color: _orange),
            ),
          ),
        ],
      ),
    );
  }

  // ── Draggable event ────────────────────────────────────────────────────────

  Widget _buildDraggableEvent(
      TaskEvent e, _EventLayoutInfo layout, double availableWidth) {
    final isDragging = _draggingId == e.task.id;
    final isResizing = _resizingId == e.task.id;
    final isInteracting = isDragging || isResizing;

    // Use ghost values while interacting
    final displayStart =
        isInteracting ? (_ghostStart ?? e.startMinutes) : e.startMinutes;
    final displayDuration = isInteracting
        ? (_ghostDuration ?? e.durationMinutes)
        : e.durationMinutes;

    final top = (displayStart - _startHour * 60) / 60 * _hourHeight;
    final height = displayDuration / 60 * _hourHeight;

    // Рассчитываем горизонтальные координаты на основе переданного layout
    final eventWidth = availableWidth * layout.widthFactor;
    final eventLeft =
        _leftLabelWidth + 12 + (availableWidth * layout.leftFactor);

    return Positioned(
      top: top + 6,
      left: isDragging ? _leftLabelWidth + 12 : eventLeft + 2,
      width: isDragging ? availableWidth : eventWidth - 4,
      height: height + 4,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: isDragging ? 0.75 : 1.0,
        child: _EventTile(
          event: e,
          height: height + 4,
          isDragging: isDragging,
          isResizing: isResizing,
          onDragStart: (d) => _onDragStart(e, d),
          onDragUpdate: (d) => _onDragUpdate(e, d),
          onDragEnd: (d) => _onDragEnd(e, d),
          onResizeStart: (d) => _onResizeStart(e, d),
          onResizeUpdate: (d) => _onResizeUpdate(e, d),
          onResizeEnd: (d) => _onResizeEnd(e, d),
          ghostStart: isInteracting ? _ghostStart : null,
          ghostDuration: isInteracting ? _ghostDuration : null,
        ),
      ),
    );
  }
}

// ── Dashed line painter ───────────────────────────────────────────────────────

class _DashedLinePainter extends CustomPainter {
  final Color color;
  final double dashWidth;
  final double dashGap;

  _DashedLinePainter({
    required this.color,
    this.dashWidth = 6.0,
    this.dashGap = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(150)
      ..strokeWidth = size.height
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(
          (startX + dashWidth).clamp(0.0, size.width),
          size.height / 2,
        ),
        paint,
      );
      startX += dashWidth + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) {
    return color != oldDelegate.color ||
        dashWidth != oldDelegate.dashWidth ||
        dashGap != oldDelegate.dashGap;
  }
}

// ── Event tile ────────────────────────────────────────────────────────────────

class _EventTile extends StatelessWidget {
  final TaskEvent event;
  final double height;
  final bool isDragging;
  final bool isResizing;

  final void Function(DragStartDetails) onDragStart;
  final void Function(DragUpdateDetails) onDragUpdate;
  final void Function(DragEndDetails) onDragEnd;

  final void Function(DragStartDetails) onResizeStart;
  final void Function(DragUpdateDetails) onResizeUpdate;
  final void Function(DragEndDetails) onResizeEnd;

  final int? ghostStart;
  final int? ghostDuration;

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

  TimeOfDay _minutesToTime(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);

  @override
  Widget build(BuildContext context) {
    final accent = event.accentColor;
    final isActive = event.isActive;
    final isInteracting = isDragging || isResizing;

    // Display times: use ghost when dragging/resizing
    final start =
        ghostStart != null ? _minutesToTime(ghostStart!) : event.startTime;
    final end = ghostStart != null && ghostDuration != null
        ? _minutesToTime(ghostStart! + ghostDuration!)
        : ghostDuration != null
            ? _minutesToTime(event.startMinutes + ghostDuration!)
            : event.endTime;

    return Stack(
      children: [
        // ── Main card (drag zone) ───────────────────────────────────────────
        GestureDetector(
          onVerticalDragStart: onDragStart,
          onVerticalDragUpdate: onDragUpdate,
          onVerticalDragEnd: onDragEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            decoration: BoxDecoration(
              color:
                  isActive ? const Color(0xFF1C1006) : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isInteracting ? accent.withOpacity(0.9) : accent,
                width: isInteracting ? 2 : (isActive ? 1.5 : 1),
              ),
              boxShadow: isInteracting
                  ? [
                      BoxShadow(
                        color: accent.withOpacity(0.35),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
            child: Row(
              children: [
                // Status circle
                Container(
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
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (height > 36)
                        Text(
                          event.title,
                          style: TextStyle(
                            color: isActive ? accent : Colors.white,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      if (height > 52)
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            '${_fmtTime(start)} – ${_fmtTime(end)}',
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
                        ),
                    ],
                  ),
                ),
                // Drag hint icon
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

        // ── Resize handle at bottom ─────────────────────────────────────────
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 18,
          child: GestureDetector(
            onVerticalDragStart: onResizeStart,
            onVerticalDragUpdate: onResizeUpdate,
            onVerticalDragEnd: onResizeEnd,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Center(
                child: Container(
                  width: 32,
                  height: 3,
                  // decoration: BoxDecoration(
                  //   color: isResizing ? accent : Colors.white10,
                  //   borderRadius: BorderRadius.circular(2),
                  // ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── App bar ───────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  const _AppBar();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration:
                const BoxDecoration(color: _orange, shape: BoxShape.circle),
            child: const Icon(Icons.person, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('AI Life Architect',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const Spacer(),
          const Icon(Icons.search, color: Colors.white70),
          const SizedBox(width: 16),
          const Icon(Icons.settings_outlined, color: Colors.white70),
        ],
      ),
    );
  }
}

// ── Date header ───────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 60),
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16),
        //   child: Container(
        //     decoration: BoxDecoration(
        //         color: const Color(0xFF1A1A1A),
        //         borderRadius: BorderRadius.circular(12)),
        //     child: Row(
        //       children: ['Day', 'Week', 'Month'].map((label) {
        //         final isActive = label == 'Day';
        //         return Expanded(
        //           child: Container(
        //             margin: const EdgeInsets.all(4),
        //             padding: const EdgeInsets.symmetric(vertical: 8),
        //             decoration: BoxDecoration(
        //               color: isActive ? _orange : Colors.transparent,
        //               borderRadius: BorderRadius.circular(8),
        //             ),
        //             child: Text(label,
        //                 textAlign: TextAlign.center,
        //                 style: TextStyle(
        //                     color: isActive ? Colors.white : Colors.white54,
        //                     fontWeight: isActive
        //                         ? FontWeight.w600
        //                         : FontWeight.normal)),
        //           ),
        //         );
        //       }).toList(),
        //     ),
        //   ),
        // ),
        // const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.chevron_left, color: Colors.white70),
            SizedBox(width: 12),
            Column(children: [
              Text('TODAY',
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
              Text('Oct 24, 2024',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700)),
            ]),
            SizedBox(width: 12),
            Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Bottom input ──────────────────────────────────────────────────────────────

class _BottomInput extends StatelessWidget {
  const _BottomInput();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(24)),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text('I need to...',
                  style: TextStyle(color: Colors.white38, fontSize: 15)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
                color: _orange, borderRadius: BorderRadius.circular(24)),
            child: const Row(children: [
              Icon(Icons.add, color: Colors.white, size: 18),
              SizedBox(width: 4),
              Text('Add',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override
  Widget build(BuildContext context) {
    final chips = [
      (Icons.priority_high, 'High Priority'),
      (Icons.access_time, 'Set Time'),
      (Icons.tag, 'Category'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: chips
            .map((c) => Container(
                  margin: const EdgeInsets.only(right: 8, bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF2A2A2A)),
                  ),
                  child: Row(children: [
                    Icon(c.$1, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(c.$2,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
                ))
            .toList(),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  // Передаем текущий индекс и колбэк через конструктор
  _BottomNav({
    required this.currentIndex,
    required this.onTap,
  });
  final items = [
    (Icons.bolt, 'Pulse'),
    (Icons.list_alt, 'Tasks'),
    (Icons.grid_view, 'Projects'),
    (Icons.menu_book_outlined, 'Library'),
    (Icons.track_changes, 'Goals'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A)))),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final icon = entry.value.$1;
          final label = entry.value.$2;

          // Теперь активность зависит от переданного извне индекса
          final isActive = index == currentIndex;

          return GestureDetector(
            behavior: HitTestBehavior.opaque, // Чтобы кликалась вся область, а не только иконка
            onTap: () => onTap(index),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
                  icon,
                  color: isActive ? _orange : Colors.white38,
                  size: 22,
                ),
              const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? _orange : Colors.white38,
                    fontSize: 10,
                  ),
                ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}


