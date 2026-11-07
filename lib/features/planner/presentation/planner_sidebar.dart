import 'package:flutter/material.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/core/ui/hierarchy/build_hierarchy_tree.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/core/theme/app_colors.dart';

class PlannerSidebar extends StatefulWidget {
  const PlannerSidebar({
    super.key,
    required this.tasks,
    required this.projects,
    required this.habits,
    required this.onOpenTask,
    required this.isActive,
  });
  final List<Task> tasks;
  final List<Project> projects;
  final HabitsViewModel habits;
  final ValueChanged<Task> onOpenTask;
  final bool Function() isActive;
  @override
  State<PlannerSidebar> createState() => _PlannerSidebarState();
}

class _PlannerSidebarState extends State<PlannerSidebar> {
  final _pending = <String>{};
  bool _hideCompleted = false;

  Future<void> _toggle(HabitWithEntry item) async {
    if (!widget.isActive() || !_pending.add(item.habit.id)) return;
    setState(() {});
    try {
      await widget.habits.toggleHabit(item.habit, widget.habits.selectedDate);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить отметку привычки'),
          ),
        );
      }
    } finally {
      _pending.remove(item.habit.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: _surface(
          title: 'Иерархия',
          icon: Icons.account_tree_outlined,
          action: IconButton(
            tooltip: _hideCompleted
                ? 'Показать завершённые задачи'
                : 'Скрыть завершённые задачи',
            isSelected: _hideCompleted,
            onPressed: () => setState(() => _hideCompleted = !_hideCompleted),
            icon: const Icon(Icons.filter_list, size: 20),
          ),
          child: _tree(),
        ),
      ),
      const SizedBox(height: 22),
      Expanded(
        child: _surface(
          title: 'Ежедневные\nпривычки',
          icon: Icons.autorenew,
          action: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: .2),
              ),
            ),
            child: const Text(
              'Сегодня',
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 10,
                color: AppColors.primary,
              ),
            ),
          ),
          child: StreamBuilder<HabitsScreenState>(
            stream: widget.habits.state,
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (state is HabitsError) {
                return const Text('Не удалось загрузить привычки');
              }
              if (state is! HabitsLoaded) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = state.habits
                  .where((item) => item.isScheduled && !item.isExpired)
                  .toList();
              if (items.isEmpty) {
                return const Text(
                  'На сегодня привычек нет',
                  style: TextStyle(color: AppColors.onSurfaceVariant),
                );
              }
              return ListView.separated(
                primary: false,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final color = item.isCompleted
                      ? const Color(0xFF00BF91)
                      : AppColors.primary;
                  return Material(
                    color: item.isCompleted
                        ? color.withValues(alpha: .04)
                        : AppColors.surfaceBright,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                      side: BorderSide(color: AppColors.borderGlass),
                    ),
                    child: InkWell(
                      key: ValueKey('planner-habit-${item.habit.id}'),
                      borderRadius: BorderRadius.circular(17),
                      onTap: _pending.contains(item.habit.id)
                          ? null
                          : () => _toggle(item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              item.isCompleted
                                  ? Icons.check_circle_outline
                                  : Icons.radio_button_unchecked,
                              color: color,
                              size: 25,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.habit.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      decoration: item.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: item.isCompleted
                                          ? AppColors.onSurfaceVariant
                                          : AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.isCompleted
                                        ? 'Выполнено'
                                        : item.isSkipped
                                        ? 'Пропущено'
                                        : 'Ожидает',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (item.streak.current > 0)
                              Text(
                                '${item.streak.current} д',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ],
  );

  Widget _tree() => LayoutBuilder(
    builder: (context, constraints) => HierarchyColumn(
      height: constraints.maxHeight,
      nodes: buildHierarchyTree(
        widget.projects,
        widget.tasks
            .where((task) => !_hideCompleted || !task.isCompleted)
            .toList(),
      ),
      onNodeTap: (node) {
        if (node.data case final Task task) widget.onOpenTask(task);
      },
      draggableBuilder: (node, child) {
        final task = node.data;
        if (task is! Task) return child;
        return LongPressDraggable<Task>(
          data: task,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          maxSimultaneousDrags: widget.isActive() ? 1 : 0,
          feedback: Material(
            color: AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 220,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(opacity: .35, child: child),
          child: child,
        );
      },
    ),
  );
  Widget _surface({
    required String title,
    required IconData icon,
    required Widget action,
    required Widget child,
  }) => Material(
    color: AppColors.surfaceContainer,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: AppColors.borderGlass),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              action,
            ],
          ),
          const SizedBox(height: 20),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
