import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:tasks_api/tasks_api.dart';
import '../theme/app_colors.dart';

/// Keeps data and expansion shared by a card and its drag feedback.
class TaskWorkLogsBuilder extends StatefulWidget {
  const TaskWorkLogsBuilder({
    super.key,
    required this.taskId,
    required this.repository,
    required this.builder,
  });
  final String taskId;
  final WorkLogsApi? repository;
  final Widget Function(Widget? footer) builder;
  @override
  State<TaskWorkLogsBuilder> createState() => _TaskWorkLogsBuilderState();
}

class _TaskWorkLogsBuilderState extends State<TaskWorkLogsBuilder> {
  late Stream<List<WorkLog>>? _logs = widget.repository?.watchWorkLogsForTask(
    widget.taskId,
  );
  bool _expanded = false;
  int _shown = 5;
  @override
  void didUpdateWidget(TaskWorkLogsBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId ||
        oldWidget.repository != widget.repository) {
      _logs = widget.repository?.watchWorkLogsForTask(widget.taskId);
      _expanded = false;
      _shown = 5;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_logs == null) return widget.builder(null);
    return StreamBuilder<List<WorkLog>>(
      key: ValueKey((widget.repository, widget.taskId)),
      stream: _logs,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return widget.builder(
            const Text(
              'Не удалось загрузить ворклоги',
              style: TextStyle(fontSize: 11),
            ),
          );
        }
        final logs = [...?snapshot.data]
          ..sort(
            (a, b) => (b.startedAt ?? b.date).compareTo(a.startedAt ?? a.date),
          );
        return widget.builder(
          logs.isEmpty
              ? null
              : _WorkLogPanel(
                  logs: logs,
                  expanded: _expanded,
                  shown: _shown,
                  onToggle: () => setState(() => _expanded = !_expanded),
                  onMore: () => setState(() => _shown += 5),
                ),
        );
      },
    );
  }
}

String workLogDurationLabel(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 1) return '< 1 мин';
  return minutes < 60
      ? '$minutes мин'
      : '${minutes ~/ 60} ч${minutes % 60 == 0 ? '' : ' ${minutes % 60} мин'}';
}

Duration workLogTimeOnDay(WorkLog log, DateTime day) {
  if (log.duration == null) return Duration.zero;
  final from = DateTime(day.year, day.month, day.day);
  final until = DateTime(day.year, day.month, day.day + 1);
  final start = log.startedAt!.isAfter(from) ? log.startedAt! : from;
  final end = log.endedAt!.isBefore(until) ? log.endedAt! : until;
  return end.isAfter(start) ? end.difference(start) : Duration.zero;
}

class _WorkLogPanel extends StatelessWidget {
  const _WorkLogPanel({
    required this.logs,
    required this.expanded,
    required this.shown,
    required this.onToggle,
    required this.onMore,
  });
  final List<WorkLog> logs;
  final bool expanded;
  final int shown;
  final VoidCallback onToggle;
  final VoidCallback onMore;

  String _clock(DateTime date) =>
      '${date.toLocal().hour.toString().padLeft(2, '0')}:${date.toLocal().minute.toString().padLeft(2, '0')}';
  String _day(DateTime value, DateTime now) {
    final day = DateUtils.dateOnly(value.toLocal());
    if (day == DateUtils.dateOnly(now)) return 'Сегодня';
    if (day == DateTime(now.year, now.month, now.day - 1)) return 'Вчера';
    return '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}.${day.year}';
  }

  Widget _entry(WorkLog log, DateTime now, bool wide, bool compact) {
    final today = _day(log.startedAt ?? log.date, now) == 'Сегодня';
    final interval = log.startedAt != null && log.endedAt != null
        ? '${_clock(log.startedAt!)} – ${_clock(log.endedAt!)}'
        : null;
    final date = Text(
      _day(log.startedAt ?? log.date, now),
      style: const TextStyle(fontSize: 12),
      maxLines: 1,
    );
    final time = interval == null
        ? const SizedBox.shrink()
        : Text(
            interval,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
            ),
            maxLines: 1,
          );
    final title = Container(
      key: ValueKey(('worklog.title', log.id)),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGlass),
      ),
      child: Text(
        log.description.isEmpty ? 'Без описания' : log.description,
        style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
    final duration = Text(
      log.duration == null ? '—' : workLogDurationLabel(log.duration!),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      maxLines: 1,
    );
    return SizedBox(
      key: ValueKey(('worklog.row', log.id)),
      height: wide
          ? 56
          : compact
          ? 66
          : 56,
      child: Row(
        children: [
          SizedBox(
            width: 12,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Container(width: 1, color: AppColors.borderGlass),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: today
                        ? AppColors.primary
                        : AppColors.onSurfaceVariant.withValues(alpha: .4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            key: ValueKey(('worklog.date', log.id)),
            width: wide ? 84 : 72,
            child: wide
                ? date
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      date,
                      if (interval != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: FittedBox(fit: BoxFit.scaleDown, child: time),
                        ),
                      if (compact && log.duration != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: duration,
                          ),
                        ),
                    ],
                  ),
          ),
          if (wide && log.duration != null) ...[
            const SizedBox(width: 10),
            SizedBox(width: 76, child: duration),
          ],
          if (wide && interval != null) ...[
            const SizedBox(width: 10),
            SizedBox(width: 100, child: time),
          ],
          const SizedBox(width: 8),
          Expanded(child: title),
          if (!wide && !compact && log.duration != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 65,
              child: FittedBox(fit: BoxFit.scaleDown, child: duration),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final total = logs.fold(
      Duration.zero,
      (sum, log) => sum + (log.duration ?? Duration.zero),
    );
    final today = logs.fold(
      Duration.zero,
      (sum, log) => sum + workLogTimeOnDay(log, now),
    );
    final timed = logs.any((log) => log.duration != null);
    final activity = [
      for (var i = 6; i >= 0; i--)
        logs
            .fold(
              Duration.zero,
              (sum, log) =>
                  sum +
                  workLogTimeOnDay(
                    log,
                    DateTime(now.year, now.month, now.day - i),
                  ),
            )
            .inSeconds,
    ];
    final maxSeconds = math.max(1, activity.reduce(math.max));
    Widget bars() => SizedBox(
      height: 23,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final seconds in activity)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Container(
                width: 5,
                height: 4 + 19 * seconds / maxSeconds,
                decoration: BoxDecoration(
                  color: seconds > 0
                      ? AppColors.primaryContainer
                      : AppColors.onSurfaceVariant.withValues(alpha: .2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
    Widget badge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.primary.withValues(alpha: .17)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time, color: AppColors.primary, size: 17),
          SizedBox(width: 6),
          Text('Ворклоги', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
    Widget totalLabel() => Text(
      timed ? workLogDurationLabel(total) : 'Время не указано',
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );
    Widget todayLabel() => Text(
      'Сегодня: ${today == Duration.zero ? '0 мин' : workLogDurationLabel(today)}',
      style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
    );
    return Container(
      key: const ValueKey('task.worklogs'),
      margin: const EdgeInsets.fromLTRB(40, 8, 4, 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 460;
          final tight = constraints.maxWidth < 260;
          final compact = constraints.maxWidth < 360;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: const ValueKey('task.worklogs.toggle'),
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: onToggle,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    color: Colors.white.withValues(alpha: .05),
                    border: Border.all(color: AppColors.borderGlass),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (tight)
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: badge(),
                              ),
                            )
                          else
                            badge(),
                          if (!tight) ...[
                            const SizedBox(width: 12),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: totalLabel(),
                              ),
                            ),
                          ],
                          if (wide && timed) ...[
                            const SizedBox(width: 12),
                            bars(),
                            const SizedBox(width: 16),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: todayLabel(),
                              ),
                            ),
                          ],
                          Icon(
                            expanded ? Icons.expand_less : Icons.expand_more,
                            size: 21,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                      if (tight)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: totalLabel(),
                            ),
                          ),
                        ),
                      if (!wide && timed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              bars(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: todayLabel(),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (expanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final log in logs.take(shown))
                        _entry(log, now, wide, compact),
                      if (logs.length > shown)
                        TextButton(
                          onPressed: onMore,
                          child: Text('Показать ещё (${logs.length - shown})'),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
