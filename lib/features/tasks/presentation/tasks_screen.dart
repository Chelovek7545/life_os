import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/empty_placeholder.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';
import 'package:life_os/features/tasks/presentation/components/timeline.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

const double _kFormExpandedHeight = 1000.0;
const double _kHeaderHeight = 40.0;
const double _kPeriodTabsHeight = 45.0;
const double _kCalendarHeight = 86.0;
const double _kTimelineTopPadding = 60.0;

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.viewModel,
    this.onFormVisibilityChanged,
  });

  final TasksViewModel viewModel;
  final ValueChanged<bool>? onFormVisibilityChanged;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  bool _isEventMode = false;
  bool _showCalendar = true;
  bool _lastFormVisible = false;

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  Widget _buildTaskBody(double overlayHeight, DateTime today) {
    return StreamBuilder<TaskScreenState>(
      stream: widget.viewModel.state,
      initialData: const TasksLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const TasksLoading();

        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          empty: (_, _) => const EmptyPlaceholder(),
          error: (message) => Center(child: Text(message)),
          loaded: (items, selectedTasks, _, _) {
            if (items.isEmpty) {
              return const EmptyPlaceholder();
            }

            final selectedIds = selectedTasks.map((task) => task.id).toSet();
            final period = widget.viewModel.currentFilterValue.period;

            return switch (period) {
              DatePeriod.week => _WeekTasksList(
                items: items,
                selectedIds: selectedIds,
                overlayHeight: overlayHeight,
                anchorDate: widget.viewModel.currentFilterValue.anchorDate,
                onToggleTask: widget.viewModel.toggleTask,
                onEditTask: _openTaskEditor,
                onToggleSelection: widget.viewModel.toggleTaskSelection,
                onDeleteTask: widget.viewModel.deleteTask,
              ),
              _ => _TaskList(
                items: items,
                selectedIds: selectedIds,
                overlayHeight: overlayHeight,
                today: today,
                onToggleTask: widget.viewModel.toggleTask,
                onEditTask: _openTaskEditor,
                onToggleSelection: widget.viewModel.toggleTaskSelection,
                onDeleteTask: widget.viewModel.deleteTask,
              ),
            };
          },
        );
      },
    );
  }

  Widget _buildEventBody() {
    return StreamBuilder<TaskScreenState>(
      stream: widget.viewModel.state,
      initialData: const TasksLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const TasksLoading();

        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          empty: (_, _) => const EmptyPlaceholder(),
          error: (message) => Center(child: Text(message)),
          loaded: (items, _, _, _) {
            final events = items
                .where((item) {
                  final startsAt = item.task.startsAt;
                  return startsAt != null && !startsAt.isDateOnly;
                })
                .map(
                  (item) => TaskEvent(
                    task: item.task,
                    title: item.task.title,
                    startMinutes: item.task.startsAt!.durationInMinutes,
                    durationMinutes: item.task.duration.inMinutes,
                  ),
                )
                .toList(growable: false);

            if (events.isEmpty) {
              return const EmptyPlaceholder();
            }

            return TimelineBody(
              events: events,
              topPadding: _kTimelineTopPadding,
              onEventChanged: _updateEvent,
            );
          },
        );
      },
    );
  }

  Widget _buildHeaderPanel(bool isFormVisible) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          _TasksHeader(
            vm: widget.viewModel,
            onAddPressed: isFormVisible
                ? widget.viewModel.hideForm
                : widget.viewModel.showForm,
            onModeChanged: _onModeChanged,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!_isEventMode)
            StreamBuilder<TaskFilterConfig>(
              stream: widget.viewModel.currentFilter,
              initialData: widget.viewModel.currentFilterValue,
              builder: (context, snapshot) {
                final currentFilter =
                    snapshot.data ?? widget.viewModel.currentFilterValue;

                return Column(
                  children: [
                    SegmentedPillControl(
                      tabs: const ['Day', 'Week', 'Month'],
                      currentIdx: currentFilter.period.index,
                      onTabChanged: _onPeriodChanged,
                    ),
                    if (currentFilter.period == DatePeriod.day) ...[
                      const SizedBox(height: AppSpacing.sm),
                      CalendarRow(
                        selectedDate: currentFilter.anchorDate,
                        onDaySelected: (date) {
                          widget.viewModel.updateFilter(
                            (old) => old.copyWith(anchorDate: date),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTaskForm(BuildContext context, bool isFormVisible) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      left: 0,
      right: 0,
      bottom: isFormVisible ? 0 : -_kFormExpandedHeight,
      height: _kFormExpandedHeight,
      onEnd: () {
        if (!isFormVisible && mounted) {
          setState(widget.viewModel.disableForm);
        }
      },
      child: widget.viewModel.shouldRenderForm
          ? CollapsibleTaskForm(
              onFormVisibilityChanged: (value) =>
                  widget.onFormVisibilityChanged?.call(value),
              onCancel: widget.viewModel.hideForm,
              height: MediaQuery.sizeOf(context).height * 0.8,
              task:
                  widget.viewModel.activeTaskWithProject?.task ??
                  widget.viewModel.draftTask,
              projects: widget.viewModel.watchProjects(),
              isEditMode: widget.viewModel.activeTaskWithProject != null,
              onDelete: (taskId) {
                widget.viewModel.deleteTask(taskId);
                widget.viewModel.hideForm();
              },
              onSubmit: _submitTask,
            )
          : const SizedBox.shrink(),
    );
  }

  static const Gradient maskingFadeGradient = LinearGradient(
    colors: [
      Colors.transparent,
      Colors.black,
      Colors.black,
      Colors.transparent,
    ],
    stops: [0.0, 0.15, 0.96, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  void _openTaskEditor(TaskWithProject item) {
    widget.viewModel.startEditingTask(item);
    widget.viewModel.showForm();
  }

  void _onModeChanged(int index) {
    _onPeriodChanged(0);
    setState(() => _isEventMode = index == 1);
  }

  void _onPeriodChanged(int index) {
    if (index < 0 || index >= DatePeriod.values.length) {
      return;
    }

    final period = DatePeriod.values[index];
    setState(() => _showCalendar = period == DatePeriod.day);
    widget.viewModel.updateFilter((old) => old.copyWith(period: period));
  }

  Future<void> _updateEvent(
    Task task, {
    int? startMinutes,
    int? durationMinutes,
  }) async {
    final currentStart = task.startsAt;
    if (currentStart == null) {
      return;
    }

    final startsAt = startMinutes == null
        ? currentStart
        : DateTime(
            currentStart.year,
            currentStart.month,
            currentStart.day,
            startMinutes ~/ 60,
            startMinutes % 60,
          );
    final duration = Duration(
      minutes: durationMinutes ?? task.duration.inMinutes,
    );

    await widget.viewModel.updateTask(
      task.copyWith(
        startsAt: Wrapped(startsAt),
        endsAt: Wrapped(startsAt.add(duration)),
      ),
    );
  }

  Future<void> _submitTask(Task task) async {
    if (widget.viewModel.activeTaskWithProject != null) {
      await widget.viewModel.updateTask(task);
    } else {
      await widget.viewModel.addTask(task);
    }
    widget.viewModel.hideForm();
  }

  @override
  Widget build(BuildContext context) {
    final overlayHeight =
        _kHeaderHeight +
        _kPeriodTabsHeight +
        AppSpacing.sm * 2 +
        (_showCalendar ? _kCalendarHeight + AppSpacing.sm + AppSpacing.md : 0);

    return StreamBuilder<bool>(
      stream: widget.viewModel.isFormVisible,
      initialData: false,
      builder: (context, snapshot) {
        final isFormVisible = snapshot.data ?? false;
        // if (isFormVisible != _lastFormVisible) {
        //   _lastFormVisible = isFormVisible;
        //   widget.onFormVisibilityChanged?.call(isFormVisible);
        // }
        final today = DateTime.now().startOfDay;

        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ShaderMask(
                shaderCallback: maskingFadeGradient.createShader,
                blendMode: BlendMode.dstIn,
                child: IndexedStack(
                  index: _isEventMode ? 1 : 0,
                  children: [
                    _buildTaskBody(overlayHeight, today),
                    _buildEventBody(),
                  ],
                ),
              ),
            ),
            _buildHeaderPanel(isFormVisible),
            _buildTaskForm(context, isFormVisible),
          ],
        );
      },
    );
  }
}

//TaskList
class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.items,
    required this.selectedIds,
    required this.overlayHeight,
    required this.today,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onToggleSelection,
    required this.onDeleteTask,
  });

  final List<TaskWithProject> items;
  final Set<String> selectedIds;
  final double overlayHeight;
  final DateTime today;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<TaskWithProject> onEditTask;
  final ValueChanged<Task> onToggleSelection;
  final ValueChanged<String> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.symmetric(vertical: overlayHeight + AppSpacing.sm),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return TaskCard(
          key: ValueKey(item.task.id),
          task: item.task,
          isOverdue: item.task.dueDate?.isBefore(today) ?? false,
          onCheckChanged: () => onToggleTask(item.task),
          onLongPress: () => onEditTask(item),
          onDelete: () => onDeleteTask(item.task.id),
          projectTitle: item.project?.name,
          isSelected: selectedIds.contains(item.task.id),
          onSelected: () => onToggleSelection(item.task),
          onTap: () {},
        );
      },
    );
  }
}

//Week view
class _WeekTasksList extends StatelessWidget {
  const _WeekTasksList({
    required this.items,
    required this.selectedIds,
    required this.overlayHeight,
    required this.anchorDate,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onToggleSelection,
    required this.onDeleteTask,
  });

  final List<TaskWithProject> items;
  final Set<String> selectedIds;
  final double overlayHeight;
  final DateTime anchorDate;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<TaskWithProject> onEditTask;
  final ValueChanged<Task> onToggleSelection;
  final ValueChanged<String> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    final groupedItems = <DateTime, List<TaskWithProject>>{};
    for (final item in items) {
      final startsAt = item.task.startsAt;
      if (startsAt == null) {
        continue;
      }
      groupedItems.putIfAbsent(startsAt.startOfDay, () => []).add(item);
    }

    final weekDates = getDatesForWeek(anchorDate);
    final today = DateTime.now().startOfDay;

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: overlayHeight),
      itemCount: weekDates.length,
      itemBuilder: (context, index) {
        final date = weekDates[index];
        final dayItems = groupedItems[date.startOfDay] ?? const [];

        return _WeekDaySection(
          date: date,
          isToday: date.startOfDay.isAtSameMomentAs(today),
          items: dayItems,
          selectedIds: selectedIds,
          onToggleTask: onToggleTask,
          onEditTask: onEditTask,
          onToggleSelection: onToggleSelection,
          onDeleteTask: onDeleteTask,
        );
      },
    );
  }
}

class _WeekDaySection extends StatelessWidget {
  const _WeekDaySection({
    required this.date,
    required this.isToday,
    required this.items,
    required this.selectedIds,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onToggleSelection,
    required this.onDeleteTask,
  });

  final DateTime date;
  final bool isToday;
  final List<TaskWithProject> items;
  final Set<String> selectedIds;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<TaskWithProject> onEditTask;
  final ValueChanged<Task> onToggleSelection;
  final ValueChanged<String> onDeleteTask;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.xl,
              bottom: AppSpacing.xs,
            ),
            child: Row(
              children: [
                if (isToday) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryContainer.withValues(
                            alpha: 0.8,
                          ),
                          blurRadius: 10,
                        ),
                      ],
                      color: AppColors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(width: 8, height: 8),
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  '${getWeekDayName(date.weekday)} ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
                  style: AppTypography.headlineLgMobile.copyWith(
                    shadows: [
                      if (isToday)
                        Shadow(
                          color: AppColors.overdueGlow.withValues(alpha: 0.7),
                          blurRadius: 21,
                        ),
                    ],
                    color: isToday
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10, left: 8),
              child: Text(
                'No tasks',
                style: AppTypography.bodySm.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
            )
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: TaskCard(
                  key: ValueKey(item.task.id),
                  task: item.task,
                  onCheckChanged: () => onToggleTask(item.task),
                  onLongPress: () => onEditTask(item),
                  onDelete: () => onDeleteTask(item.task.id),
                  projectTitle: item.project?.name,
                  isSelected: selectedIds.contains(item.task.id),
                  onSelected: () => onToggleSelection(item.task),
                  onTap: () {},
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Header elements
class _TasksHeader extends StatefulWidget {
  const _TasksHeader({
    required this.onAddPressed,
    required this.onModeChanged,
    required this.vm,
  });
  final TasksViewModel vm;
  final VoidCallback onAddPressed;
  final ValueChanged<int> onModeChanged;

  @override
  State<_TasksHeader> createState() => _TasksHeaderState();
}

class _TasksHeaderState extends State<_TasksHeader>
    with SingleTickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Row(
      //mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.settings_outlined, color: Colors.white),
        ),
        Spacer(),
        SizedBox(
          width: 150,
          child: PillSwitcher(
            outerPadding: 1,
            paddingBetweenOptions: 1,
            innerPadding: 1,
            options: const [Icon(Icons.check_box), Icon(Icons.event)],
            onSelectionChanged: widget.onModeChanged,
          ),
        ),
        Spacer(),

        Container(
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),

            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          child: Row(
            children: [
              StreamBuilder(
                stream: widget.vm.state,
                builder: (_, snap) {
                  Widget? ico;
                  if (snap.hasData) {
                    snap.data!.when(
                      loading: () {},
                      empty: (_, _) {},
                      loaded: (_, selected, _, _) {
                        if (selected.isNotEmpty) {
                          ico = Row(
                            children: [
                              IconButton(
                                style: IconButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => widget.vm.clearTaskSelection(),
                                icon: const Icon(Icons.clear),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  selected.length.toString(),
                                  style: AppTypography.bodyMd,
                                ),
                              ),
                            ],
                          );
                        }
                      },
                      error: (_) {},
                    );
                  }

                  return AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: ico ?? const SizedBox.shrink(),
                  );
                },
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: widget.onAddPressed,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CalendarRow extends StatelessWidget {
  const CalendarRow({
    super.key,
    required this.selectedDate,
    required this.onDaySelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final weekDates = getDatesForWeek(selectedDate);

    return SizedBox(
      height: 90,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: weekDates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final date = weekDates[index];
          final isSelected = date.startOfDay.isAtSameMomentAs(
            selectedDate.startOfDay,
          );

          return DateTimelineCard(
            weekday: getWeekDayName(date.weekday),
            day: '${date.day}',
            isSelected: isSelected,
            onTap: () => onDaySelected(date),
          );
        },
      ),
    );
  }
}
