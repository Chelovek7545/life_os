import 'package:tasks_plugin/tasks_logic.dart';
import 'package:tasks_api/tasks_api.dart' show WorkLogsApi, Task;
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/empty_placeholder.dart';
import 'package:life_os/core/ui/fixed_fade_mask.dart';
import 'package:life_os/core/ui/glassPopUpMenuButton.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/core/ui/hierarchy/build_hierarchy_tree.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:life_os/core/ui/resizable_panel.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/ui/task_work_logs.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:projects_api/projects_api.dart';
import 'package:life_os/features/settings/settings_screen.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/date_header.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';
import 'package:life_os/features/tasks/presentation/components/task_calendar.dart';
import 'package:life_os/features/tasks/presentation/components/calendar_task_hint.dart';
import 'package:life_os/features/tasks/presentation/components/task_kanban_board.dart';

Widget? _taskRangeIndicator(Task task) {
  final start = task.startsAt;
  final end = task.endsAt;
  if (start == null ||
      end == null ||
      !end.isAfter(start) ||
      DateUtils.isSameDay(start, end)) {
    return null;
  }
  return CalendarTaskHint(
    message: 'Период: ${formatDate(start)} — ${formatDate(end)}',
    child: const Icon(
      Icons.date_range_outlined,
      size: 18,
      color: AppColors.primary,
    ),
  );
}

const double _kHeaderHeight = 42.0;
const double _kPeriodTabsHeight = 45.0;
const double _kCalendarHeight = 90.0;
const double _kDateHeaderHeight = 60.0;
const double _kTimelineTopPadding = 60.0 + _kDateHeaderHeight;
const double _kWeekTimelineTopPadding =
    _kTimelineTopPadding - _kDateHeaderHeight;
const double _kWideBreakpoint = 760.0;
const _kUnscheduledHoverColor = Color(0xFFFFB59C);

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.viewModel,
    this.onFormVisibilityChanged,
    this.workLogs,
    this.embeddedEditor = true,
  });

  final TasksViewModel viewModel;
  final WorkLogsApi? workLogs;
  final bool embeddedEditor;
  final ValueChanged<bool>? onFormVisibilityChanged;

  @override
  State<TasksScreen> createState() => TasksScreenState();
}

class TasksScreenState extends State<TasksScreen> {
  bool _weekHorizontal = false;
  bool get _wideWeek =>
      _weekHorizontal &&
      !_kanbanMode &&
      !widget.viewModel.currentUiFlags.isEventMode &&
      widget.viewModel.currentFilterValue.period == DatePeriod.week;
  bool _kanbanMode = false;
  bool _showUnscheduledOverlay = false;
  bool _draggingFromOverlay = false;
  bool _hoveringUnscheduled = false;
  final GlobalKey _unscheduledOverlayKey = GlobalKey();
  bool _showHierarchyOverlay = false;
  bool _draggingFromHierarchy = false;

  bool _isOverUnscheduled(Offset globalPosition) {
    final box =
        _unscheduledOverlayKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final local = box.globalToLocal(globalPosition);
    return local.dx >= 0 &&
        local.dy >= 0 &&
        local.dx <= box.size.width &&
        local.dy <= box.size.height;
  }

  void _onHoverUnscheduled(bool hovering) {
    if (_hoveringUnscheduled == hovering) return;
    setState(() => _hoveringUnscheduled = hovering);
  }

  Future<void> _unscheduleTask(Task task) async {
    await widget.viewModel.updateTask(
      task.copyWith(startsAt: Wrapped(null), endsAt: Wrapped(null)),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleUnscheduledOverlay() {
    setState(() {
      _showUnscheduledOverlay = !_showUnscheduledOverlay;
      _showHierarchyOverlay = false;
    });
  }

  void _toggleHierarchyOverlay() {
    setState(() {
      _showHierarchyOverlay = !_showHierarchyOverlay;
      _showUnscheduledOverlay = false;
    });
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
          key: _unscheduledOverlayKey,
          top: AppSpacing.sm + _kHeaderHeight + AppSpacing.sm,
          left: 8,
          width: overlayWidth,
          child: IgnorePointer(
            ignoring: _draggingFromOverlay,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg + 2),
                border: _hoveringUnscheduled
                    ? Border.all(color: _kUnscheduledHoverColor, width: 2)
                    : null,
                boxShadow: _hoveringUnscheduled
                    ? [
                        BoxShadow(
                          color: _kUnscheduledHoverColor.withValues(alpha: 0.4),
                          blurRadius: 20,
                          spreadRadius: -6,
                        ),
                      ]
                    : null,
              ),
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
                              Text(
                                _hoveringUnscheduled
                                    ? 'Drop to unschedule'
                                    : 'Unscheduled',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _hoveringUnscheduled
                                      ? _kUnscheduledHoverColor
                                      : null,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => setState(
                                  () => _showUnscheduledOverlay = false,
                                ),
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
                                    child: LongPressDraggable<Task>(
                                      data: item.task,
                                      hapticFeedbackOnStart: true,
                                      onDragStarted: () => setState(
                                        () => _draggingFromOverlay = true,
                                      ),
                                      onDraggableCanceled: (_, __) => setState(
                                        () => _draggingFromOverlay = false,
                                      ),
                                      onDragEnd: (_) => setState(
                                        () => _draggingFromOverlay = false,
                                      ),
                                      feedback: _buildDragFeedback(item),
                                      childWhenDragging: Opacity(
                                        opacity: 0.35,
                                        child: _buildUnscheduledCard(
                                          item,
                                          today,
                                        ),
                                      ),
                                      child: _buildUnscheduledCard(item, today),
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildUnscheduledCard(TaskWithProject item, DateTime today) {
    return TaskCard(
      workLogs: widget.workLogs,
      task: item.task,
      indicator: _taskRangeIndicator(item.task),
      projectTitle: item.project?.name,
      leftBorderColor: item.project != null
          ? parseHexColor(item.project!.color)
          : null,
      isOverdue: item.task.dueDate?.isBefore(today) ?? false,
      onCheckChanged: () {
        widget.viewModel.toggleTask(item.task);
      },
      onTap: () => _openTaskEditor(item),
      onDelete: () => widget.viewModel.deleteTask(item.task.id),
      isSelected: false,
    );
  }

  Widget _buildDragFeedback(TaskWithProject item) {
    final accent = item.project != null
        ? parseHexColor(item.project!.color)
        : AppColors.primary;
    return Material(
      elevation: 8,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: accent, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator, size: 20, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Drop on calendar',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyOverlay(
    double overlayHeight,
    DateTime today,
    double overlayWidth,
  ) {
    if (!_showHierarchyOverlay) {
      return const SizedBox.shrink();
    }
    return Positioned(
      top: AppSpacing.sm + _kHeaderHeight + AppSpacing.sm,
      left: 8,
      width: overlayWidth,
      child: IgnorePointer(
        ignoring: _draggingFromHierarchy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg + 2),
          ),
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
                            'Hierarchy',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _showHierarchyOverlay = false),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Flexible(child: _buildHierarchyContent()),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHierarchyContent() {
    return StreamBuilder<List<Project>>(
      stream: widget.viewModel.watchProjects(),
      initialData: const [],
      builder: (context, projectSnapshot) {
        final projects = projectSnapshot.data ?? const <Project>[];
        return StreamBuilder<List<Task>>(
          stream: widget.viewModel.watchAllTasks(),
          initialData: const [],
          builder: (context, taskSnapshot) {
            final tasks = taskSnapshot.data ?? const <Task>[];
            return HierarchyColumn(
              height: 500,
              nodes: buildHierarchyTree(projects, tasks),
              draggableBuilder: _buildDraggableHierarchyNode,
            );
          },
        );
      },
    );
  }

  Widget _buildDraggableHierarchyNode(HierarchyNode node, Widget child) {
    final task = node.data;
    if (task is! Task) return child;
    return LongPressDraggable<Task>(
      data: task,
      hapticFeedbackOnStart: true,
      onDragStarted: () => setState(() => _draggingFromHierarchy = true),
      onDragEnd: (_) => setState(() => _draggingFromHierarchy = false),
      onDraggableCanceled: (_, __) =>
          setState(() => _draggingFromHierarchy = false),
      feedback: _buildHierarchyDragFeedback(task),
      childWhenDragging: Opacity(opacity: 0.35, child: child),
      child: child,
    );
  }

  Widget _buildHierarchyDragFeedback(Task task) {
    return Material(
      elevation: 8,
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.primary, width: 2),
        ),
        child: Row(
          children: [
            const Icon(Icons.drag_indicator, size: 20, color: Colors.white54),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.event, size: 10, color: Colors.white54),
                      SizedBox(width: 4),
                      Text(
                        'Drop on calendar',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskBody(double overlayHeight, DateTime today) {
    if (_kanbanMode) {
      return StreamBuilder<TaskScreenState>(
        stream: widget.viewModel.state,
        builder: (context, snapshot) {
          Widget board(List<TaskWithProject> items) => TaskKanbanBoard(
            items: items,
            topPadding: overlayHeight,
            workLogs: widget.workLogs,
            onOpen: _openTaskEditor,
            onToggle: widget.viewModel.toggleTask,
            onMove: (task, status) async {
              try {
                await widget.viewModel.setTaskStatus(task.id, status);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Не удалось изменить статус задачи'),
                    ),
                  );
                }
              }
            },
          );
          return (snapshot.data ?? const TasksLoading()).when(
            loading: () => const Center(child: CircularProgressIndicator()),
            empty: (_, _) => board(const []),
            error: (message) => Center(child: Text(message)),
            loaded: (items, _, _, _, unscheduled) =>
                board([...items, ...unscheduled]),
          );
        },
      );
    }
    return StreamBuilder<TaskScreenState>(
      stream: widget.viewModel.state,
      initialData: const TasksLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const TasksLoading();

        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          empty: (_, _) =>
              widget.viewModel.currentFilterValue.period == DatePeriod.week
              ? _buildWeekTasks(const [], const {}, overlayHeight)
              : const EmptyPlaceholder(),
          error: (message) => Center(child: Text(message)),
          loaded: (items, selectedTasks, _, _, _) {
            if (items.isEmpty &&
                widget.viewModel.currentFilterValue.period != DatePeriod.week) {
              return const EmptyPlaceholder();
            }

            final selectedIds = selectedTasks.map((task) => task.id).toSet();
            final period = widget.viewModel.currentFilterValue.period;

            return switch (period) {
              DatePeriod.week => _buildWeekTasks(
                items,
                selectedIds,
                overlayHeight,
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
                workLogs: widget.workLogs,
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
                workLogs: widget.workLogs,
              ),
            };
          },
        );
      },
    );
  }

  Widget _buildEventBody(bool isWide, DateTime anchorDate) => TaskCalendar(
    viewModel: widget.viewModel,
    isWeek: isWide,
    topPadding: isWide ? _kWeekTimelineTopPadding : _kTimelineTopPadding,
    isOverUnscheduled: _isOverUnscheduled,
    onEventToUnscheduled: _unscheduleTask,
    onHoverUnscheduled: _onHoverUnscheduled,
  );

  Widget _buildWeekTasks(
    List<TaskWithProject> items,
    Set<String> selectedIds,
    double overlayHeight,
  ) => _WeekTasksList(
    items: items,
    selectedIds: selectedIds,
    overlayHeight: overlayHeight,
    anchorDate: widget.viewModel.currentFilterValue.anchorDate,
    horizontal: _weekHorizontal,
    onMove: (task, source, target) async {
      try {
        await widget.viewModel.moveTaskToDay(task.id, source, target);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось перенести задачу')),
          );
        }
      }
    },
    onToggleTask: widget.viewModel.toggleTask,
    onEditTask: _openTaskEditor,
    onToggleSelection: widget.viewModel.toggleTaskSelection,
    onDeleteTask: widget.viewModel.deleteTask,
    workLogs: widget.workLogs,
  );
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
          selectedMode: _kanbanMode
              ? 2
              : widget.viewModel.currentUiFlags.isEventMode
              ? 1
              : 0,
          vm: widget.viewModel,
          tasksScreenWidth: tasksScreenWidth,
          onAddPressed: widget.viewModel.currentUiFlags.isFormVisible
              ? () {
                  widget.viewModel.hideForm();
                  if (!widget.embeddedEditor) widget.viewModel.disableForm();
                }
              : widget.viewModel.showForm,
          onModeChanged: (index) => _onModeChanged(index, isWide),
          onToggleUnscheduled: _toggleUnscheduledOverlay,
          onToggleHierarchy: _toggleHierarchyOverlay,
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

                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: SegmentedPillControl(
                            tabs: const ['Day', 'Week', 'Month'],
                            currentIdx: currentFilter.period.index,
                            onTabChanged: _onPeriodChanged,
                          ),
                        ),
                        if (currentFilter.period == DatePeriod.week &&
                            !_kanbanMode)
                          IconButton(
                            key: const ValueKey('tasks.week-layout'),
                            tooltip: _weekHorizontal
                                ? 'Дни по вертикали'
                                : 'Дни по горизонтали',
                            onPressed: () => setState(
                              () => _weekHorizontal = !_weekHorizontal,
                            ),
                            icon: Icon(
                              _weekHorizontal
                                  ? Icons.view_agenda_outlined
                                  : Icons.view_week_outlined,
                            ),
                          ),
                      ],
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
    if (!widget.embeddedEditor) return const SizedBox.shrink();
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
    if (index < 0 || index > 2) return;
    setState(() => _kanbanMode = index == 2);
    if (index == 1) _onPeriodChanged(isWide ? DatePeriod.week.index : 0);
    if (widget.viewModel.currentUiFlags.isEventMode != (index == 1)) {
      widget.viewModel.toggleEventMode();
    }
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
    widget.viewModel.updateFilter((old) => old.copyWith(period: period));
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

    return StreamBuilder<TasksUiFlags>(
      stream: widget.viewModel.uiFlags,
      initialData: TasksUiFlags(),
      builder: (context, snapshot) {
        final uiFlags = snapshot.data ?? TasksUiFlags();
        final today = DateTime.now().startOfDay;

        return StreamBuilder<TaskFilterConfig>(
          stream: widget.viewModel.currentFilter,
          initialData: widget.viewModel.currentFilterValue,
          builder: (context, snapshot) {
            final period =
                (snapshot.data ?? widget.viewModel.currentFilterValue).period;
            final overlayHeight =
                _kHeaderHeight +
                _kPeriodTabsHeight +
                AppSpacing.sm * 2 +
                (period == DatePeriod.day && !uiFlags.isEventMode
                    ? _kCalendarHeight + AppSpacing.sm
                    : 0);

            if (isLandscape) {
              return _buildLandscapeLayout(
                overlayHeight,
                today,
                widget.embeddedEditor && uiFlags.isFormVisible,
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
          constraints: BoxConstraints(
            maxWidth: _kanbanMode || _wideWeek ? double.infinity : 550,
          ),
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
        _buildHierarchyOverlay(
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
                      maxWidth: isWide || _kanbanMode || _wideWeek
                          ? double.infinity
                          : 550,
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
                  _buildHierarchyOverlay(
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
          workLogs: widget.workLogs,
          onChanged: (draft) {
            widget.viewModel.draftTask = draft;
          },
          forceExpanded: forceExpanded,
          onFormVisibilityChanged: (value) =>
              widget.onFormVisibilityChanged?.call(value),
          onCancel: () {
            widget.viewModel.hideForm();
            if (forceExpanded) widget.viewModel.disableForm();
          },
          height: forceExpanded
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height * 0.8,
          task: widget.viewModel.draftTask,
          projects: widget.viewModel.watchProjects(),
          isEditMode: widget.viewModel.activeTaskWithProject != null,
          onDelete: (taskId) {
            widget.viewModel.deleteTask(taskId);
            widget.viewModel.hideForm();
            if (forceExpanded) widget.viewModel.disableForm();
          },
          onSubmit: (task) {
            _submitTask(task);
            if (forceExpanded) widget.viewModel.disableForm();
          },
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
    this.workLogs,
  });

  final List<TaskWithProject> items;
  final Set<String> selectedIds;
  final double overlayHeight;
  final DateTime today;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<TaskWithProject> onEditTask;
  final ValueChanged<Task> onToggleSelection;
  final ValueChanged<String> onDeleteTask;
  final WorkLogsApi? workLogs;

  @override
  State<_TaskList> createState() => _TaskListState();
}

class _TaskListState extends State<_TaskList>
    with SingleTickerProviderStateMixin {
  final _listKey = GlobalKey<AnimatedListState>();
  final _items = <TaskWithProject>[];
  late final _stretch = AnimationController(
    vsync: this,
    upperBound: .04,
    duration: const Duration(milliseconds: 220),
  );
  bool _fitsViewport = false;

  @override
  void dispose() {
    _stretch.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetricsNotification notification) {
    if (notification.depth != 0) return false;
    final fits = notification.metrics.maxScrollExtent <= 0;
    if (fits != _fitsViewport) {
      setState(() => _fitsViewport = fits);
      _stretch.value = 0;
    }
    return false;
  }

  bool _onScroll(ScrollNotification notification) {
    if (!_fitsViewport || notification.depth != 0) return false;
    if (notification is OverscrollNotification &&
        !MediaQuery.disableAnimationsOf(context) &&
        !MediaQuery.accessibleNavigationOf(context)) {
      _stretch.stop();
      final extent = notification.metrics.viewportDimension;
      if (extent > 0) {
        _stretch.value =
            (_stretch.value + notification.overscroll.abs() / extent * .08)
                .clamp(0, _stretch.upperBound);
      }
    } else if (notification is ScrollEndNotification) {
      _stretch.animateBack(0, curve: Curves.easeOutCubic);
    }
    return false;
  }

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
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(
            context,
          ).copyWith(overscroll: !_fitsViewport),
          child: AnimatedBuilder(
            animation: _stretch,
            builder: (context, child) => Transform.scale(
              scaleY: 1 + _stretch.value,
              alignment: Alignment.topCenter,
              child: child,
            ),
            child: AnimatedList(
              key: _listKey,
              primary: false,
              physics: _fitsViewport
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
              initialItemCount: _items.length,
              padding: EdgeInsets.only(
                top: widget.overlayHeight + AppSpacing.sm,
                bottom: AppSpacing.sm,
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
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(TaskWithProject item) {
    return TaskCard(
      key: ValueKey(item.task.id),
      workLogs: widget.workLogs,
      task: item.task,
      indicator: _taskRangeIndicator(item.task),
      leftBorderColor: item.project != null
          ? parseHexColor(item.project!.color)
          : null,
      isOverdue: item.task.dueDate?.isBefore(widget.today) ?? false,
      onCheckChanged: () => widget.onToggleTask(item.task),
      onTap: () => widget.onEditTask(item),
      onDelete: () => widget.onDeleteTask(item.task.id),
      projectTitle: item.project?.name,
      isSelected: widget.selectedIds.contains(item.task.id),
      onSelected: () => widget.onToggleSelection(item.task),
      //onTap: () {},
    );
  }
}

//Week view
class _WeekTaskDrag {
  const _WeekTaskDrag(this.task, this.sourceDay);
  final Task task;
  final DateTime sourceDay;
}

class _WeekTasksList extends StatefulWidget {
  const _WeekTasksList({
    required this.items,
    required this.selectedIds,
    required this.overlayHeight,
    required this.anchorDate,
    required this.horizontal,
    required this.onMove,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onToggleSelection,
    required this.onDeleteTask,
    this.workLogs,
  });
  final List<TaskWithProject> items;
  final Set<String> selectedIds;
  final double overlayHeight;
  final DateTime anchorDate;
  final bool horizontal;
  final void Function(Task, DateTime, DateTime) onMove;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<TaskWithProject> onEditTask;
  final ValueChanged<Task> onToggleSelection;
  final ValueChanged<String> onDeleteTask;
  final WorkLogsApi? workLogs;

  @override
  State<_WeekTasksList> createState() => _WeekTasksListState();
}

class _WeekTasksListState extends State<_WeekTasksList> {
  @override
  Widget build(BuildContext context) {
    final anchorDate = widget.anchorDate;
    final items = widget.items;
    final horizontal = widget.horizontal;
    final selectedIds = widget.selectedIds;
    final overlayHeight = widget.overlayHeight;
    final onMove = widget.onMove;
    final onToggleTask = widget.onToggleTask;
    final onEditTask = widget.onEditTask;
    final onToggleSelection = widget.onToggleSelection;
    final onDeleteTask = widget.onDeleteTask;
    final workLogs = widget.workLogs;
    final days = getDatesForWeek(anchorDate);
    final today = DateUtils.dateOnly(DateTime.now());
    final grouped = <DateTime, List<TaskWithProject>>{};
    for (final item in items) {
      final start = item.task.startsAt;
      if (start == null) continue;
      final end = item.task.endsAt;
      final last = end != null && !end.isBefore(start) ? end : start;
      for (final day in days) {
        final date = DateUtils.dateOnly(day);
        if (!date.isBefore(DateUtils.dateOnly(start)) &&
            !date.isAfter(DateUtils.dateOnly(last))) {
          grouped.putIfAbsent(date, () => []).add(item);
        }
      }
    }
    Widget section(DateTime day) => _WeekDaySection(
      date: DateUtils.dateOnly(day),
      isToday: DateUtils.isSameDay(day, today),
      horizontal: horizontal,
      items: grouped[DateUtils.dateOnly(day)] ?? const [],
      selectedIds: selectedIds,
      onMove: onMove,
      onToggleTask: onToggleTask,
      onEditTask: onEditTask,
      onToggleSelection: onToggleSelection,
      onDeleteTask: onDeleteTask,
      workLogs: workLogs,
    );
    if (!horizontal) {
      return ListView.builder(
        key: const ValueKey('tasks.week.vertical'),
        padding: EdgeInsets.symmetric(vertical: overlayHeight),
        itemCount: days.length,
        itemBuilder: (_, index) => section(days[index]),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: overlayHeight + AppSpacing.md, bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = ((constraints.maxWidth - 72) / 7).clamp(
            260.0,
            double.infinity,
          );
          return SingleChildScrollView(
            key: const ValueKey('tasks.week.horizontal'),
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i != 0) const SizedBox(width: 12),
                  SizedBox(width: width, child: section(days[i])),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeekDaySection extends StatelessWidget {
  const _WeekDaySection({
    required this.date,
    required this.isToday,
    required this.horizontal,
    required this.items,
    required this.selectedIds,
    required this.onMove,
    required this.onToggleTask,
    required this.onEditTask,
    required this.onToggleSelection,
    required this.onDeleteTask,
    this.workLogs,
  });
  final DateTime date;
  final bool isToday;
  final bool horizontal;
  final List<TaskWithProject> items;
  final Set<String> selectedIds;
  final void Function(Task, DateTime, DateTime) onMove;
  final ValueChanged<Task> onToggleTask;
  final ValueChanged<TaskWithProject> onEditTask;
  final ValueChanged<Task> onToggleSelection;
  final ValueChanged<String> onDeleteTask;
  final WorkLogsApi? workLogs;

  Widget _card(TaskWithProject item) => LayoutBuilder(
    builder: (_, constraints) => TaskWorkLogsBuilder(
      taskId: item.task.id,
      repository: workLogs,
      builder: (footer) {
        Widget card() => TaskCard(
          key: ValueKey(item.task.id),
          footer: footer,
          task: item.task,
          indicator: _taskRangeIndicator(item.task),
          leftBorderColor: item.project == null
              ? null
              : parseHexColor(item.project!.color),
          onCheckChanged: () => onToggleTask(item.task),
          onTap: () => onEditTask(item),
          onDelete: horizontal ? null : () => onDeleteTask(item.task.id),
          projectTitle: item.project?.name,
          isSelected: selectedIds.contains(item.task.id),
          onSelected: () => onToggleSelection(item.task),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: LongPressDraggable<_WeekTaskDrag>(
            key: ValueKey(('week.task', date, item.task.id)),
            data: _WeekTaskDrag(item.task, date),
            feedback: Material(
              key: ValueKey(('week.feedback', date, item.task.id)),
              color: Colors.transparent,
              child: SizedBox(
                width: constraints.maxWidth,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.primary, width: 1.2),
                  ),
                  child: card(),
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: .4, child: card()),
            child: card(),
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) => DragTarget<_WeekTaskDrag>(
    key: ValueKey(('week.day', date)),
    onWillAcceptWithDetails: (details) =>
        !DateUtils.isSameDay(details.data.sourceDay, date),
    onAcceptWithDetails: (details) =>
        onMove(details.data.task, details.data.sourceDay, date),
    builder: (context, candidates, _) {
      final color = candidates.isNotEmpty
          ? Color.alphaBlend(
              AppColors.primary.withValues(alpha: .12),
              AppColors.surfaceContainerLow,
            )
          : AppColors.surfaceContainerLow;
      final header = Padding(
        padding: EdgeInsets.only(
          top: horizontal ? 12 : AppSpacing.xl,
          bottom: AppSpacing.xs,
        ),
        child: Row(
          children: [
            if (isToday) ...[
              const Icon(
                Icons.circle,
                size: 8,
                color: AppColors.primaryContainer,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '${getWeekDayName(date.weekday)} ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
                  style: AppTypography.headlineLgMobile.copyWith(
                    color: isToday
                        ? AppColors.primaryContainer
                        : AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
      final empty = Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          'No tasks',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant.withValues(alpha: .5),
          ),
        ),
      );
      return DecoratedBox(
        decoration: BoxDecoration(
          color: horizontal || candidates.isNotEmpty
              ? color
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: horizontal || candidates.isNotEmpty
              ? Border.all(
                  color: candidates.isEmpty
                      ? AppColors.borderGlass
                      : AppColors.primary,
                )
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (horizontal)
                Expanded(
                  child: ClipRect(
                    child: ScrollConfiguration(
                      behavior: AppScrollBehavior(fadeColor: color),
                      child: items.isEmpty
                          ? Align(alignment: Alignment.topLeft, child: empty)
                          : ListView.builder(
                              padding: const EdgeInsets.only(top: 8),
                              itemCount: items.length,
                              itemBuilder: (_, index) => _card(items[index]),
                            ),
                    ),
                  ),
                )
              else if (items.isEmpty)
                empty
              else
                ...items.map(_card),
            ],
          ),
        ),
      );
    },
  );
}

// Header elements
class _TasksHeader extends StatelessWidget {
  const _TasksHeader({
    required this.onAddPressed,
    required this.onModeChanged,
    required this.vm,
    required this.tasksScreenWidth,
    required this.onToggleUnscheduled,
    required this.onToggleHierarchy,
    required this.selectedMode,
  });
  final TasksViewModel vm;
  final VoidCallback onAddPressed;
  final ValueChanged<int> onModeChanged;
  final double tasksScreenWidth;
  final VoidCallback onToggleUnscheduled;
  final VoidCallback onToggleHierarchy;
  final int selectedMode;

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
          if (MediaQuery.sizeOf(context).width > 410)
            IconButton(
              tooltip: 'Hierarchy',
              onPressed: onToggleHierarchy,
              icon: const Icon(Icons.account_tree_rounded, color: Colors.white),
            ),
          Spacer(),
          SizedBox(
            width: 150,
            child: PillSwitcher(
              selectedIndex: selectedMode,
              outerPadding: 1,
              paddingBetweenOptions: 1,
              innerPadding: 1,
              options: const [
                Tooltip(message: 'Список', child: Icon(Icons.check_box)),
                Tooltip(message: 'Календарь', child: Icon(Icons.event)),
                Tooltip(
                  message: 'Канбан',
                  child: Icon(Icons.view_kanban_outlined),
                ),
              ],
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
                            < 450 => 1,
                            < 500 => 2,
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

class CalendarRow extends StatefulWidget {
  const CalendarRow({
    super.key,
    required this.selectedDate,
    required this.onDaySelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  @override
  State<CalendarRow> createState() => _CalendarRowState();
}

class _CalendarRowState extends State<CalendarRow> {
  static const _weekSwipeThreshold = 72.0;
  final _controller = ScrollController();
  double _dragOverflow = 0;
  double _wheelOverflow = 0;
  bool _wheelChangedWeek = false;
  Timer? _wheelIdle;

  @override
  void dispose() {
    _wheelIdle?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CalendarRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldWeek = getWeekStart(oldWidget.selectedDate);
    final newWeek = getWeekStart(widget.selectedDate);
    if (oldWeek == newWeek) return;
    _dragOverflow = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      _controller.jumpTo(
        newWeek.isAfter(oldWeek) ? 0 : _controller.position.maxScrollExtent,
      );
    });
  }

  void _changeWeek(double overflow) {
    final date = widget.selectedDate;
    widget.onDaySelected(
      DateTime(date.year, date.month, date.day + (overflow > 0 ? 7 : -7)),
    );
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axis != Axis.horizontal) {
      return false;
    }
    if (notification is ScrollStartNotification &&
        notification.dragDetails != null) {
      _dragOverflow = 0;
    } else if (notification is OverscrollNotification &&
        notification.dragDetails != null) {
      final delta = notification.overscroll;
      if (delta.sign != _dragOverflow.sign) _dragOverflow = 0;
      _dragOverflow += delta;
    } else if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _dragOverflow = 0;
    } else if (notification is ScrollEndNotification) {
      final overflow = _dragOverflow;
      _dragOverflow = 0;
      if (overflow.abs() >= _weekSwipeThreshold) _changeWeek(overflow);
    }
    return false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_controller.hasClients) return;
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    final shift =
        keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
    var delta = shift ? event.scrollDelta.dy : event.scrollDelta.dx;
    final position = _controller.position;
    if (position.axisDirection == AxisDirection.left) delta = -delta;
    if (delta == 0) return;
    _wheelIdle?.cancel();
    _wheelIdle = Timer(const Duration(milliseconds: 220), () {
      _wheelOverflow = 0;
      _wheelChangedWeek = false;
    });
    final atEdge = delta > 0
        ? position.pixels >= position.maxScrollExtent
        : position.pixels <= position.minScrollExtent;
    if (!atEdge) {
      _wheelOverflow = 0;
      return;
    }
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!mounted || _wheelChangedWeek) return;
      if (delta.sign != _wheelOverflow.sign) _wheelOverflow = 0;
      _wheelOverflow += delta;
      if (_wheelOverflow.abs() >= _weekSwipeThreshold) {
        _wheelChangedWeek = true;
        _wheelOverflow = 0;
        _changeWeek(delta);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekDates = getDatesForWeek(widget.selectedDate);

    // The date cells blur the task list behind this overlay. Viewport effects
    // isolate that backdrop in an offscreen layer, so keep this strip unfiltered.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(overscroll: false),
      child: SizedBox(
        height: 90,
        child: Listener(
          onPointerSignal: _onPointerSignal,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.separated(
              controller: _controller,
              physics: const AlwaysScrollableScrollPhysics(
                parent: ClampingScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppMargins.sm),
              clipBehavior: Clip.hardEdge,
              scrollDirection: Axis.horizontal,
              itemCount: weekDates.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final date = weekDates[index];
                final isSelected = date.startOfDay.isAtSameMomentAs(
                  widget.selectedDate.startOfDay,
                );

                return DateTimelineCard(
                  weekday: getWeekDayName(date.weekday),
                  day: '${date.day}',
                  isSelected: isSelected,
                  onTap: () => widget.onDaySelected(date),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
