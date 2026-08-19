import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/empty_placeholder.dart';
import 'package:life_os/core/ui/fixed_fade_mask.dart';
import 'package:life_os/core/ui/glassPopUpMenuButton.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:life_os/core/ui/resizable_panel.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/settings/settings_screen.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/date_header.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';
import 'package:life_os/features/tasks/presentation/components/timeline.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

const double _kHeaderHeight = 42.0;
const double _kPeriodTabsHeight = 45.0;
const double _kCalendarHeight = 90.0;
const double _kDateHeaderHeight = 60.0;
const double _kTimelineTopPadding = 60.0 + _kDateHeaderHeight;
const double _kWeekTimelineTopPadding =
    _kTimelineTopPadding - _kDateHeaderHeight;
const double _kWideBreakpoint = 760.0;

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.viewModel,
    this.onFormVisibilityChanged,
  });

  final TasksViewModel viewModel;
  final ValueChanged<bool>? onFormVisibilityChanged;

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  bool _showCalendar = true;
  bool _showUnscheduledOverlay = false;

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleUnscheduledOverlay() {
    setState(() => _showUnscheduledOverlay = !_showUnscheduledOverlay);
  }

  Widget _buildUnscheduledOverlay(
    double overlayHeight,
    DateTime today,
    double overlayWidth,
  ) {
    if (!_showUnscheduledOverlay) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<TaskScreenState>(
      stream: widget.viewModel.state,
      initialData: const TasksLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const TasksLoading();
        final unscheduledTasks =
            state.maybeWhen(
              loaded: (_, _, _, _, unscheduled) => unscheduled,
              orElse: () => const <TaskWithProject>[],
            ) ??
            const <TaskWithProject>[];
        if (unscheduledTasks.isEmpty) {
          return const SizedBox.shrink();
        }
        return Positioned(
          top: AppSpacing.sm + _kHeaderHeight + AppSpacing.sm,
          left: 8,
          width: overlayWidth,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            color: Colors.transparent,
            child: GlassPanel(
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Unscheduled',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _showUnscheduledOverlay = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        children: unscheduledTasks
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: TaskCard(
                                  task: item.task,
                                  projectTitle: item.project?.name,
                                  leftBorderColor: item.project != null
                                      ? parseHexColor(item.project!.color)
                                      : null,
                                  isOverdue:
                                      item.task.dueDate?.isBefore(today) ??
                                      false,
                                  onCheckChanged: () {
                                    widget.viewModel.toggleTask(item.task);
                                  },
                                  onLongPress: () => _openTaskEditor(item),
                                  onDelete: () =>
                                      widget.viewModel.deleteTask(item.task.id),
                                  isSelected: false,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
          loaded: (items, selectedTasks, _, _, _) {
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
              DatePeriod.day => _TaskList(
                key: ValueKey(widget.viewModel.currentFilterValue.anchorDate),
                items: items,
                selectedIds: selectedIds,
                overlayHeight: overlayHeight,
                today: today,
                onToggleTask: widget.viewModel.toggleTask,
                onEditTask: _openTaskEditor,
                onToggleSelection: widget.viewModel.toggleTaskSelection,
                onDeleteTask: widget.viewModel.deleteTask,
              ),
              _ => _TaskList(
                key: ValueKey(widget.viewModel.currentFilterValue.anchorDate),
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

  Widget _buildEventBody(bool isWide, DateTime anchorDate) {
    return StreamBuilder<TaskScreenState>(
      stream: widget.viewModel.state,
      initialData: const TasksLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const TasksLoading();
        final anchorDate = widget.viewModel.currentFilterValue.anchorDate;
        List<TaskEvent> events = [];
        state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          empty: (_, _) {
            events = [];
          },
          error: (message) => Center(child: Text(message)),
          loaded: (items, _, _, _, _) {
            events = items
                .where((item) {
                  final startsAt = item.task.startsAt;
                  return startsAt != null && !startsAt.isDateOnly;
                })
                .map(
                  (item) => TaskEvent(
                    accentColor: item.project != null
                        ? parseHexColor(item.project!.color)
                        : AppColors.onSurface,
                    task: item.task,
                    title: item.task.title,
                    date: item.task.startsAt,
                    startMinutes: item.task.startsAt!.durationInMinutes,
                    durationMinutes: item.task.duration.inMinutes,
                    isCompleted: item.task.isCompleted,
                  ),
                )
                .toList(growable: false);
          },
        );

        return TimelineBody(
          events: events,
          weekStart: isWide ? getWeekStart(anchorDate) : null,
          anchorDate: isWide ? anchorDate : null,
          onWeekChange: isWide
              ? (date) => widget.viewModel.updateFilter(
                  (old) => old.copyWith(anchorDate: date),
                )
              : null,
          topPadding: isWide ? _kWeekTimelineTopPadding : _kTimelineTopPadding,
          onEventChanged: _updateEvent,
          onToggleTask: widget.viewModel.toggleTask,
          taskFormProjects: widget.viewModel.watchProjects(),
          onSubmitNewTask: widget.viewModel.addTask,
        );
      },
    );
  }

  Widget _buildHeaderPanel(
    bool isFormVisible,
    bool isLandscape,
    bool _isEventMode,
    double tasksScreenWidth,
    bool isWide,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.sm),
        _TasksHeader(
          vm: widget.viewModel,
          tasksScreenWidth: tasksScreenWidth,
          onAddPressed: isFormVisible
              ? widget.viewModel.hideForm
              : widget.viewModel.showForm,
          onModeChanged: (index) => _onModeChanged(index, isWide),
          onToggleUnscheduled: _toggleUnscheduledOverlay,
        ),
        const SizedBox(height: AppSpacing.sm),

        StreamBuilder<TaskFilterConfig>(
          stream: widget.viewModel.currentFilter,
          initialData: widget.viewModel.currentFilterValue,
          builder: (context, snapshot) {
            final currentFilter =
                snapshot.data ?? widget.viewModel.currentFilterValue;

            return Column(
              children: [
                if (_isEventMode && !isWide)
                  DateHeader(
                    anchorDate: currentFilter.anchorDate,
                    onDateChange: (value) => widget.viewModel.updateFilter(
                      (old) => old.copyWith(anchorDate: value),
                    ),
                  ),

                if (!_isEventMode) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppMargins.sm,
                    ),

                    child: SegmentedPillControl(
                      tabs: const ['Day', 'Week', 'Month'],
                      currentIdx: currentFilter.period.index,
                      onTabChanged: _onPeriodChanged,
                    ),
                  ),
                  if (currentFilter.period == DatePeriod.day) ...[
                    const SizedBox(height: AppSpacing.sm),

                    SizedBox(
                      width: 550,
                      child: CalendarRow(
                        selectedDate: currentFilter.anchorDate,
                        onDaySelected: (date) {
                          widget.viewModel.updateFilter(
                            (old) => old.copyWith(anchorDate: date),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTaskForm(
    BuildContext context,
    bool isFormVisible,
    double width,
  ) {
    double _kFormExpandedHeight = MediaQuery.sizeOf(context).height * 0.8;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 600),
      right: 0,
      width: width,
      curve: Curves.easeInOut,
      bottom: isFormVisible ? 0 : -_kFormExpandedHeight,
      height: _kFormExpandedHeight,
      onEnd: () {
        if (!isFormVisible && mounted) {
          setState(widget.viewModel.disableForm);
        }
      },
      child: widget.viewModel.shouldRenderForm
          ? _buildForm()
          : const SizedBox.shrink(),
    );
  }

  void _openTaskEditor(TaskWithProject item) {
    widget.viewModel.startEditingTask(item);
    widget.viewModel.showForm();
  }

  void _onModeChanged(int index, bool isWide) {
    _onPeriodChanged(isWide ? DatePeriod.week.index : 0);
    widget.viewModel.toggleEventMode();
  }

  void _syncEventPeriod(bool isWide, bool isEventMode) {
    if (!isEventMode) return;
    final desired = isWide ? DatePeriod.week : DatePeriod.day;
    if (widget.viewModel.currentFilterValue.period == desired) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.viewModel.updateFilter((old) => old.copyWith(period: desired));
    });
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
    DateTime? newDate,
  }) async {
    final currentStart = task.startsAt;
    if (currentStart == null) {
      return;
    }

    final referenceDate = newDate ?? currentStart;
    final startsAt = startMinutes == null && newDate == null
        ? currentStart
        : DateTime(
            referenceDate.year,
            referenceDate.month,
            referenceDate.day,
            startMinutes == null ? currentStart.hour : startMinutes ~/ 60,
            startMinutes == null ? currentStart.minute : startMinutes % 60,
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

  static const Gradient maskingFadeGradient = LinearGradient(
    colors: [
      Colors.transparent,
      Colors.black,
      Colors.black,
      Colors.transparent,
    ],
    stops: [0.0, 0.20, 0.96, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final overlayHeight =
        _kHeaderHeight +
        _kPeriodTabsHeight +
        AppSpacing.sm * 2 +
        (_showCalendar ? _kCalendarHeight + AppSpacing.sm : 0);

    return StreamBuilder<TasksUiFlags>(
      stream: widget.viewModel.uiFlags,
      initialData: TasksUiFlags(),
      builder: (context, snapshot) {
        final uiFlags = snapshot.data ?? TasksUiFlags();
        final today = DateTime.now().startOfDay;

        if (isLandscape) {
          return _buildLandscapeLayout(
            overlayHeight,
            today,
            uiFlags.isFormVisible,
            uiFlags.isEventMode,
          );
        }
        return _buildPortraitLayout(
          overlayHeight,
          today,
          uiFlags.isFormVisible,
          uiFlags.isEventMode,
        );
      },
    );
  }

  Widget _buildPortraitLayout(
    double overlayHeight,
    DateTime today,
    bool isFormVisible,
    bool _isEventMode,
  ) {
    final isWide = false;
    _syncEventPeriod(isWide, _isEventMode);

    return Stack(
      alignment: AlignmentDirectional.topCenter,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 550),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FixedVerticalFadeMask(
              topFade: 100,
              child: _isEventMode
                  ? _buildEventBody(
                      isWide,
                      widget.viewModel.currentFilterValue.anchorDate,
                    )
                  : _buildTaskBody(overlayHeight, today),
            ),
          ),
        ),
        _buildHeaderPanel(
          isFormVisible,
          false,
          _isEventMode,
          MediaQuery.sizeOf(context).width,
          isWide,
        ),
        _buildUnscheduledOverlay(
          overlayHeight,
          today,
          MediaQuery.sizeOf(context).width > 400
              ? 400
              : MediaQuery.sizeOf(context).width,
        ),
        _buildTaskForm(
          context,
          isFormVisible,
          MediaQuery.sizeOf(context).width,
        ),
      ],
    );
  }

  double _panelWidth = 350;
  Widget _buildLandscapeLayout(
    double overlayHeight,
    DateTime today,
    bool isFormVisible,
    bool _isEventMode,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Ширина левой части = totalWidth - ширина панели (если видна)
        final leftWidth = isFormVisible
            ? totalWidth -
                  _panelWidth // _panelWidth храним в State
            : totalWidth;

        final isWide = _isEventMode && leftWidth >= _kWideBreakpoint;
        _syncEventPeriod(isWide, _isEventMode);

        //print(leftWidth);
        //print(totalWidth);
        //print(_panelWidth);
        return Row(
          children: [
            Expanded(
              child: Stack(
                alignment: AlignmentDirectional.topCenter,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isWide ? double.infinity : 550,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: _isEventMode && isWide
                          ? _buildEventBody(
                              isWide,
                              widget.viewModel.currentFilterValue.anchorDate,
                            )
                          : FixedVerticalFadeMask(
                              topFade: 100,
                              bottomFade: 10,
                              child: _isEventMode
                                  ? _buildEventBody(
                                      isWide,
                                      widget
                                          .viewModel
                                          .currentFilterValue
                                          .anchorDate,
                                    )
                                  : _buildTaskBody(overlayHeight, today),
                            ),
                    ),
                  ),
                  _buildHeaderPanel(
                    isFormVisible,
                    false,
                    _isEventMode,
                    leftWidth,
                    isWide,
                  ),
                  _buildUnscheduledOverlay(
                    overlayHeight,
                    today,
                    leftWidth > 400 ? 400 : leftWidth,
                  ),
                  if (isFormVisible && leftWidth <= 330)
                    _buildTaskForm(context, isFormVisible, 310),
                ],
              ),
            ),
            if (isFormVisible && leftWidth > 330)
              ResizablePanel(
                initialWidth: _panelWidth,
                minWidth: 310,
                maxWidth: 500,
                onWidthChanged: (w) => setState(() => _panelWidth = w),
                child: _buildForm(forceExpanded: true),
              ),
          ],
        );
      },
    );
  }

  Widget _buildForm({bool forceExpanded = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CollapsibleTaskForm(
          onChanged: (draft) {
            widget.viewModel.draftTask = draft;
          },
          forceExpanded: forceExpanded,
          onFormVisibilityChanged: (value) =>
              widget.onFormVisibilityChanged?.call(value),
          onCancel: widget.viewModel.hideForm,
          height: forceExpanded
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.8,
          task: widget.viewModel.draftTask,
          projects: widget.viewModel.watchProjects(),
          isEditMode: widget.viewModel.activeTaskWithProject != null,
          onDelete: (taskId) {
            widget.viewModel.deleteTask(taskId);
            widget.viewModel.hideForm();
          },
          onSubmit: _submitTask,
        );
      },
    );
  }
}

//TaskList
class _TaskList extends StatefulWidget {
  const _TaskList({
    super.key,
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
  State<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<_TaskList> {
  final _listKey = GlobalKey<AnimatedListState>();
  final _items = <TaskWithProject>[];

  @override
  void initState() {
    super.initState();
    _items.addAll(widget.items);
  }

  @override
  void didUpdateWidget(_TaskList oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldIds = oldWidget.items.map((e) => e.task.id).toSet();
    final newIds = widget.items.map((e) => e.task.id).toSet();

    for (int i = _items.length - 1; i >= 0; i--) {
      if (!newIds.contains(_items[i].task.id)) {
        final removed = _items.removeAt(i);
        _listKey.currentState?.removeItem(
          i,
          (context, animation) => SizeTransition(
            sizeFactor: animation,
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCard(removed),
            ),
          ),
          duration: const Duration(milliseconds: 300),
        );
      }
    }

    for (int i = 0; i < widget.items.length; i++) {
      final newItem = widget.items[i];
      if (!oldIds.contains(newItem.task.id)) {
        _items.insert(i, newItem);
        _listKey.currentState?.insertItem(i);
      } else {
        // КЛЮЧЕВОЙ МОМЕНТ: Заменяем объект в _items, чтобы обновить title, completed статус и т.д.
        final indexInLocalList = _items.indexWhere(
          (e) => e.task.id == newItem.task.id,
        );
        if (indexInLocalList != -1) {
          _items[indexInLocalList] = newItem;
        }
      }
    }

    // Вызываем setState только если данные действительно изменились
    final changed =
        _items.length != widget.items.length ||
        _items.asMap().entries.any((e) => e.value != widget.items[e.key]);
    if (changed) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _listKey,
      initialItemCount: _items.length,
      padding: EdgeInsets.symmetric(
        vertical: widget.overlayHeight + AppSpacing.sm,
      ),
      itemBuilder: (context, index, animation) {
        return SizeTransition(
          sizeFactor: animation,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCard(_items[index]),
          ),
        );
      },
    );
  }

  Widget _buildCard(TaskWithProject item) {
    return TaskCard(
      key: ValueKey(item.task.id),
      task: item.task,
      leftBorderColor: item.project != null
          ? parseHexColor(item.project!.color)
          : null,
      isOverdue: item.task.dueDate?.isBefore(widget.today) ?? false,
      onCheckChanged: () => widget.onToggleTask(item.task),
      onLongPress: () => widget.onEditTask(item),
      onDelete: () => widget.onDeleteTask(item.task.id),
      projectTitle: item.project?.name,
      isSelected: widget.selectedIds.contains(item.task.id),
      onSelected: () => widget.onToggleSelection(item.task),
      onTap: () {},
    );
  }
}

//Week view
class _WeekTasksList extends StatefulWidget {
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
  State<_WeekTasksList> createState() => _WeekTasksListState();
}

class _WeekTasksListState extends State<_WeekTasksList> {
  Map<DateTime, List<TaskWithProject>> _groupedItems = {};

  @override
  void initState() {
    super.initState();
    _groupedItems = _buildGroupedItems();
  }

  @override
  void didUpdateWidget(_WeekTasksList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _groupedItems = _buildGroupedItems();
    }
  }

  Map<DateTime, List<TaskWithProject>> _buildGroupedItems() {
    final grouped = <DateTime, List<TaskWithProject>>{};
    for (final item in widget.items) {
      final startsAt = item.task.startsAt;
      if (startsAt == null) continue;
      grouped.putIfAbsent(startsAt.startOfDay, () => []).add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = getDatesForWeek(widget.anchorDate);
    final today = DateTime.now().startOfDay;

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: widget.overlayHeight),
      itemCount: weekDates.length,
      itemBuilder: (context, index) {
        final date = weekDates[index];
        final dayItems = _groupedItems[date.startOfDay] ?? const [];

        return _WeekDaySection(
          date: date,
          isToday: date.startOfDay.isAtSameMomentAs(today),
          items: dayItems,
          selectedIds: widget.selectedIds,
          onToggleTask: widget.onToggleTask,
          onEditTask: widget.onEditTask,
          onToggleSelection: widget.onToggleSelection,
          onDeleteTask: widget.onDeleteTask,
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
                  leftBorderColor: item.project != null
                      ? parseHexColor(item.project!.color)
                      : null,
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
class _TasksHeader extends StatelessWidget {
  const _TasksHeader({
    required this.onAddPressed,
    required this.onModeChanged,
    required this.vm,
    required this.tasksScreenWidth,
    required this.onToggleUnscheduled,
  });
  final TasksViewModel vm;
  final VoidCallback onAddPressed;
  final ValueChanged<int> onModeChanged;
  final double tasksScreenWidth;
  final VoidCallback onToggleUnscheduled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppMargins.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Внутри TasksScreen (в AppBar или любой кнопке)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    // Если настройкам нужен доступ к DI, передаем его или viewModel
                    // viewModel: widget.viewModel.settingsViewModel,
                  ),
                ),
              );
            },
          ),
          Badge(
            label: StreamBuilder<TaskScreenState>(
              stream: vm.state,
              initialData: const TasksLoading(),
              builder: (context, snap) {
                final state = snap.data ?? const TasksLoading();
                final count = state.maybeWhen(
                  loaded: (_, _, _, _, unscheduled) => unscheduled.length,
                  orElse: () => 0,
                );
                return Text(
                  count.toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
            child: IconButton(
              onPressed: onToggleUnscheduled,
              icon: const Icon(Icons.inbox_rounded, color: Colors.white),
            ),
          ),
          Spacer(),
          SizedBox(
            width: 150,
            child: PillSwitcher(
              selectedIndex: vm.currentUiFlags.isEventMode ? 1 : 0,
              outerPadding: 1,
              paddingBetweenOptions: 1,
              innerPadding: 1,
              options: const [Icon(Icons.check_box), Icon(Icons.event)],
              onSelectionChanged: onModeChanged,
            ),
          ),
          Spacer(),
          GlassPanel(
            padding: EdgeInsets.all(4),
            child: Row(
              children: [
                StreamBuilder(
                  stream: vm.state,
                  builder: (_, snap) {
                    Widget? ico;
                    if (snap.hasData) {
                      snap.data!.when(
                        loading: () {},
                        empty: (_, _) {},
                        loaded: (_, selected, _, _, _) {
                          if (selected.isEmpty) return null;

                          final screenWidth = tasksScreenWidth;
                          //MediaQuery.sizeOf(context).width
                          final int maxVisibleActions = switch (screenWidth) {
                            < 400 => 1,
                            < 480 => 2,
                            < 600 => 3,
                            _ => 4, // Для больших экранов
                          };

                          // Список всех имеющихся действий
                          final actions = [
                            PopUpMenuAction(
                              icon: Icons.clear,
                              label: 'Clear selection',
                              onTap: () => vm.clearTaskSelection(),
                            ),
                            PopUpMenuAction(
                              icon: Icons.delete_forever,
                              label: 'Delete',
                              onTap: () => vm.deleteSelectedTask().then(
                                (_) => vm.clearTaskSelection(),
                              ),
                            ),
                            PopUpMenuAction(
                              icon: Icons.done_all,
                              label: "mark Done",
                              onTap: () => vm.markSelectedAsDone().then(
                                (_) => vm.clearTaskSelection(),
                              ),
                            ),
                            // Сюда можно добавлять новые кнопки (например: Архив, Завершить и т.д.)
                          ];

                          final bool isOverflowed =
                              actions.length > maxVisibleActions;
                          final visibleActions = isOverflowed
                              ? actions.take(maxVisibleActions - 1).toList()
                              : actions;
                          final overflowActions = isOverflowed
                              ? actions.skip(maxVisibleActions - 1).toList()
                              : <PopUpMenuAction>[];

                          ico = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Отображаем основные (видимые) кнопки
                              ...visibleActions.map(
                                (action) => IconButton(
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: action.onTap,
                                  icon: Icon(action.icon),
                                ),
                              ),

                              // 2. Отображаем меню "3 точки" для переполнения
                              if (isOverflowed)
                                GlassPopUpMenuButton(
                                  overflowActions: overflowActions,
                                ),
                              // 3. Счетчик выделенных элементов
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  selected.length.toString(),
                                  style: AppTypography.bodyMd,
                                ),
                              ),
                            ],
                          );
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
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.all(5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: onAddPressed,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: AppMargins.sm),
        clipBehavior: Clip.hardEdge,
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
