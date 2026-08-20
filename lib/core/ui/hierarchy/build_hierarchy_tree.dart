  import 'package:flutter/material.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

/// Построение дерева иерархии любой глубины
  List<HierarchyNode> buildHierarchyTree(
    List<Project> projects,
    List<Task> tasks,
  ) {
    // 1. Индексация проектов по parentProejectId
    final subProjectsMap = <String, List<Project>>{};
    final rootProjects = <Project>[];

    for (final project in projects) {
      if (project.isArchived) continue;

      if (project.parentProejectId == null) {
        rootProjects.add(project);
      } else {
        subProjectsMap
            .putIfAbsent(project.parentProejectId!, () => [])
            .add(project);
      }
    }

    // 2. Индексация задач по projectId и parentTaskId
    final projectTasksMap = <String, List<Task>>{};
    final subtasksMap = <String, List<Task>>{};

    for (final task in tasks) {
      if (task.parentTaskId != null) {
        subtasksMap.putIfAbsent(task.parentTaskId!, () => []).add(task);
      } else if (task.projectId != null) {
        projectTasksMap.putIfAbsent(task.projectId!, () => []).add(task);
      }
    }

    // 3. Рекурсивная сборка корреневых проектов
    return rootProjects
        .map(
          (project) => _buildProjectNode(
            project: project,
            subProjectsMap: subProjectsMap,
            projectTasksMap: projectTasksMap,
            subtasksMap: subtasksMap,
          ),
        )
        .toList();
  }

  /// Рекурсивная сборка узла проекта (любая глубина вложенности подпроектов)
  HierarchyNode _buildProjectNode({
    required Project project,
    required Map<String, List<Project>> subProjectsMap,
    required Map<String, List<Task>> projectTasksMap,
    required Map<String, List<Task>> subtasksMap,
  }) {
    final subProjects = subProjectsMap[project.id] ?? const [];
    final projectTasks = projectTasksMap[project.id] ?? const [];

    return HierarchyNode(
      id: project.id,
      title: project.name,
      type: NodeType.project,
      icon: Icons.folder,
      data: project,
      dotColor: parseHexColor(project.color),
      isExpanded: true,
      children: [
        // Рекурсивно собираем подпроекты
        for (final subProject in subProjects)
          _buildProjectNode(
            project: subProject,
            subProjectsMap: subProjectsMap,
            projectTasksMap: projectTasksMap,
            subtasksMap: subtasksMap,
          ),
        // Добавляем прямые задачи проекта
        for (final task in projectTasks)
          _buildTaskNode(
            task: task,
            subtasksMap: subtasksMap,
            isSubtask: false,
          ),
      ],
    );
  }

  /// Рекурсивная сборка узла задачи (любая глубина вложенности подзадач)
  HierarchyNode _buildTaskNode({
    required Task task,
    required Map<String, List<Task>> subtasksMap,
    required bool isSubtask,
  }) {
    final childSubtasks = subtasksMap[task.id] ?? const [];

    return HierarchyNode(
      id: task.id,
      title: task.title,
      data: task,
      type: isSubtask ? NodeType.subtask : NodeType.task,
      dotColor: isSubtask ? task.status.color : null,
      children: [
        // Рекурсивно собираем подзадачи
        for (final subtask in childSubtasks)
          _buildTaskNode(
            task: subtask,
            subtasksMap: subtasksMap,
            isSubtask: true,
          ),
      ],
    );
  }

