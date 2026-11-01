import 'package:collection/collection.dart';
import 'package:rxdart/rxdart.dart';
import 'package:life_os/features/spheres/data/spheres_repository.dart';
import 'package:life_os/features/spheres/domain/sphere_model.dart';
import 'package:life_os/features/goals/data/goals_repository.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';
import 'package:life_os/features/projects/domain/projects_api.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:tasks_api/tasks_api.dart' show TasksApi;
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/lifegraph/domain/graph_node.dart';

/// Строит список доменных нод для заданной сферы, объединяя стримы
/// из репозиториев. Рёбра и позиции сюда не входят — их выводит [GraphView].
class GraphBuilder {
  GraphBuilder({
    required this.spheresRepository,
    required this.goalsRepository,
    required this.projectsRepository,
    required this.tasksRepository,
  });

  final SpheresRepository spheresRepository;
  final GoalsRepository goalsRepository;
  final ProjectsApi projectsRepository;
  final TasksApi tasksRepository;

  /// Возвращает стрим полного списка нод (сфера — корень) для сферы.
  Stream<List<GraphNode>> watchGraph(String sphereId) {
    return Rx.combineLatest4<
      Sphere?,
      List<Goal>,
      List<Project>,
      List<Task>,
      List<GraphNode>
    >(
      spheresRepository.watchAllSpheres().map(
        (list) => list.firstWhereOrNull((s) => s.id == sphereId),
      ),
      goalsRepository.watchGoalsBySphere(sphereId),
      projectsRepository.watchAllProjects(),
      tasksRepository.watchTasks(),
      (sphere, goals, allProjects, allTasks) {
        if (sphere == null) return <GraphNode>[];
        // Фильтруем проекты и задачи, принадлежащие этому поддереву.
        final goalIds = goals.map((g) => g.id).toSet();
        final projects = allProjects.where((p) {
          //print(p);
          return p.goalId != null && goalIds.contains(p.goalId);
        }).toList();
        final included = projects.map((p) => p.id).toSet();
        var changed = true;
        while (changed) {
          changed = false;
          for (final project in allProjects) {
            if (included.contains(project.parentProejectId) &&
                included.add(project.id)) {
              projects.add(project);
              changed = true;
            }
          }
        }
        final projectIds = projects.map((p) => p.id).toSet();

        final tasks = allTasks
            .where(
              (t) =>
                  t.parentTaskId == null &&
                  t.projectId != null &&
                  projectIds.contains(t.projectId),
            )
            .toList();
        final subTasks = allTasks
            .where(
              (t) =>
                  t.parentTaskId != null &&
                  tasks.firstWhereOrNull(
                        (element) => element.id == t.parentTaskId,
                      ) !=
                      null,
            )
            .toList();

        final nodes = <GraphNode>[
          // Сфера (корень)
          GraphNode(
            id: sphere.id,
            type: GraphNodeType.sphere,
            title: sphere.name,
            subtitle: '',
            color: sphere.color,
            parentId: null,
          ),
        ];

        // Цели
        for (final goal in goals) {
          nodes.add(
            GraphNode(
              id: goal.id,
              type: GraphNodeType.goal,
              title: goal.name,
              subtitle: goal.description,
              color: goal.color,
              parentId: sphere.id,
            ),
          );
        }

        // Проекты
        for (final project in projects) {
          nodes.add(
            GraphNode(
              id: project.id,
              type: GraphNodeType.project,
              title: project.name,
              subtitle: project.description,
              color: project.color,
              parentId: project.parentProejectId ?? project.goalId,
            ),
          );
          //print(project.parentProejectId);
        }

        // Задачи
        for (final task in tasks) {
          nodes.add(
            GraphNode(
              id: task.id,
              type: GraphNodeType.task,
              title: task.title,
              subtitle: task.description.isEmpty
                  ? 'Нет описания'
                  : task.description,
              color: projects.firstWhere((v) => v.id == task.projectId).color,
              parentId: task.parentTaskId ?? task.projectId,
              taskStatus: task.status,
            ),
          );
        }

        for (final task in subTasks) {
          nodes.add(
            GraphNode(
              id: task.id,
              type: GraphNodeType.subTask,
              title: task.title,
              subtitle: task.description.isEmpty
                  ? 'Нет описания'
                  : task.description,
              color: '#CCC2DC',
              parentId: task.parentTaskId,
              taskStatus: task.status,
            ),
          );
        }

        return nodes;
      },
    );
  }
}
