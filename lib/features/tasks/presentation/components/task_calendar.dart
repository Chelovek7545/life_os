import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/fixed_fade_mask.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'date_header.dart';
import 'timeline.dart';

/// Connects the existing timeline to a screen-owned tasks model.
class TaskCalendar extends StatefulWidget {
  const TaskCalendar({
    super.key,
    required this.viewModel,
    required this.isWeek,
    required this.topPadding,
    this.onOpenTask,
    this.showDayHeader = false,
    this.showUnscheduledToggle = false,
    this.showDateOnlyPanel,
    this.onToggleDateOnlyPanel,
  });
  final TasksViewModel viewModel;
  final bool isWeek;
  final double topPadding;
  final ValueChanged<Task>? onOpenTask;
  final bool showDayHeader;
  final bool showUnscheduledToggle;
  final bool? showDateOnlyPanel;
  final VoidCallback? onToggleDateOnlyPanel;

  @override
  State<TaskCalendar> createState() => _TaskCalendarState();
}

class _TaskCalendarState extends State<TaskCalendar> {
  static const _dayHeaderSpace = 80.0;

  Stream<List<Task>> _watchUnscheduled() => widget.viewModel.state.map(
    (state) => state is TasksLoaded
        ? [for (final item in state.unscheduledTasks) item.task]
        : const <Task>[],
  );

  // Browsing weeks changes the query period, but keeps the chosen day intact.
  late DateTime _lastAnchorDate =
      widget.viewModel.currentFilterValue.anchorDate;
  late DateTime _selectedDate = _lastAnchorDate;

  @override
  void didUpdateWidget(covariant TaskCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _lastAnchorDate = widget.viewModel.currentFilterValue.anchorDate;
      _selectedDate = _lastAnchorDate;
    }
  }

  void _changeWeek(DateTime date) {
    _lastAnchorDate = date;
    widget.viewModel.updateFilter((old) => old.copyWith(anchorDate: date));
    widget.viewModel.selectCalendarCreationDate(_selectedDate);
  }

  void _selectDay(DateTime date) {
    setState(() => _selectedDate = date);
    _changeWeek(date);
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action, {
    bool propagateError = false,
  }) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить изменения задачи'),
          ),
        );
      }
      if (propagateError) rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TaskWithProject>>(
    stream: widget.viewModel.watchCalendarTasks(
      bufferDays: widget.isWeek ? TimelineBody.weekBufferDays : 0,
      period: widget.isWeek ? DatePeriod.week : DatePeriod.day,
    ),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Не удалось загрузить календарь'));
      }
      final items = snapshot.data ?? <TaskWithProject>[];
      final date = widget.viewModel.currentFilterValue.anchorDate;
      if (date != _lastAnchorDate) {
        // Date controls outside the calendar still explicitly select a day.
        _lastAnchorDate = date;
        _selectedDate = date;
      }
      final hasDayHeader = !widget.isWeek && widget.showDayHeader;
      final dayHeaderSpace = hasDayHeader
          ? MediaQuery.textScalerOf(
              context,
            ).clamp(minScaleFactor: 1).scale(_dayHeaderSpace)
          : 0.0;
      final timeline = TimelineBody(
        key: ObjectKey(widget.viewModel),
        showDateOnlyPanel: widget.showDateOnlyPanel,
        onToggleDateOnlyPanel: widget.onToggleDateOnlyPanel,
        watchUnscheduled: widget.isWeek && widget.showUnscheduledToggle
            ? _watchUnscheduled
            : null,
        dateOnlyTasks: [
          for (final item in items)
            if ((item.task.startsAt?.isDateOnly ?? false) ||
                isCalendarRange(item.task))
              item.task,
        ],
        onOpenTask: widget.onOpenTask ?? widget.viewModel.openTaskInEditor,
        onDayTaskMoved: (task, source, target) => _run(
          context,
          () => widget.viewModel.moveTaskToDay(task.id, source, target),
        ),
        onEventToDay: (task, day) => _run(
          context,
          () => widget.viewModel.makeTaskDateOnly(task.id, day),
        ),
        events: [
          for (final item in items)
            if (item.task.startsAt != null && !item.task.startsAt!.isDateOnly)
              TaskEvent(
                task: item.task,
                title: item.task.title,
                date: item.task.startsAt,
                startMinutes: item.task.startsAt!.durationInMinutes,
                durationMinutes: item.task.duration.inMinutes,
                isCompleted: item.task.isCompleted,
                accentColor: item.project != null
                    ? parseHexColor(item.project!.color)
                    : widget.isWeek
                    ? AppColors.primaryContainer
                    : AppColors.onSurface,
              ),
        ],
        weekStart: widget.isWeek ? getWeekStart(date) : null,
        anchorDate: widget.isWeek ? _selectedDate : date,
        onWeekChange: widget.isWeek ? _changeWeek : null,
        onDaySelected: widget.isWeek ? _selectDay : null,
        topPadding: widget.topPadding + dayHeaderSpace,
        onEventChanged: (task, {startMinutes, durationMinutes, newDate}) =>
            _run(
              context,
              () => widget.viewModel.rescheduleTask(
                task.id,
                startMinutes: startMinutes,
                durationMinutes: durationMinutes,
                newDate: newDate,
              ),
              propagateError: true,
            ),
        onExternalDrop: (task, startsAt, endsAt) => _run(
          context,
          () => widget.viewModel.scheduleTask(task.id, startsAt, endsAt),
        ),
        onToggleTask: (task) =>
            _run(context, () => widget.viewModel.toggleTask(task)),
        taskFormProjects: widget.viewModel.watchProjects(),
        onSubmitNewTask: widget.viewModel.addTask,
      );
      if (!hasDayHeader) return timeline;
      return Stack(
        fit: StackFit.expand,
        children: [
          FixedVerticalFadeMask(
            topFade: dayHeaderSpace + 20,
            bottomFade: 10,
            child: timeline,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: DateHeader(anchorDate: date, onDateChange: _selectDay),
          ),
        ],
      );
    },
  );
}
