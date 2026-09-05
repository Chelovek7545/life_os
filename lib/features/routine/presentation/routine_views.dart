import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/routine_models.dart';
import 'routine_style.dart';

typedef OccurrenceAction = void Function(RoutineOccurrence occurrence);

class RoutineCheck extends StatelessWidget {
  const RoutineCheck({
    super.key,
    required this.occurrence,
    required this.today,
    required this.onToggle,
    this.pending = false,
  });
  final RoutineOccurrence occurrence;
  final DateTime today;
  final OccurrenceAction onToggle;
  final bool pending;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: occurrence.cancelled
        ? 'Отменено на эту дату'
        : occurrence.date.isAfter(routineDay(today))
        ? 'Будущие дни нельзя отмечать'
        : occurrence.completed
        ? 'Снять отметку'
        : 'Отметить выполненным',
    child: Checkbox(
      semanticLabel: '${occurrence.item.title}, ${dayKey(occurrence.date)}',
      value: occurrence.completed && !occurrence.cancelled,
      onChanged:
          pending ||
              occurrence.cancelled ||
              occurrence.date.isAfter(routineDay(today))
          ? null
          : (_) => onToggle(occurrence),
    ),
  );
}

class RoutineDayView extends StatefulWidget {
  const RoutineDayView({
    super.key,
    required this.entries,
    required this.today,
    required this.onToggle,
    required this.onEdit,
    required this.onMenu,
    required this.onAdd,
    this.pending = const {},
  });
  final List<RoutineOccurrence> entries;
  final DateTime today;
  final OccurrenceAction onToggle;
  final OccurrenceAction onEdit;
  final void Function(RoutineOccurrence, String) onMenu;
  final VoidCallback onAdd;
  final Set<String> pending;
  @override
  State<RoutineDayView> createState() => _RoutineDayViewState();
}

class _RoutineDayViewState extends State<RoutineDayView> {
  bool _hideDone = false;
  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final stats = RoutineStats(widget.entries);
    final visible = widget.entries
        .where((o) => !_hideDone || !o.completed)
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stats.total == 0
                          ? 'Свободный день'
                          : '${stats.done} из ${stats.total} выполнено',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    stats.rate == null
                        ? '—'
                        : '${(stats.rate! * 100).round()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: stats.rate ?? 0,
                  minHeight: 6,
                  backgroundColor: p.inset,
                  color: routineAccent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${minutesLabel(stats.doneMinutes)} / ${minutesLabel(stats.plannedMinutes)} · плановое время',
                style: TextStyle(fontSize: 12, color: p.secondary),
              ),
              Row(
                children: [
                  Checkbox(
                    value: _hideDone,
                    onChanged: (v) => setState(() => _hideDone = v!),
                  ),
                  const Expanded(
                    child: Text(
                      'Скрыть выполненные',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onAdd,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Пункт'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? RoutineEmpty(
                  title: stats.total == 0
                      ? 'Место для вашего дня'
                      : 'Всё отмечено',
                  subtitle: stats.total == 0
                      ? 'Добавьте разовый пункт или примените шаблон недели.'
                      : 'Можно отдохнуть и вернуться завтра.',
                  action: stats.total == 0
                      ? OutlinedButton(
                          onPressed: widget.onAdd,
                          child: const Text('Добавить пункт'),
                        )
                      : null,
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    for (final timed in [true, false])
                      if (visible.any((o) => o.slot.timed == timed)) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 12, 0, 8),
                          child: Text(
                            timed ? 'ПО ВРЕМЕНИ' : 'В ТЕЧЕНИЕ ДНЯ',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                              color: p.secondary,
                            ),
                          ),
                        ),
                        ...visible
                            .where((o) => o.slot.timed == timed)
                            .map((o) => _row(context, o)),
                      ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, RoutineOccurrence o) {
    final p = paletteOf(context);
    final current =
        !o.cancelled &&
        o.slot.timed &&
        !widget.today.isBefore(o.startsAt!) &&
        widget.today.isBefore(o.endsAt!);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: current
            ? routineAccent.withValues(alpha: .09)
            : p.inset.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(14),
        border: current
            ? Border.all(color: routineAccent.withValues(alpha: .5))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: Color(o.item.color),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          RoutineCheck(
            occurrence: o,
            today: widget.today,
            onToggle: widget.onToggle,
            pending: widget.pending.contains(o.id),
          ),
          Expanded(
            child: InkWell(
              onTap: () => widget.onEdit(o),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.item.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        decoration: o.completed && !o.cancelled
                            ? TextDecoration.lineThrough
                            : null,
                        color: o.cancelled ? p.secondary : p.text,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${o.slot.timeLabel} · ${o.item.sphere}',
                      style: TextStyle(fontSize: 11, color: p.secondary),
                    ),
                    if (o.cancelled || o.changed || current)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          o.cancelled
                              ? 'Отменено'
                              : current
                              ? 'Сейчас'
                              : 'Изменено на эту дату',
                          style: TextStyle(
                            fontSize: 10,
                            color: current ? routineAccent : p.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Действия с занятием',
            onSelected: (v) => widget.onMenu(o, v),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Изменить на эту дату'),
              ),
              if (!o.added)
                const PopupMenuItem(
                  value: 'template',
                  child: Text('Изменить в шаблоне'),
                ),
              if (!o.cancelled)
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Отменить на эту дату'),
                ),
              if (o.changed || o.cancelled)
                PopupMenuItem(
                  value: 'restore',
                  child: Text(
                    o.added ? 'Убрать разовый пункт' : 'Вернуть по шаблону',
                  ),
                ),
            ],
            icon: Icon(Icons.more_horiz, size: 20, color: p.secondary),
          ),
        ],
      ),
    );
  }
}

class RoutineWeekView extends StatefulWidget {
  const RoutineWeekView({
    super.key,
    required this.entries,
    required this.date,
    required this.today,
    required this.onToggle,
    required this.onEdit,
    required this.onMove,
    required this.onNew,
  });
  final List<RoutineOccurrence> entries;
  final DateTime date;
  final DateTime today;
  final OccurrenceAction onToggle;
  final OccurrenceAction onEdit;
  final void Function(RoutineOccurrence, int start, int end) onMove;
  final void Function(DateTime, int) onNew;
  @override
  State<RoutineWeekView> createState() => _RoutineWeekViewState();
}

class _RoutineWeekViewState extends State<RoutineWeekView> {
  final _vertical = ScrollController(initialScrollOffset: 324);
  final _horizontal = ScrollController();
  @override
  void dispose() {
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    final monday = mondayOf(widget.date);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(952.0, constraints.maxWidth);
        final dayWidth = (width - 56) / 7;
        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: true,
          notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const SizedBox(width: 56),
                        for (var d = 0; d < 7; d++)
                          SizedBox(
                            width: dayWidth,
                            child: Center(
                              child: Text(
                                '${weekdayLabels[d]}  ${shiftDay(monday, d).day}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      dayKey(shiftDay(monday, d)) ==
                                          dayKey(widget.today)
                                      ? routineAccent
                                      : p.text,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 88,
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: p.border)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 56,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              'Без\nчасов',
                              style: TextStyle(fontSize: 9, color: p.secondary),
                            ),
                          ),
                        ),
                        for (var d = 0; d < 7; d++)
                          SizedBox(
                            width: dayWidth,
                            child: ListView(
                              children: widget.entries
                                  .where(
                                    (o) =>
                                        dayKey(o.date) ==
                                            dayKey(shiftDay(monday, d)) &&
                                        !o.slot.timed &&
                                        !o.cancelled,
                                  )
                                  .map(
                                    (o) => SizedBox(
                                      height: 34,
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
                                            child: InkWell(
                                              onTap: () => widget.onEdit(o),
                                              child: Text(
                                                o.item.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Scrollbar(
                      controller: _vertical,
                      child: SingleChildScrollView(
                        controller: _vertical,
                        child: SizedBox(
                          height: 1296,
                          child: Stack(
                            children: [
                              for (var hour = 0; hour < 24; hour++)
                                Positioned(
                                  top: hour * 54,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 56,
                                        child: Text(
                                          '${hour.toString().padLeft(2, '0')}:00',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: p.secondary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          height: 1,
                                          color: p.border.withValues(alpha: .6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              for (var d = 0; d < 7; d++)
                                Positioned(
                                  left: 56 + d * dayWidth,
                                  width: dayWidth,
                                  top: 0,
                                  bottom: 0,
                                  child: _dayColumn(
                                    shiftDay(monday, d),
                                    dayWidth,
                                    p,
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
        );
      },
    );
  }

  Widget _dayColumn(DateTime day, double width, RoutinePalette p) {
    final entries = widget.entries
        .where(
          (o) =>
              o.slot.timed &&
              !o.cancelled &&
              o.startsAt!.isBefore(shiftDay(day, 1)) &&
              o.endsAt!.isAfter(day),
        )
        .toList();
    Offset? down;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (d) => down = d.localPosition,
      onDoubleTap: () {
        final start = (((down?.dy ?? 0) / .9 / 15).floor() * 15).clamp(0, 1425);
        widget.onNew(day, start);
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: p.border.withValues(alpha: .4)),
          ),
        ),
        child: Stack(
          children: [
            for (final o in entries)
              _WeekBlock(
                key: ValueKey('${o.id}/${dayKey(day)}'),
                o: o,
                day: day,
                today: widget.today,
                onToggle: widget.onToggle,
                onEdit: widget.onEdit,
                onMove: widget.onMove,
              ),
            if (dayKey(day) == dayKey(widget.today))
              Positioned(
                top: (widget.today.hour * 60 + widget.today.minute) * .9,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Container(height: 1.5, color: routineAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekBlock extends StatefulWidget {
  const _WeekBlock({
    super.key,
    required this.o,
    required this.day,
    required this.today,
    required this.onToggle,
    required this.onEdit,
    required this.onMove,
  });
  final RoutineOccurrence o;
  final DateTime day;
  final DateTime today;
  final OccurrenceAction onToggle;
  final OccurrenceAction onEdit;
  final void Function(RoutineOccurrence, int, int) onMove;
  @override
  State<_WeekBlock> createState() => _WeekBlockState();
}

class _WeekBlockState extends State<_WeekBlock> {
  double _drag = 0;
  bool _resize = false;
  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final p = paletteOf(context);
    final continuation = dayKey(o.date) != dayKey(widget.day);
    final start = continuation ? 0 : o.slot.start!;
    final end = continuation ? o.slot.end! - 1440 : math.min(o.slot.end!, 1440);
    final canMove = !continuation && !o.date.isBefore(routineDay(widget.today));
    final delta = (_drag / .9 / 15).round() * 15;
    final top = ((start + (_resize ? 0 : delta)) * .9).clamp(0.0, 1280.0);
    final height = math.max(
      14.0,
      (end - start + (_resize ? delta : 0)) * .9 - 3,
    );
    void finish() {
      final newStart = _resize
          ? o.slot.start!
          : (o.slot.start! + delta).clamp(0, 1439);
      final newEnd = _resize
          ? (o.slot.end! + delta).clamp(newStart + 1, newStart + 1440)
          : newStart + o.slot.minutes;
      setState(() => _drag = 0);
      if (delta != 0) {
        widget.onMove(o, newStart, newEnd);
      }
    }

    return Positioned(
      top: top,
      left: 4,
      right: 4,
      height: height,
      child: GestureDetector(
        onTap: () => widget.onEdit(o),
        onVerticalDragStart: canMove
            ? (_) => setState(() {
                _resize = false;
                _drag = 0;
              })
            : null,
        onVerticalDragUpdate: canMove
            ? (d) => setState(() => _drag += d.delta.dy)
            : null,
        onVerticalDragEnd: canMove ? (_) => finish() : null,
        onVerticalDragCancel: () => setState(() => _drag = 0),
        child: Tooltip(
          message:
              '${o.item.title}\n${o.slot.timeLabel}\n${o.item.sphere}${continuation ? '\nПродолжение предыдущего дня' : ''}',
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Color(o.item.color).withValues(alpha: p.dark ? .22 : .18),
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(width: 3, color: Color(o.item.color)),
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    6,
                    height < 30 ? 0 : 4,
                    height < 70 ? 24 : 4,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (height >= 14)
                        Text(
                          continuation ? '↳ ${o.item.title}' : o.item.title,
                          maxLines: height > 65 ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: height < 30 ? 9 : 11,
                            fontWeight: FontWeight.w500,
                            decoration: o.completed
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      if (height > 55)
                        Text(
                          o.slot.timeLabel,
                          style: TextStyle(fontSize: 9, color: p.secondary),
                        ),
                    ],
                  ),
                ),
                if (height >= 20)
                  Positioned(
                    right: 0,
                    bottom: 2,
                    child: SizedBox(
                      height: math.min(32, height - 2),
                      width: height < 70 ? 24 : 36,
                      child: RoutineCheck(
                        occurrence: o,
                        today: widget.today,
                        onToggle: widget.onToggle,
                      ),
                    ),
                  ),
                if (canMove && height > 30)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 10,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.resizeUpDown,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (_) => setState(() {
                          _resize = true;
                          _drag = 0;
                        }),
                        onVerticalDragUpdate: (d) =>
                            setState(() => _drag += d.delta.dy),
                        onVerticalDragEnd: (_) => finish(),
                        child: Center(
                          child: Container(
                            width: 20,
                            height: 2,
                            color: Color(o.item.color).withValues(alpha: .6),
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
    );
  }
}

class RoutineTrackerView extends StatefulWidget {
  const RoutineTrackerView({
    super.key,
    required this.entries,
    required this.from,
    required this.to,
    required this.today,
    required this.onToggle,
    required this.onDay,
  });
  final List<RoutineOccurrence> entries;
  final DateTime from;
  final DateTime to;
  final DateTime today;
  final OccurrenceAction onToggle;
  final ValueChanged<DateTime> onDay;
  @override
  State<RoutineTrackerView> createState() => _RoutineTrackerViewState();
}

class _RoutineTrackerViewState extends State<RoutineTrackerView> {
  String _sort = 'plan';
  final _x = ScrollController();
  final _header = ScrollController();
  final _y = ScrollController();
  @override
  void initState() {
    super.initState();
    _x.addListener(() {
      if (_header.hasClients && _header.offset != _x.offset) {
        _header.jumpTo(_x.offset.clamp(0, _header.position.maxScrollExtent));
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
    final dates = <DateTime>[];
    for (var d = widget.from; !d.isAfter(widget.to); d = shiftDay(d, 1)) {
      dates.add(d);
    }
    final groups = <String, List<RoutineOccurrence>>{};
    final cells = <String, List<RoutineOccurrence>>{};
    for (final o in widget.entries) {
      (groups[o.item.id] ??= []).add(o);
      (cells['${o.item.id}/${dayKey(o.date)}'] ??= []).add(o);
    }
    final ids = groups.keys.toList();
    if (_sort == 'title') {
      ids.sort(
        (a, b) =>
            groups[a]!.last.item.title.compareTo(groups[b]!.last.item.title),
      );
    } else if (_sort == 'progress') {
      double rate(String id) =>
          RoutineStats(
            groups[id]!.where((o) => !o.date.isAfter(routineDay(widget.today))),
          ).rate ??
          -1;
      ids.sort((a, b) => rate(b).compareTo(rate(a)));
    }
    const nameWidth = 180.0;
    const cellWidth = 42.0;
    const rowHeight = 48.0;
    if (ids.isEmpty) {
      return const RoutineEmpty(
        title: 'Здесь появится ваша регулярность',
        subtitle: 'Примените шаблон или выберите другой период.',
        icon: Icons.grid_view_rounded,
      );
    }
    Widget dateCell(DateTime d) => SizedBox(
      width: cellWidth,
      height: 52,
      child: InkWell(
        onTap: () => widget.onDay(d),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayLabels[d.weekday - 1],
              style: TextStyle(fontSize: 9, color: p.secondary),
            ),
            const SizedBox(height: 4),
            Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: dayKey(d) == dayKey(widget.today)
                    ? routineAccent
                    : p.text,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: nameWidth,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: PopupMenuButton<String>(
                  tooltip: 'Сортировка занятий',
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'plan', child: Text('По расписанию')),
                    PopupMenuItem(value: 'title', child: Text('По названию')),
                    PopupMenuItem(
                      value: 'progress',
                      child: Text('По выполнению'),
                    ),
                  ],
                  child: const Row(
                    children: [
                      Text('Занятие', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 8),
                      Icon(Icons.sort, size: 16),
                    ],
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
                    for (final d in dates) dateCell(d),
                    const SizedBox(
                      width: 100,
                      child: Text('Итого', textAlign: TextAlign.center),
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
                    width: nameWidth,
                    child: Column(
                      children: [
                        for (final id in ids)
                          Container(
                            height: rowHeight,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: p.border.withValues(alpha: .5),
                                ),
                              ),
                            ),
                            child: Text(
                              groups[id]!.last.item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        const SizedBox(
                          height: rowHeight,
                          child: Center(
                            child: Text(
                              'Итог дня',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
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
                            for (final id in ids)
                              Row(
                                children: [
                                  for (final d in dates)
                                    _cell(
                                      cells['$id/${dayKey(d)}'] ?? [],
                                      d,
                                      cellWidth,
                                      rowHeight,
                                      p,
                                    ),
                                  SizedBox(
                                    width: 100,
                                    height: rowHeight,
                                    child: Center(
                                      child: Text(
                                        _ratio(
                                          groups[id]!.where(
                                            (o) => !o.date.isAfter(
                                              routineDay(widget.today),
                                            ),
                                          ),
                                        ),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            Row(
                              children: [
                                for (final d in dates)
                                  SizedBox(
                                    width: cellWidth,
                                    height: rowHeight,
                                    child: Center(
                                      child: Text(
                                        d.isAfter(routineDay(widget.today))
                                            ? '—'
                                            : _ratio(
                                                widget.entries.where(
                                                  (o) =>
                                                      dayKey(o.date) ==
                                                      dayKey(d),
                                                ),
                                                percentOnly: true,
                                              ),
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 100),
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
          padding: const EdgeInsets.all(12),
          child: Text(
            '✓ выполнено    □ без отметки    — не запланировано    ⊘ отменено',
            style: TextStyle(fontSize: 10, color: p.secondary),
          ),
        ),
      ],
    );
  }

  String _ratio(
    Iterable<RoutineOccurrence> entries, {
    bool percentOnly = false,
  }) {
    final s = RoutineStats(entries);
    return s.total == 0
        ? '—'
        : percentOnly
        ? '${(s.rate! * 100).round()}%'
        : '${s.done}/${s.total} · ${(s.rate! * 100).round()}%';
  }

  Widget _cell(
    List<RoutineOccurrence> entries,
    DateTime date,
    double width,
    double height,
    RoutinePalette p,
  ) {
    final s = RoutineStats(entries);
    final future = date.isAfter(routineDay(widget.today));
    final label = entries.isEmpty
        ? '—'
        : s.total == 0
        ? '⊘'
        : s.total > 1
        ? '${s.done}/${s.total}'
        : s.done == 1
        ? '✓'
        : '□';
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Tooltip(
          message:
              '${dayKey(date)} · ${entries.isEmpty ? 'Не запланировано' : '${entries.first.item.title}: $label'}',
          child: TextButton(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              backgroundColor: s.done > 0
                  ? routineAccent.withValues(alpha: .2)
                  : p.inset.withValues(alpha: .5),
              foregroundColor: s.done > 0
                  ? (p.dark ? const Color(0xFFFFBA9D) : const Color(0xFF9B492D))
                  : p.secondary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: future || entries.isEmpty
                ? null
                : () {
                    if (s.total == 1 && entries.length == 1) {
                      widget.onToggle(entries.first);
                      return;
                    }
                    showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(
                          '${entries.first.item.title} · ${dayKey(date)}',
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: entries
                              .map(
                                (o) => ListTile(
                                  title: Text(o.slot.timeLabel),
                                  subtitle: o.cancelled
                                      ? const Text('Отменено')
                                      : null,
                                  leading: Icon(
                                    o.completed
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                  ),
                                  onTap: o.cancelled
                                      ? null
                                      : () {
                                          Navigator.pop(ctx);
                                          widget.onToggle(o);
                                        },
                                ),
                              )
                              .toList(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Закрыть'),
                          ),
                        ],
                      ),
                    );
                  },
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
        ),
      ),
    );
  }
}

class RoutineAnalyticsView extends StatelessWidget {
  const RoutineAnalyticsView({
    super.key,
    required this.entries,
    required this.previous,
    required this.today,
    required this.onDay,
    this.section = 'overview',
    this.periodLabel,
  });
  final List<RoutineOccurrence> entries;
  final List<RoutineOccurrence> previous;
  final DateTime today;
  final ValueChanged<DateTime> onDay;
  final String section;
  final String? periodLabel;
  @override
  Widget build(BuildContext context) {
    final s = RoutineStats(entries);
    final p = paletteOf(context);
    final old = RoutineStats(previous);
    if (s.total == 0 && s.cancelled == 0) {
      return const RoutineEmpty(
        title: 'История ещё впереди',
        subtitle:
            'Здесь появятся итоги завершённых дней.\nМожно включить сегодня для предварительного результата.',
        icon: Icons.insights_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (periodLabel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              periodLabel!,
              style: TextStyle(fontSize: 11, color: p.secondary),
            ),
          ),
        if (section == 'overview') ...[
          LayoutBuilder(
            builder: (context, c) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: c.maxWidth > 600 ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  child: RoutineMetric(
                    label: 'ВЫПОЛНЕНИЕ ПЛАНА',
                    value: s.rate == null ? '—' : '${(s.rate! * 100).round()}%',
                    caption:
                        '${s.done} из ${s.total} пунктов${old.rate == null || s.rate == null ? '' : ' · ${s.rate! >= old.rate! ? '+' : ''}${((s.rate! - old.rate!) * 100).round()} п.п.'}',
                  ),
                ),
                SizedBox(
                  width: c.maxWidth > 600 ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  child: RoutineMetric(
                    label: 'ДНИ СО ВСЕМИ ОТМЕТКАМИ',
                    value: '${s.fullDays}',
                    caption:
                        'из ${s.days.values.where((d) => d.total > 0).length} дней с планом',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          RoutineMetric(
            label: 'ПЛАНОВОЕ ВРЕМЯ ОТМЕЧЕННЫХ ЗАНЯТИЙ',
            value: minutesLabel(s.doneMinutes),
            caption:
                'из ${minutesLabel(s.plannedMinutes)} в расписании · это не измеренное время',
          ),
          const SizedBox(height: 24),
          const Text(
            'Выполнение по дням',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _dailyBars(context, s),
        ],
        if (section == 'regularity') ...[
          const Text(
            'Карта регулярности',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: (s.days.keys.toList()..sort()).map((key) {
              final d = s.days[key]!;
              return Tooltip(
                message: '$key · ${d.done}/${d.total}',
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: TextButton(
                    onPressed: () => onDay(DateTime.parse(key)),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: routineAccent.withValues(
                        alpha: .07 + (d.rate ?? 0) * .65,
                      ),
                      foregroundColor: p.text,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: Text(
                      '${DateTime.parse(key).day}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'По занятиям',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          ..._itemGroups(s).entries.map((g) {
            final stat = RoutineStats(g.value);
            final streak = s.streak(g.key, today);
            return _bar(
              context,
              g.value.last.item.title,
              '${stat.done}/${stat.total} · серия ${streak.$1}, лучшая ${streak.$2}',
              stat.rate ?? 0,
              Color(g.value.last.item.color),
            );
          }),
          const SizedBox(height: 20),
          const Text(
            'По дням недели',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          for (var day = 1; day <= 7; day++)
            Builder(
              builder: (_) {
                final stat = RoutineStats(
                  entries.where((o) => o.date.weekday == day),
                );
                return _bar(
                  context,
                  weekdayLabels[day - 1],
                  '${stat.done}/${stat.total} · ${stat.days.length} наблюдений',
                  stat.rate ?? 0,
                  routineAccent,
                );
              },
            ),
          Text(
            'Серии показаны в пределах выбранного периода. Отмены и свободные дни не прерывают серию.',
            style: TextStyle(fontSize: 11, color: p.secondary),
          ),
        ],
        if (section == 'balance') ...[
          const Text(
            'Место для каждой сферы',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Плановое время отмеченных занятий / всё запланированное время',
            style: TextStyle(color: p.secondary, fontSize: 12),
          ),
          const SizedBox(height: 20),
          ...s.spheres.entries.map(
            (g) => _bar(
              context,
              g.key,
              '${minutesLabel(g.value.doneMinutes)} / ${minutesLabel(g.value.plannedMinutes)} · ${g.value.done}/${g.value.total}',
              g.value.plannedMinutes == 0
                  ? 0
                  : g.value.doneMinutes / g.value.plannedMinutes,
              Color(g.value.planned.first.item.color),
            ),
          ),
          const SizedBox(height: 16),
          RoutineMetric(
            label: 'ПУНКТЫ БЕЗ ВРЕМЕНИ',
            value:
                '${s.planned.where((o) => !o.slot.timed && o.completed).length} / ${s.planned.where((o) => !o.slot.timed).length}',
            caption: 'Учитываются в выполнении плана, но не добавляют часы.',
          ),
          const SizedBox(height: 16),
          Text(
            'Отдых — полноценная часть плана. Здесь нет заданной «правильной» пропорции сфер.',
            style: TextStyle(fontSize: 12, height: 1.5, color: p.secondary),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Отменено: ${s.cancelled} · без отметки: ${s.total - s.done}\nБудущие дни исключены. Отметка не фиксирует фактическое время занятия.',
          style: TextStyle(fontSize: 11, height: 1.5, color: p.secondary),
        ),
      ],
    );
  }

  Map<String, List<RoutineOccurrence>> _itemGroups(RoutineStats stats) {
    final map = <String, List<RoutineOccurrence>>{};
    for (final o in stats.planned) {
      (map[o.item.id] ??= []).add(o);
    }
    return map;
  }

  Widget _bar(
    BuildContext context,
    String title,
    String detail,
    double rate,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: TextStyle(fontSize: 11, color: paletteOf(context).secondary),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: rate.clamp(0, 1),
            color: color,
            backgroundColor: paletteOf(context).inset,
            minHeight: 7,
          ),
        ),
      ],
    ),
  );
  Widget _dailyBars(BuildContext context, RoutineStats stats) {
    final days = stats.days.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return SizedBox(
      height: 150,
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days
                .map(
                  (d) => SizedBox(
                    width: math.max(26, c.maxWidth / math.max(1, days.length)),
                    child: Tooltip(
                      message: '${d.key}: ${d.value.done}/${d.value.total}',
                      child: InkWell(
                        onTap: () => onDay(DateTime.parse(d.key)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                d.value.rate == null
                                    ? '—'
                                    : '${(d.value.rate! * 100).round()}',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: paletteOf(context).secondary,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Container(
                                height: math.max(3, (d.value.rate ?? 0) * 102),
                                decoration: BoxDecoration(
                                  color: routineAccent.withValues(alpha: .8),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${DateTime.parse(d.key).day}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}
