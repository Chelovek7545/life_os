import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:projects_api/projects_api.dart';
import 'package:life_os/core/ui/hierarchy/build_hierarchy_tree.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';

class WorkspaceHierarchy extends StatefulWidget {
  const WorkspaceHierarchy({
    super.key,
    required this.model,
    required this.onOpenTask,
    required this.isActive,
  });
  final TasksViewModel model;
  final ValueChanged<Task> onOpenTask;
  final bool Function() isActive;
  @override
  State<WorkspaceHierarchy> createState() => _WorkspaceHierarchyState();
}

class _WorkspaceHierarchyState extends State<WorkspaceHierarchy> {
  late final _tasks = widget.model.watchAllTasks();
  late final _projects = widget.model.watchProjects();
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Task>>(
    stream: _tasks,
    builder: (context, tasks) => StreamBuilder<List<Project>>(
      stream: _projects,
      builder: (context, projects) {
        if (tasks.hasError || projects.hasError) {
          return const Center(child: Text('Не удалось загрузить иерархию'));
        }
        if (!tasks.hasData || !projects.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return LayoutBuilder(
          builder: (context, constraints) => HierarchyColumn(
            nodes: buildHierarchyTree(projects.data!, tasks.data!),
            height: constraints.maxHeight,
            onNodeTap: (node) {
              if (widget.isActive() && node.data is Task) {
                widget.onOpenTask(node.data as Task);
              }
            },
            draggableBuilder: (node, child) {
              final task = node.data;
              if (task is! Task) return child;
              return LongPressDraggable<Task>(
                data: task,
                maxSimultaneousDrags: widget.isActive() ? 1 : 0,
                feedback: Material(
                  child: SizedBox(
                    width: 220,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(task.title),
                    ),
                  ),
                ),
                childWhenDragging: Opacity(opacity: .35, child: child),
                child: child,
              );
            },
          ),
        );
      },
    ),
  );
}
