import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'timeline.dart';

/// Connects the existing timeline to a screen-owned tasks model.
class TaskCalendar extends StatelessWidget {
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
    stream: viewModel.watchCalendarTasks(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Не удалось загрузить календарь'));
      }
      final items = snapshot.data ?? <TaskWithProject>[];
      final date = viewModel.currentFilterValue.anchorDate;
      return TimelineBody(
        dateOnlyTasks: [
          for (final item in items)
            if ((item.task.startsAt?.isDateOnly ?? false) ||
                isCalendarRange(item.task))
              item.task,
        ],
        onOpenTask: onOpenTask ?? viewModel.openTaskInEditor,
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
        weekStart: isWeek ? getWeekStart(date) : null,
        anchorDate: date,
        onWeekChange: isWeek
            ? (date) => viewModel.updateFilter(
                (old) => old.copyWith(anchorDate: date),
              )
            : null,
        topPadding: topPadding,
        onEventChanged: (task, {startMinutes, durationMinutes, newDate}) =>
            _run(
              context,
              () => viewModel.rescheduleTask(
                task.id,
                startMinutes: startMinutes,
                durationMinutes: durationMinutes,
                newDate: newDate,
              ),
            ),
        onExternalDrop: (task, startsAt, endsAt) => _run(
          context,
          () => viewModel.scheduleTask(task.id, startsAt, endsAt),
        ),
        onToggleTask: (task) => _run(context, () => viewModel.toggleTask(task)),
        taskFormProjects: viewModel.watchProjects(),
        onSubmitNewTask: viewModel.addTask,
        isOverUnscheduled: isOverUnscheduled,
        onEventToUnscheduled: onEventToUnscheduled,
        onHoverUnscheduled: onHoverUnscheduled,
      );
    },
  );
}
