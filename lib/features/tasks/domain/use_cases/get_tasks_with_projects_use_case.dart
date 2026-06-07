import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:rxdart/rxdart.dart'; // Для объединения стримов
import 'package:collection/collection.dart';

// Специальная UI-модель, которую мы отдадим во ViewModel
class TaskWithProject {
  final Task task;
  final Project? project; // Проекта может и не быть

  TaskWithProject({required this.task, this.project});
}

class GetTasksWithProjectsUseCase {
  final TasksRepository _taskRepository;
  final ProjectsRepository _projectRepository;

  GetTasksWithProjectsUseCase(this._taskRepository, this._projectRepository);

  // Основной метод Use Case. Часто его называют call(), чтобы вызывать класс как функцию
  Stream<List<TaskWithProject>> call() {
    // Объединяем два стрима с помощью RxDart (CombineLatest2)
    return Rx.combineLatest2<List<Task>, List<Project>, List<TaskWithProject>>(
      _taskRepository.watchTasks(),
      _projectRepository.watchAllProjects(),
      (tasks, projects) {
        // Логика склейки: для каждой задачи ищем её проект по ID
        return tasks.map((task) {
          final project = projects.firstWhereOrNull(
            (p) => p.id == task.projectId,);
          return TaskWithProject(task: task, project: project);
        }).toList();
      },
    );
  }
}