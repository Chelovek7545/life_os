import 'package:rxdart/rxdart.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';
import 'package:life_os/features/lifegraph/data/graph_positions_repository.dart';

/// Строит граф для заданной сферы, объединяя стримы из репозиториев.
class GraphBuilder {
  GraphBuilder({
    required this.spheresRepository,
    required this.goalsRepository,
    required this.projectsRepository,
    required this.tasksRepository,
    required this.positionsRepository,
  });

  final SpheresRepository spheresRepository;
  final GoalsRepository goalsRepository;
  final ProjectsRepository projectsRepository;
  final TasksRepository tasksRepository;
  final GraphPositionsRepository positionsRepository;

  /// Возвращает стрим GraphData для указанной сферы.
  Stream<GraphData> watchGraph(String sphereId) {
    return Rx.combineLatest4<
        Sphere,
        List<Goal>,
        List<Project>,
        List<Task>,
        GraphData>(
      spheresRepository.watchAllSpheres().map((list) => list.firstWhere((s) => s.id == sphereId)),
      goalsRepository.watchGoalsBySphere(sphereId),
      projectsRepository.watchAllProjects(),
      tasksRepository.watchTasks(),
      (sphere, goals, allProjects, allTasks) {
        // Фильтруем проекты и задачи, принадлежащие этому поддереву.
        final goalIds = goals.map((g) => g.id).toSet();
        final projects = allProjects.where((p) => p.goalId != null && goalIds.contains(p.goalId)).toList();
        final projectIds = projects.map((p) => p.id).toSet();
        final tasks = allTasks.where((t) => t.projectId != null && projectIds.contains(t.projectId)).toList();

        // Строим ноды синхронно (позиции наложим асинхронно в ViewModel).
        final nodes = <GraphNode>[];
        final edges = <GraphEdge>[];

        // Сфера (корень)
        nodes.add(GraphNode(
          id: sphere.id,
          type: GraphNodeType.sphere,
          title: sphere.name,
          subtitle: '',
          color: sphere.color,
          parentId: null,
          x: 0,
          y: 0,
        ));

        // Цели
        for (final goal in goals) {
          nodes.add(GraphNode(
            id: goal.id,
            type: GraphNodeType.goal,
            title: goal.name,
            subtitle: goal.description,
            color: goal.color,
            parentId: sphere.id,
            x: 0,
            y: 0,
          ));
          edges.add(GraphEdge(fromId: sphere.id, toId: goal.id));
        }

        // Проекты
        for (final project in projects) {
          nodes.add(GraphNode(
            id: project.id,
            type: GraphNodeType.project,
            title: project.name,
            subtitle: project.description,
            color: project.color,
            parentId: project.goalId,
            x: 0,
            y: 0,
          ));
          if (project.goalId != null) {
            edges.add(GraphEdge(fromId: project.goalId!, toId: project.id));
          }
        }

        // Задачи
        for (final task in tasks) {
          nodes.add(GraphNode(
            id: task.id,
            type: GraphNodeType.task,
            title: task.title,
            subtitle: task.description.isEmpty ? 'Нет описания' : task.description,
            color: _taskColor(task.status),
            parentId: task.projectId,
            x: 0,
            y: 0,
            taskStatus: task.status,
          ));
          if (task.projectId != null) {
            edges.add(GraphEdge(fromId: task.projectId!, toId: task.id));
          }
        }

        return GraphData(nodes: nodes, edges: edges);
      },
    );
  }

  String _taskColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.done:
        return '#4CAF50';
      case TaskStatus.inProgress:
        return '#2196F3';
      case TaskStatus.notStarted:
        return '#FF9800';
      case TaskStatus.open:
        return '#9E9E9E';
    }
  }
}
