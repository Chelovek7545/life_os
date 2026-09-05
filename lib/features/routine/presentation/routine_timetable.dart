import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/routine_models.dart';
import 'routine_style.dart';
import 'routine_views.dart';

/// A spreadsheet-like view of the same occurrences, never a separate journal.
class RoutineTimetable extends StatefulWidget {
  const RoutineTimetable({
    super.key,
    required this.entries,
    required this.date,
    required this.today,
    required this.onToggle,
    required this.onEdit,
    required this.onAdd,
    this.dayLabels = const {},
    this.onDayLabel,
  });
  final List<RoutineOccurrence> entries;
  final DateTime date, today;
  final OccurrenceAction onToggle, onEdit;
  final void Function(DateTime, int?) onAdd;
  final Map<int, String> dayLabels;
  final ValueChanged<int>? onDayLabel;
  @override
  State<RoutineTimetable> createState() => _RoutineTimetableState();
}

class _RoutineTimetableState extends State<RoutineTimetable> {
  final _x = ScrollController(),
      _header = ScrollController(),
      _y = ScrollController();
  @override
  void initState() {
    super.initState();
    _x.addListener(() {
      if (_header.hasClients) {
        _header.jumpTo(_x.offset);
      }
    });
  }

  @override
  void dispose() {
    _x.dispose();
    _header.dispose();
    _y.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final monday = mondayOf(widget.date);
    final days = List.generate(7, (i) => shiftDay(monday, i));
    final boundaries = <int>{};
    final segments = <(RoutineOccurrence, int, int, int)>[];
    final untimed = <int, List<RoutineOccurrence>>{};
    for (final o in widget.entries) {
      for (var i = 0; i < 7; i++) {
        if (!o.slot.timed) {
          if (dayKey(o.date) == dayKey(days[i])) {
            (untimed[i] ??= []).add(o);
          }
          continue;
        }
        if (o.startsAt!.isBefore(shiftDay(days[i], 1)) &&
            o.endsAt!.isAfter(days[i])) {
          final start = math.max(0, o.startsAt!.difference(days[i]).inMinutes);
          final end = math.min(1440, o.endsAt!.difference(days[i]).inMinutes);
          boundaries.addAll([start, end]);
          segments.add((o, i, start, end));
        }
      }
    }
    if (boundaries.isEmpty) {
      boundaries.addAll([540, 600, 720, 780, 1080, 1140]);
    }
    final ticks = boundaries.toList()..sort();
    final rows = <(int?, int?)>[
      for (var i = 0; i < ticks.length - 1; i++) (ticks[i], ticks[i + 1]),
      (null, null),
    ];
    List<RoutineOccurrence> cell(int row, int day) => rows[row].$1 == null
        ? untimed[day] ?? []
        : segments
              .where(
                (s) =>
                    s.$2 == day && s.$3 < rows[row].$2! && s.$4 > rows[row].$1!,
              )
              .map((s) => s.$1)
              .toList();
    final heights = List.generate(
      rows.length,
      (r) => math.max(
        62.0,
          List.generate(7, (d) => cell(r, d).length).reduce(math.max) * 54.0 + 2,
      ),
    );
    const timeWidth = 104.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnWidth = math.max(
          156.0,
          (constraints.maxWidth - timeWidth) / 7,
        );
        Widget timeCell(int r) => Container(
          height: heights[r],
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: p.border.withValues(alpha: .6)),
            ),
          ),
          child: Text(
            rows[r].$1 == null
                ? 'В течение\nдня'
                : '${clockLabel(rows[r].$1!)}–\n${rows[r].$2 == 1440 ? '24:00' : clockLabel(rows[r].$2!)}',
            style: TextStyle(fontSize: 11, color: p.secondary, height: 1.4),
          ),
        );
        Widget contentCell(int r, int d) {
          final entries = cell(r, d);
          return Container(
            width: columnWidth,
            height: heights[r],
            decoration: BoxDecoration(
              color: dayKey(days[d]) == dayKey(widget.today)
                  ? routineAccent.withValues(alpha: .035)
                  : null,
              border: Border(
                top: BorderSide(color: p.border.withValues(alpha: .6)),
                left: BorderSide(color: p.border.withValues(alpha: .25)),
              ),
            ),
            child: entries.isEmpty
                ? InkWell(
                    onTap: () => widget.onAdd(days[d], rows[r].$1),
                    child: const Center(
                      child: Text(
                        '—',
                        style: TextStyle(color: Color(0xFF8B93A7)),
                      ),
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final o in entries)
                        SizedBox(
                          height: 54,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: RoutineCheck(
                                  occurrence: o,
                                  today: widget.today,
                                  onToggle: widget.onToggle,
                                ),
                              ),
                              Expanded(
                                child: Tooltip(
                                  message:
                                      '${o.item.title}\n${o.slot.timeLabel} · ${o.item.sphere}${o.cancelled ? '\nОтменено' : ''}',
                                  child: InkWell(
                                    onTap: () => widget.onEdit(o),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        o.item.title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.3,
                                          color: o.cancelled
                                              ? p.secondary
                                              : p.text,
                                          decoration: o.completed || o.cancelled
                                              ? TextDecoration.lineThrough
                                              : null,
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
          );
        }

        return Column(
          children: [
            Row(
              children: [
                const SizedBox(
                  width: timeWidth,
                  height: 64,
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Время',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _header,
                    physics: const NeverScrollableScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          SizedBox(
                            width: columnWidth,
                            height: 64,
                            child: Tooltip(
                              message:
                                  'Изменить подпись дня: очный, онлайн, выходной…',
                              child: InkWell(
                                onTap: widget.onDayLabel == null
                                    ? null
                                    : () => widget.onDayLabel!(i + 1),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${weekdayLabels[i]}${widget.dayLabels[i + 1]?.isNotEmpty == true ? ' (${widget.dayLabels[i + 1]})' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              dayKey(days[i]) ==
                                                  dayKey(widget.today)
                                              ? routineAccent
                                              : p.text,
                                        ),
                                      ),
                                      Text(
                                        '${days[i].day}.${days[i].month.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: p.secondary,
                                        ),
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
              ],
            ),
            Expanded(
              child: Scrollbar(
                controller: _y,
                child: SingleChildScrollView(
                  controller: _y,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: timeWidth,
                        child: Column(
                          children: [
                            for (var r = 0; r < rows.length; r++) timeCell(r),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Scrollbar(
                          controller: _x,
                          thumbVisibility: true,
                          notificationPredicate: (n) =>
                              n.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _x,
                            scrollDirection: Axis.horizontal,
                            child: Column(
                              children: [
                                for (var r = 0; r < rows.length; r++)
                                  Row(
                                    children: [
                                      for (var d = 0; d < 7; d++)
                                        contentCell(r, d),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                'Длинное занятие может занимать несколько строк. Галочка общая — в итогах оно считается один раз.',
                style: TextStyle(fontSize: 10, color: p.secondary),
              ),
            ),
          ],
        );
      },
    );
  }
}
