import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'timeline.dart';

/// Connects the existing timeline to a screen-owned tasks model.
class TaskCalendar extends StatefulWidget {
  const TaskCalendar({
    super.key,
    required this.viewModel,
    required this.isWeek,
    required this.topPadding,
    this.isOverUnscheduled,
    this.onEventToUnscheduled,
    this.onHoverUnscheduled,
    this.onOpenTask,
  });
  final TasksViewModel viewModel;
  final bool isWeek;
  final double topPadding;
  final bool Function(Offset)? isOverUnscheduled;
  final ValueChanged<Task>? onEventToUnscheduled;
  final ValueChanged<bool>? onHoverUnscheduled;
  final ValueChanged<Task>? onOpenTask;

  @override
  State<TaskCalendar> createState() => _TaskCalendarState();
}

class _TaskCalendarState extends State<TaskCalendar> {
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
  }

  void _selectDay(DateTime date) {
    setState(() => _selectedDate = date);
    _changeWeek(date);
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
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
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<TaskWithProject>>(
    stream: widget.viewModel.watchCalendarTasks(
      bufferDays: widget.isWeek ? TimelineBody.weekBufferDays : 0,
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
      return TimelineBody(
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
                accentColor: item.project == null
                    ? AppColors.onSurface
                    : parseHexColor(item.project!.color),
              ),
        ],
        weekStart: widget.isWeek ? getWeekStart(date) : null,
        anchorDate: widget.isWeek ? _selectedDate : date,
        onWeekChange: widget.isWeek ? _changeWeek : null,
        onDaySelected: widget.isWeek ? _selectDay : null,
        topPadding: widget.topPadding,
        onEventChanged: (task, {startMinutes, durationMinutes, newDate}) =>
            _run(
              context,
              () => widget.viewModel.rescheduleTask(
                task.id,
                startMinutes: startMinutes,
                durationMinutes: durationMinutes,
                newDate: newDate,
              ),
            ),
        onExternalDrop: (task, startsAt, endsAt) => _run(
          context,
          () => widget.viewModel.scheduleTask(task.id, startsAt, endsAt),
        ),
        onToggleTask: (task) =>
            _run(context, () => widget.viewModel.toggleTask(task)),
        taskFormProjects: widget.viewModel.watchProjects(),
        onSubmitNewTask: widget.viewModel.addTask,
        isOverUnscheduled: widget.isOverUnscheduled,
        onEventToUnscheduled: widget.onEventToUnscheduled,
        onHoverUnscheduled: widget.onHoverUnscheduled,
      );
    },
  );
}
