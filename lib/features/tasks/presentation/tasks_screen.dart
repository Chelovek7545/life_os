import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/empty_placeholder.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
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
  bool _shouldRenderForm = false;

  @override
  void dispose() {
    widget.viewModel.dispose();    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: widget.viewModel.isFormVisible,
      initialData: false,
      builder: (context, snap) {
        final isFormVisible = snap.data ?? false;

        if (isFormVisible) {
          _shouldRenderForm = true;
        }

        return Scaffold(
          //appBar: AppBar(title: const Text('Tasks')),
          floatingActionButton: FloatingActionButton(
            onPressed: () => isFormVisible
                ? widget.viewModel.hideForm()
                : widget.viewModel.showForm(),
            tooltip: 'Новая задача',
            child: Icon(isFormVisible ? Icons.close : Icons.add),
          ),
          backgroundColor: AppColors.surfaceGlass,
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    _buildHeader(),
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

                              child: 
                                SegmentedPillControl(
                                  tabs: ["Day", "Week", "Month"],
                                  onTabChanged: (index) {
                                    widget.viewModel.updateFilter(
                                      (old) => old.copyWith(
                                        period: DatePeriod.values[index],
                                      ),
                                    );
                                  },
                                ),
                                
                              
                            ),
                            if (currentFilter.period == DatePeriod.day)
                              CalendarRow(
                                selectedDate: anchorDate,
                                onDaySelected: (date) {
                                  widget.viewModel.updateFilter(
                                    (old) => old.copyWith(anchorDate: date),
                                  );
                                },
                              ),
                          ],
                        );
                      },
                    ),

                    Expanded(
                      child: StreamBuilder<TaskScreenState>(
                        stream: widget.viewModel.state,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          }
                          return snapshot.data!.when(
                            loading: () =>
                                Center(child: CircularProgressIndicator()),
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

                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  return TaskCard(
                                    tags: item.task.tags,
                                    title: item.task.title,
                                    dueDate: item.task.dueDate,
                                    isCompleted: item.task.isCompleted,
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
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                left: 0,
                right: 0,
                bottom: isFormVisible ? 0 : -_kFormExpandedHeight,
                height: _kFormExpandedHeight,
                onEnd: () {
                  if (!isFormVisible) {
                    setState(() {
                      _shouldRenderForm = false;
                    });
                  }
                },
                child: _shouldRenderForm
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
            ],
          ),
        );
      },
    );
  }
}

Widget _buildHeader() {
  return Row(
    children: [
      const Icon(Icons.dashboard_outlined, color: Colors.white),
      const SizedBox(width: 8),
      const Text(
        'Главная',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
      const Spacer(),
      IconButton(
        onPressed: () {},
        icon: const Icon(Icons.settings_outlined, color: Colors.white),
      ),
    ],
  );
}

Widget _segmentButton({
  required String text,
  required bool selected,
  required GestureTapCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF2A2E39) : const Color(0xFF1C2028),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: selected ? Colors.white : Colors.white70,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
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
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.separated(
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

class _TaskTile extends StatelessWidget {
  final String title;
  final String time;
  final bool completed;
  final String? tag;
  final Color? tagColor;

  final VoidCallback? onLongPress;

  final VoidCallback? onPressed;

  const _TaskTile({
    required this.title,
    required this.time,
    this.completed = false,
    this.tag,
    this.tagColor,
    required VoidCallback this.onPressed,
    required VoidCallback this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F27),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: completed
                ? Icon(Icons.check_circle_outline)
                : Icon(Icons.radio_button_unchecked),
            color: completed ? Colors.greenAccent : Colors.white38,
            onPressed: onPressed,
            onLongPress: onLongPress,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: completed ? Colors.white38 : Colors.white,
                    fontSize: 18,
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor ?? Colors.grey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag!,
                      style: const TextStyle(color: Colors.black, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
