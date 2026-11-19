import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/hierarchy/build_hierarchy_tree.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/core/ui/task_drag.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';

class TaskHierarchy extends StatelessWidget {
  const TaskHierarchy({
    super.key,
    required this.tasks,
    required this.projects,
    required this.height,
    required this.onMoveUnder,
    this.onOpenTask,
    this.isActive,
    this.hideCompleted = false,
  });

  final List<Task> tasks;
  final List<Project> projects;
  final double height;
  final Future<void> Function(String id, String parentId) onMoveUnder;
  final ValueChanged<Task>? onOpenTask;
  final bool Function()? isActive;
  final bool hideCompleted;

  bool get _active => isActive?.call() ?? true;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final task in tasks) task.id: task};
    bool canMove(Task source, Task parent) {
      if (!_active || (byId[source.id] ?? source).parentTaskId == parent.id) {
        return false;
      }
      final visited = {source.id};
      Task? ancestor = parent;
      while (ancestor != null) {
        if (!visited.add(ancestor.id)) return false;
        final next = ancestor.parentTaskId;
        ancestor = next == null ? null : byId[next];
        if (next != null && ancestor == null) return false;
      }
      return true;
    }

    return HierarchyColumn(
      height: height,
      nodes: buildHierarchyTree(
        projects,
        hideCompleted
            ? tasks.where((task) => !task.isCompleted).toList()
            : tasks,
      ),
      onNodeTap: onOpenTask == null
          ? null
          : (node) {
              if (node.data case final Task task when _active) {
                onOpenTask!(task);
              }
            },
      draggableBuilder: (node, child) {
        if (node.data is! Task) return child;
        final parent = node.data as Task;
        return DragTarget<TaskDrag>(
          onWillAcceptWithDetails: (details) =>
              canMove(details.data.task, parent),
          onAcceptWithDetails: (details) async {
            final source = details.data.task;
            if (!canMove(source, parent)) return;
            try {
              await onMoveUnder(source.id, parent.id);
            } catch (_) {
              if (context.mounted && _active) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Не удалось изменить родителя задачи'),
                  ),
                );
              }
            }
          },
          builder: (context, candidates, _) => DecoratedBox(
            decoration: BoxDecoration(
              color: candidates.isEmpty
                  ? null
                  : taskDropFill(Colors.transparent),
              border: candidates.isEmpty
                  ? null
                  : Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TaskDraggable(task: parent, enabled: _active, child: child),
          ),
        );
      },
    );
  }
}
