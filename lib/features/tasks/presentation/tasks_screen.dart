import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/empty_placeholder.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
//import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

const double _kFormExpandedHeight = 1000.0;

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key, required this.viewModel});
  final TasksViewModel viewModel;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // int dayIndex = 0;
  //bool _shouldRenderForm = false;

  @override
  void dispose() {
    widget.viewModel.dispose();
    super.dispose();
  }

  Widget _buildWeekView(
    List<TaskWithProject> items,
    List<Task> selectedTasks,
    double overlayHeight,
  ) {
    final Map<DateTime, List<TaskWithProject>> grouped = {};
    for (final item in items) {
      final day = item.task.startsAt!.startOfDay;
      grouped.putIfAbsent(day, () => []).add(item);
    }

    final anchorDate = widget.viewModel.currentFilterValue.anchorDate;
    final weekDates = getDatesForWeek(anchorDate);

    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final widgets = <Widget>[];
    final now = DateTime.now();

    for (final date in weekDates) {
      final dayName = dayNames[date.weekday - 1];
      final isToday =
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;

      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(8, AppSpacing.lg, 8, AppSpacing.xs),
          child: Row(
            children: [
              if (isToday) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryContainer.withValues(
                          alpha: 0.8,
                        ),
                        blurRadius: 10,
                      ),
                    ],
                    color: AppColors
                        .primaryContainer, // оранжевый, используется в приложении
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
              ],
              Text(
                '$dayName ${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}',
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
      );

      final dayTasks = grouped[date];
      if (dayTasks != null) {
        for (final item in dayTasks) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(
                bottom: AppSpacing.sm,
                left: 8,
                right: 8,
              ),
              child: TaskCard(
                task: item.task,
                onCheckChanged: () async {
                  await widget.viewModel.toggleTask(item.task);
                },
                onLongPress: () {
                  widget.viewModel.startEditingTask(item);
                  widget.viewModel.showForm();
                },
                projectTitle: item.project?.name,
                isSelected: selectedTasks.any((t) => t.id == item.task.id),
                onSelected: () =>
                    widget.viewModel.toggleTaskSelection(item.task),
                onTap: () {},
              ),
            ),
          );
        }
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 16),
            child: Text(
              'No tasks',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant.withOpacity(0.5),
              ),
            ),
          ),
        );
      }
    }
    return ListView(
      padding: EdgeInsets.symmetric(vertical: overlayHeight),
      children: widgets,
    );
  }

  static const Gradient _maskingGradient = LinearGradient(
    // This gradient goes from fully transparent to fully opaque black...
    colors: [
      Colors.transparent,
      Colors.black,
      Colors.black,
      Colors.transparent,
    ],
    // ... from the top (transparent) to half (0.5) of the way to the bottom.
    stops: [0.0, 0.15, 0.96, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  bool showCalendar = true;
  @override
  Widget build(BuildContext context) {
    const kHeaderH = 40.0;
    const kPillH = 45.0;
    const kCalendarH = 86.0;

    double overlayHeight =
        kHeaderH + kPillH + (showCalendar ? kCalendarH + AppSpacing.sm + AppSpacing.md : 0);

    return StreamBuilder<bool>(
      stream: widget.viewModel.isFormVisible,
      initialData: false,
      builder: (context, snap) {
        final isFormVisible = snap.data ?? false;

        // if (isFormVisible) {

        //   _shouldRenderForm = true;
        // }

        return Scaffold(
          //appBar: AppBar(title: const Text('Tasks')),
          // floatingActionButton: FloatingActionButton(
          //   onPressed: () => isFormVisible
          //       ? widget.viewModel.hideForm()
          //       : widget.viewModel.showForm(),
          //   tooltip: 'Новая задача',
          //   child: Icon(isFormVisible ? Icons.close : Icons.add),
          // ),
          backgroundColor: AppColors.surfaceDim,
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      _maskingGradient.createShader(bounds),
                  blendMode: BlendMode.dstIn,
                  child: Column(
                    children: [
                      Expanded(
                        child: StreamBuilder<TaskScreenState>(
                          stream: widget.viewModel.state,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const CircularProgressIndicator();
                            }
                            return snapshot.data!.when(
                              loading: () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                              empty: (_, _) => EmptyPlaceholder(),
                              error: (e) => Text(e),
                              loaded: (items, selectedTasks, _, curTask) {
                                if (items.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'No tasks available yet.',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  );
                                }

                                if (widget
                                        .viewModel
                                        .currentFilterValue
                                        .period ==
                                    DatePeriod.week) {
                                  return _buildWeekView(
                                    items,
                                    selectedTasks,
                                    overlayHeight,
                                  );
                                }

                                return ListView.separated(
                                  padding: EdgeInsets.symmetric(
                                    vertical: overlayHeight + AppSpacing.sm,
                                  ),
                                  itemCount: items.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final item = items[index];
                                    return TaskCard(
                                      task: item.task,
                                      onCheckChanged: () async {
                                        await widget.viewModel.toggleTask(
                                          item.task,
                                        );
                                      },
                                      onLongPress: () {
                                        widget.viewModel.startEditingTask(item);
                                        widget.viewModel.showForm();
                                      },
                                      projectTitle: item.project?.name,
                                      isSelected: selectedTasks.any(
                                        (t) => t.id == item.task.id,
                                      ),
                                      onSelected: () => widget.viewModel
                                          .toggleTaskSelection(item.task),
                                      onTap: () {},
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                //                 decoration: const BoxDecoration(
                //   gradient: LinearGradient(
                //     begin: Alignment.topCenter,
                //     end: Alignment.bottomCenter,
                //     stops: [0, 0.9, 0.95, 1],
                //     colors: [Colors.black, Colors.black54, Colors.black12,  Colors.transparent],
                //   ),
                // ),
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(
                      () => isFormVisible
                          ? widget.viewModel.hideForm()
                          : widget.viewModel.showForm(),
                      context,
                    ),
                    StreamBuilder(
                      stream: widget.viewModel.currentFilter,
                      builder: (_, snapshot) {
                        final currentFilter =
                            snapshot.data ??
                            TaskFilterConfig(anchorDate: DateTime.now());

                        // Извлекаем "опорную" дату из текущего фильтра для сохранения контекста
                        final DateTime anchorDate = currentFilter.anchorDate;

                        return Column(
                          children: [
                            Align(
                              child: SegmentedPillControl(
                                tabs: ["Day", "Week", "Month"],
                                onTabChanged: (index) {
                                  setState(() {
                                    if (index == 0) {
                                      showCalendar = true;
                                    } else {
                                      showCalendar = false;
                                    }
                                  });
                                  widget.viewModel.updateFilter(
                                    (old) => old.copyWith(
                                      period: DatePeriod.values[index],
                                    ),
                                  );
                                },
                              ),
                            ),
                            if (currentFilter.period == DatePeriod.day) ...[
                              SizedBox(height: AppSpacing.sm),
                              CalendarRow(
                                selectedDate: anchorDate,
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
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
                left: 0,
                right: 0,
                bottom: isFormVisible ? 0 : -_kFormExpandedHeight,
                height: _kFormExpandedHeight,
                onEnd: () {
                  if (!isFormVisible) {
                    setState(() {
                      widget.viewModel.disableForm();
                      //_shouldRenderForm = false;
                    });
                  }
                },
                child: widget.viewModel.shouldRenderForm
                    ? CollapsibleTaskForm(
                        onCancel: () => widget.viewModel.hideForm(),
                        height: MediaQuery.sizeOf(context).height * 0.8,
                        task:
                            widget.viewModel.activeTaskWithProject?.task ??
                            widget.viewModel.draftTask,
                        projects: widget.viewModel.watchProjects(),
                        isEditMode:
                            widget.viewModel.activeTaskWithProject != null,
                        onSubmit: (Task task) {
                          if (widget.viewModel.activeTaskWithProject != null) {
                            print("update");
                            widget.viewModel.updateTask(task);
                          } else {
                            widget.viewModel.addTask(task);
                          }
                          widget.viewModel.hideForm();
                        },
                      )
                    : const SizedBox.shrink(),
              ),
              // CollapsibleTaskForm(
              //   isVisible: isFormVisible,
              //   task:
              //       widget.viewModel.activeTaskWithProject?.task ??
              //       widget.viewModel.draftTask,
              //   height: MediaQuery.sizeOf(context).height * 0.8,
              //   onSubmit: (Task task) {
              //     if (widget.viewModel.activeTaskWithProject != null) {
              //       print("update");
              //       widget.viewModel.updateTask(task);
              //     } else {
              //       widget.viewModel.addTask(task);
              //     }
              //     widget.viewModel.hideForm();
              //   },
              //   onCancel: () => widget.viewModel.hideForm(),
              //   projects: widget.viewModel.watchProjects(),
              //   isEditMode: widget.viewModel.activeTaskWithProject != null,
              // ),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildHeader(VoidCallback onPressed, BuildContext context) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.settings_outlined, color: Colors.white),
      ),
      //const Icon(Icons.dashboard_outlined, color: Colors.white),
      //const SizedBox(width: 8),
      Text('Main', style: Theme.of(context).textTheme.headlineLarge),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.all(5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppRadius.full,
            ), // 👈 Радиус скругления
          ),
          //fixedSize: Size(30, 30),
          //minimumSize: Size.zero,
          //tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
        child: Icon(Icons.add),
      ),
    ],
  );
}

class CalendarRow extends StatelessWidget {
  final DateTime selectedDate;
  final void Function(DateTime date) onDaySelected;

  const CalendarRow({
    super.key,
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final List<DateTime> weekDates = getDatesForWeek(selectedDate);

    return Container(
      height: 90,
      //margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final date = weekDates[index];
          final isSelected =
              date.year == selectedDate.year &&
              date.month == selectedDate.month &&
              date.day == selectedDate.day;

          return DateTimelineCard(
            weekday: getWeekDayName(date.weekday),
            day: "${date.day}",
            isSelected: isSelected,
            onTap: () => onDaySelected(date),
          );
        },
      ),
    );
  }
}
