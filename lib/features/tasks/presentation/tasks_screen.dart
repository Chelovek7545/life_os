import 'package:flutter/material.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/day_calendar.dart';
import 'package:life_os/features/tasks/presentation/components/task_card.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

const double _kFormExpandedHeight = 1000.0;

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.viewModel});
  final TasksViewModel viewModel;

  // int dayIndex = 0;

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF12141A);
    return StreamBuilder<bool>(
      stream: viewModel.isFormVisible,
      initialData: false,
      builder: (context, snap) {
        final isFormVisible = snap.data ?? false;

        return Scaffold(
          //appBar: AppBar(title: const Text('Tasks')),
          floatingActionButton: FloatingActionButton(
            onPressed: () =>
                isFormVisible ? viewModel.hideForm() : viewModel.showForm(),
            tooltip: 'Новая задача',
            child: Icon(isFormVisible ? Icons.close : Icons.add),
          ),
          backgroundColor: bgColor,
          body: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    _buildHeader(),
                    StreamBuilder(
                      stream: viewModel.currentFilter,
                      builder: (_, snapshot) {
                        final currentFilter =
                            snapshot.data ?? TaskFilterConfig(anchorDate: DateTime.now());

                        // Извлекаем "опорную" дату из текущего фильтра для сохранения контекста
                        final DateTime anchorDate = currentFilter.anchorDate;

                        return Column(
                          children: [
                            Row(
                              children: [
                                _segmentButton(
                                  text: "Day",
                                  selected: currentFilter.period == DatePeriod.day,
                                  onTap: () => viewModel.updateFilter(
                                    (old) => old.copyWith(period: DatePeriod.day),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _segmentButton(
                                  text: "Week",
                                  selected: currentFilter.period == DatePeriod.week,
                                  onTap: () => viewModel.updateFilter(
                                    (old) => old.copyWith(period: DatePeriod.week),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _segmentButton(
                                  text: "Month",
                                  selected: currentFilter.period == DatePeriod.month,
                                  onTap: () => viewModel.updateFilter(
                                    (old) => old.copyWith(period: DatePeriod.month),
                                  ),
                                ),
                                const Spacer(),
                                const Icon(
                                  Icons.calendar_month_outlined,
                                  color: Colors.white,
                                ),
                              ],
                            ),
                            if(currentFilter.period == DatePeriod.day)
                            CalendarRow(
                              selectedDate: anchorDate,
                              onDaySelected: (date) {
                                viewModel.updateFilter(
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
                        stream: viewModel.state,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return CircularProgressIndicator();
                          }
                          return snapshot.data!.when(
                            loading: () =>
                                Center(child: CircularProgressIndicator()),
                            empty: (_, _) => Text("empty"),
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
                                    completed: item.task.isCompleted,
                                    onCheckChanged: () async {
                                      await viewModel.toggleTask(item.task);
                                    },
                                    onLongPress: () {
                                      viewModel.startEditingTask(item);
                                      viewModel.showForm();
                                    },
                                    projectTitle: item.project?.name,
                                    isSelected: selectedTasks.any(
                                      (t) => t.id == item.task.id,
                                    ),
                                    onSelected: () => viewModel
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
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                bottom: isFormVisible ? 0 : -_kFormExpandedHeight,
                height: isFormVisible ? _kFormExpandedHeight : 0,
                child: isFormVisible
                    ? CollapsibleTaskForm(
                      height: MediaQuery.sizeOf(context).height * 0.8,
                        task: viewModel.activeTaskWithProject?.task,
                        projects: viewModel.watchProjects(),
                        isEditMode: viewModel.activeTaskWithProject != null,
                        onSubmit: (Task task) {
                          if (viewModel.activeTaskWithProject != null) {
                            print("update");
                            viewModel.updateTask(task);
                          } else {
                            viewModel.addTask(task);
                          }
                          viewModel.hideForm();
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
      height: 88,
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
