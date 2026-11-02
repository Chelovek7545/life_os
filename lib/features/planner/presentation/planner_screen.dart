import 'dart:async';
import 'package:flutter/material.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/tasks/presentation/components/task_calendar.dart';
import 'planner_sidebar.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({
    super.key,
    required this.tasks,
    required this.habits,
    required this.onOpenTask,
    required this.isActive,
  });
  final TasksViewModel tasks;
  final HabitsViewModel habits;
  final ValueChanged<Task> onOpenTask;
  final bool Function() isActive;
  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  late final _tasks = widget.tasks.watchAllTasks();
  late final _projects = widget.tasks.watchProjects();
  late final Timer _clock;
  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!widget.isActive()) return;
      final now = DateTime.now();
      if (!DateUtils.isSameDay(widget.habits.selectedDate, now)) {
        widget.habits.selectDate(now);
      }
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Widget _sidebar({ValueChanged<Task>? onOpenTask}) =>
      StreamBuilder<List<Task>>(
        stream: _tasks,
        builder: (context, tasks) => StreamBuilder<List<Project>>(
          stream: _projects,
          builder: (context, projects) {
            if (tasks.hasError || projects.hasError) {
              return const Center(child: Text('Не удалось загрузить проекты'));
            }
            if (!tasks.hasData || !projects.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return PlannerSidebar(
              tasks: tasks.data!,
              projects: projects.data!,
              habits: widget.habits,
              isActive: widget.isActive,
              onOpenTask: onOpenTask ?? widget.onOpenTask,
            );
          },
        ),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 1050;
      return Padding(
        padding: EdgeInsets.all(wide ? 20 : 8),
        child: Row(
          children: [
            if (wide) ...[
              SizedBox(width: 280, child: _sidebar()),
              const SizedBox(width: 28),
            ],
            Expanded(
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  border: Border.all(color: AppColors.borderGlass),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    if (!wide)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(
                            Icons.account_tree_outlined,
                            size: 18,
                          ),
                          label: const Text('Проекты и привычки'),
                          onPressed: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (sheetContext) => SafeArea(
                              child: SizedBox(
                                height: MediaQuery.sizeOf(context).height * .8,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: _sidebar(
                                    onOpenTask: (task) {
                                      Navigator.of(sheetContext).pop();
                                      widget.onOpenTask(task);
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: TaskCalendar(
                        viewModel: widget.tasks,
                        onOpenTask: widget.onOpenTask,
                        isWeek: true,
                        topPadding: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
