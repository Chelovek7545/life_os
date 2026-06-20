import 'dart:async';
import 'package:life_os/core/utils/datetime_utils.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:rxdart/rxdart.dart';

// Нам нужен этот enum для переключения видов (день/неделя/месяц)
//enum TaskFilterView { day, week, month }

// sealed class TaskFilter {
//   const TaskFilter();

//   const factory TaskFilter.day(DateTime date) = TaskDayFilter;
//   const factory TaskFilter.week(DateTime anchorDate) = TaskWeekFilter;
//   const factory TaskFilter.month(DateTime anchorDate) = TaskMonthFilter;
// }

// // Переносим конкретную дату внутри объекта дня
// class TaskDayFilter extends TaskFilter {
//   final DateTime date;
//   const TaskDayFilter(this.date);
// }

// // Переносим дату, которая находится внутри нужной недели
// class TaskWeekFilter extends TaskFilter {
//   final DateTime anchorDate;
//   const TaskWeekFilter(this.anchorDate);
// }

// class TaskMonthFilter extends TaskFilter {
//   final DateTime anchorDate;
//   const TaskMonthFilter(this.anchorDate);
// }

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
  Task draftTask = Task.blank();

  void showForm() {
    _isFormVisibleController.add(true);
  }

  void hideForm() {
    _isFormVisibleController.add(false);
    activeTaskWithProject = null;
    draftTask = Task.blank();
  }

  void toggleForm() {
    shouldRenderForm = !shouldRenderForm;
  }

  bool shouldRenderForm = true;

  //Для формы редактирования задач

  // 3. Текущий фильтр отображения (день/неделя/месяц)
  final BehaviorSubject<TaskFilterConfig> _filterController =
      BehaviorSubject<TaskFilterConfig>.seeded(
        TaskFilterConfig(anchorDate: DateTime.now()),
      );
  Stream<TaskFilterConfig> get currentFilter => _filterController.stream;

  StreamSubscription<dynamic>? _combineSubscription;

  // 4. Выбранные задачи
  final List<Task> selectedTasks = [];

  // Метод для UI: обновить только часть фильтра
  void updateFilter(
    TaskFilterConfig Function(TaskFilterConfig oldConfig) updater,
  ) {
    _filterController.add(updater(_filterController.value));
  }

  void resetFilters() {
    updateFilter((old) => TaskFilterConfig(anchorDate: old.anchorDate));
  }

  void initialize() {
    // Используем Rx.combineLatest2, чтобы пересчитывать отфильтрованный список задач
    // каждый раз, когда меняются либо данные в БД, либо пользователь переключает вкладку (день/неделя/месяц)
    _combineSubscription =
        Rx.combineLatest2<List<TaskWithProject>, TaskFilterConfig, void>(
          _taskWithProjectUseCase
              .call(), // Слушаем Use Case со склеенными проектами
          _filterController.stream, // Слушаем изменения фильтра
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
  void _handleDataUpdate(List<TaskWithProject> tasks, TaskFilterConfig filter) {
    if (tasks.isEmpty) {
      _uiStateController.add(TasksEmpty());
      return;
    }

    // Фильтруем задачи в зависимости от выбранного режима
    final filteredTasks = tasks.where((item) {
      final task = item.task;

      // 1. Фильтр по ДАТЕ и ПЕРИОДУ
      if (task.dueDate != null) {
        final taskDay = task.dueDate!.startOfDay;
        final anchorDay = filter.anchorDate.startOfDay;

        final bool dateMatches = switch (filter.period) {
          DatePeriod.day => taskDay.isAtSameMomentAs(anchorDay),
          DatePeriod.week => isDateInSameWeek(taskDay, anchorDay),
          DatePeriod.month =>
            task.dueDate!.year == filter.anchorDate.year &&
                task.dueDate!.month == filter.anchorDate.month,
          DatePeriod.year => task.dueDate!.year == filter.anchorDate.year,
        };

        if (!dateMatches) return false;
      } else {
        // Если у задачи нет даты, а у нас выбран жесткий период — скрываем её (или оставляем, на ваш выбор)
        return false;
      }

      // 2. Фильтр по ПРОЕКТАМ (Если список не пустой, проверяем совпадение)
      if (filter.projectIds.isNotEmpty &&
          !filter.projectIds.contains(task.projectId)) {
        return false;
      }

      // 3. Фильтр по ТЕГАМ
      if (filter.tagIds.isNotEmpty) {
        // Проверяем, есть ли у задачи хотя бы один из выбранных тегов
        final hasSelectedTag = task.tags.any(
          (tag) => filter.tagIds.contains(tag.id),
        );
        if (!hasSelectedTag) return false;
      }

      // 4. Фильтр по СТАТУСУ ВЫПОЛНЕНИЯ
      if (filter.showCompleted != null &&
          task.isCompleted != filter.showCompleted) {
        return false;
      }

      return true;
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
          selectedTasks: List.from(
            selectedTasks,
          ), // Передаем копию списка, чтобы Flutter зафиксировал изменения
        ),
      );
    }
  }


  // ---UI ЛОГИКА ---
  void startEditingTask(TaskWithProject item){
    activeTaskWithProject = item;
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
    _filterController.close();
  }
}
