import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:projects_api/projects_api.dart';
import 'package:life_os/features/tasks/presentation/components/task_hierarchy.dart';

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
          builder: (context, constraints) => TaskHierarchy(
            tasks: tasks.data!,
            projects: projects.data!,
            height: constraints.maxHeight,
            onOpenTask: widget.onOpenTask,
            onMoveUnder: widget.model.moveTaskUnder,
            isActive: widget.isActive,
          ),
        );
      },
    ),
  );
}
