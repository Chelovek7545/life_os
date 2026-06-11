import 'dart:async';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:rxdart/rxdart.dart';

// Нам нужен этот enum для переключения видов (день/неделя/месяц)
enum TaskFilterView { day, week, month }

class TasksViewModel {
  final TasksRepository _repository;
  final GetTasksWithProjectsUseCase _taskWithProjectUseCase;
  final ProjectsRepository _projectsRepository;

  TasksViewModel(
    this._repository,
    this._taskWithProjectUseCase,
    this._projectsRepository,
  );

  // 1. Стримы состояния экрана (Задачи + Проекты)
  final BehaviorSubject<TaskScreenState> _uiStateController =
      BehaviorSubject<TaskScreenState>.seeded(const TasksLoading());
  Stream<TaskScreenState> get state => _uiStateController.stream;

  // 2. Видимость нижней формы создания задачи
  final BehaviorSubject<bool> _isFormVisibleController =
      BehaviorSubject<bool>.seeded(false);
  Stream<bool> get isFormVisible => _isFormVisibleController.stream;

  TaskWithProject? activeTaskWithProject;

  void showForm() => _isFormVisibleController.add(true);
  void hideForm() {
    _isFormVisibleController.add(false);
    activeTaskWithProject = null;
  }

  //Для формы редактирования задач

  // 3. Текущий фильтр отображения (день/неделя/месяц)
  final BehaviorSubject<TaskFilterView> _currentViewController =
      BehaviorSubject<TaskFilterView>.seeded(TaskFilterView.day);
  Stream<TaskFilterView> get currentView => _currentViewController.stream;

  StreamSubscription<dynamic>? _combineSubscription;


  // 4. Выбранные задачи
  final List<Task> selectedTasks = [];
  
  
  
  void initialize() {
    // Используем Rx.combineLatest2, чтобы пересчитывать отфильтрованный список задач
    // каждый раз, когда меняются либо данные в БД, либо пользователь переключает вкладку (день/неделя/месяц)
    _combineSubscription =
        Rx.combineLatest2<List<TaskWithProject>, TaskFilterView, void>(
          _taskWithProjectUseCase
              .call(), // Слушаем Use Case со склеенными проектами
          _currentViewController.stream,
          (tasksWithProjects, currentFilter) {
            _handleDataUpdate(tasksWithProjects, currentFilter);
          },
        ).listen(
          (_) {},
          onError: (Object error) {
            _uiStateController.add(TasksError('Failed to load tasks: $error'));
          },
        );
  }

  // Логика фильтрации и отправки состояния в UI
  void _handleDataUpdate(List<TaskWithProject> tasks, TaskFilterView filter) {
    if (tasks.isEmpty) {
      _uiStateController.add(TasksEmpty());
      return;
    }

    // Фильтруем задачи в зависимости от выбранного режима
    final filteredTasks = tasks.where((item) {
      final now = DateTime.now();
      final taskDate = item.task.dueDate;
      if (taskDate == null) return true; // Если даты нет, показываем везде

      switch (filter) {
        case TaskFilterView.day:
          return taskDate.year == now.year &&
              taskDate.month == now.month &&
              taskDate.day == now.day;
        case TaskFilterView.week:
          final difference = taskDate.difference(now).inDays;
          return difference >= 0 && difference <= 7;
        case TaskFilterView.month:
          return taskDate.year == now.year && taskDate.month == now.month;
      }
    }).toList();

    if (filteredTasks.isEmpty) {
      _uiStateController.add(TasksEmpty());
    } else {
      // Передаем первую актуальную задачу как curTask, и весь отфильтрованный список
      _uiStateController.add(
        TasksLoaded(
          curTask: filteredTasks.first.task,
          tasks:
              filteredTasks, // Важно: TasksLoaded теперь должен принимать List<TaskWithProject>
          selectedTasks: List.from(selectedTasks),
        ),
      );
    }
  }

  void toggleTaskSelection(Task task) {
  // Логика добавления/удаления из списка selectedTasks
  // ...
  
  // Дополнительно: если мы выделили задачу, можно сразу подставить её в форму
  selectedTasks.any((t) => t.id == task.id)
      ? selectedTasks.removeWhere((t) => t.id == task.id)
      : selectedTasks.add(task);

  final currentState = _uiStateController.value;
  
  if (currentState is TasksLoaded) {
    // Если стейт уже загружен, просто проталкиваем в него обновленный selectedTasks.
    // Передаем исходный (неотфильтрованный) список из Use Case здесь не нужно, 
    // мы можем перевыпустить текущие задачи с новым списком выделения.
    _uiStateController.add(
      TasksLoaded(
        curTask: currentState.curTask,
        tasks: currentState.tasks, // Оставляем текущие отфильтрованные задачи
        selectedTasks: List.from(selectedTasks), // Передаем копию списка, чтобы Flutter зафиксировал изменения
      ),
    );
  }
  
}

  // Изменение режима отображения (вызывается по нажатию на табы на экране)
  void changeView(TaskFilterView view) {
    _currentViewController.add(view);
  }

  // --- Бизнес-логика (CUD операции) ---
  // ВАЖНО: Мы убрали ручной вызов _emitUiState() из этих методов.
  // Так как репозиторий реактивный, вызов addTask/deleteTask изменит базу данных,
  // это стриггерит стрим в Use Case, и метод _handleDataUpdate выполнится САМ автоматически.

  Future<Task?> getTask(String id) async => await _repository.getById(id);

  Stream<List<Project>> watchProjects() =>
      _projectsRepository.watchAllProjects();

  Future<void> addTask(Task task) async {
    await _repository.addTask(task.copyWith(createdAt: DateTime.now()));
  }

  Future<void> updateTask(Task task) async {
    await _repository.updateTask(task);
  }

  Future<void> toggleTask(Task task) async {
    final updated = task.copyWith(isCompleted: !task.isCompleted);
    await updateTask(updated);
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
  }

  void dispose() {
    _combineSubscription?.cancel();
    _uiStateController.close();
    _isFormVisibleController.close();
    _currentViewController.close();
  }
}
