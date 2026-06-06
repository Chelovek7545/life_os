import 'package:flutter/material.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/features/tasks/presentation/components/task_card.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:life_os/features/tasks/presentation/tasks_view_model.dart';

const double _kFormExpandedHeight = 350.0;

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key, required this.viewModel});
  final TasksViewModel viewModel;

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
                    Row(
                      children: [
                        _segmentButton("День", true),
                        const SizedBox(width: 8),
                        _segmentButton("Неделя", false),
                        const SizedBox(width: 8),
                        _segmentButton("Месяц", false),
                        const Spacer(),
                        const Icon(
                          Icons.calendar_month_outlined,
                          color: Colors.white,
                        ),
                      ],
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
                            empty: (_, __) => Text("empty"),
                            error: (e) => Text(e),
                            loaded: (tasks, _, curTask) {
                              if (tasks.isEmpty) {
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
                                itemCount: tasks.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final task = tasks[index];
                                  return TaskCard(
                                    tags: task.tags,
                                    title: task.title,
                                    dueDate: DateTime.now(),
                                    completed: task.isCompleted,
                                    onCheckChanged: () async {
                                      await viewModel.toggleTask(task);
                                    },
                                    onSelected: () {},
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
                        onSubmit: (Task task) {
                          viewModel.addTask(
                            task.copyWith(
                              tags: [
                                Tag(id: 1, name: 'name', colorHex: 123123),
                              ],
                            ),
                          );
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

Widget _segmentButton(String text, bool selected) {
  return Container(
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
  );
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
