import 'package:rxdart/rxdart.dart';

import 'package:life_os/features/tasks/domain/task_model.dart';

class TasksDao {
  static final List<Task> tasks = [
    Task(
      id: "0",
      title: "new",
      description: "",
      status: TaskStatus.inProgress,
      isCompleted: false,
      createdAt: DateTime.now(),
      timerSeconds: 0,
      effortWeight: 0,
    ),
  ];
  final BehaviorSubject<List<Task>> _tasksController =
      BehaviorSubject<List<Task>>.seeded(List.unmodifiable(tasks));

  Future<List<Task>> getAllTasks() async {
    return List.unmodifiable(tasks);
  }

  Future<Task?> getById(String id) async {
    for (final task in tasks) {
      if (task.id == id) {
        return task;
      }
    }
    return null;
  }

  Future<void> insert(Task task) async {
    tasks.add(task);
    _tasksController.add(List.unmodifiable(tasks));
  }

  Future<void> update(Task task) async {
    final index = tasks.indexWhere((Task t) => t.id == task.id);
    if (index != -1) {
      tasks[index] = task;
      _tasksController.add(List.unmodifiable(tasks));
    }
  }

  Future<void> delete(String id) async {
    tasks.removeWhere((Task task) => task.id == id);
    _tasksController.add(List.unmodifiable(tasks));
  }

  Stream<List<Task>> watchAll() => _tasksController.stream;

  Stream<Task?> watchTask(String id) {
    return _tasksController.stream.map((List<Task> updatedTasks) {
      for (final task in updatedTasks) {
        if (task.id == id) {
          return task;
        }
      }
      return null;
    });
  }

  void dispose() {
    _tasksController.close();
  }
}
