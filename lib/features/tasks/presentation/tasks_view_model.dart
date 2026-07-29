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

class TasksUiFlags {
  final bool isFormVisible;
  final bool isEventMode;

  const TasksUiFlags({
    this.isFormVisible = false,
    this.isEventMode = false,
  });

  TasksUiFlags copyWith({
    bool? isFormVisible,
    bool? isEventMode,
  }) {
    return TasksUiFlags(
      isFormVisible: isFormVisible ?? this.isFormVisible,
      isEventMode: isEventMode ?? this.isEventMode,
    );
  }
}

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
  final BehaviorSubject<TasksUiFlags> _uiFlagsController =
      BehaviorSubject<TasksUiFlags>.seeded(TasksUiFlags());
  Stream<TasksUiFlags> get uiFlags => _uiFlagsController.stream;
  TasksUiFlags get currentUiFlags => _uiFlagsController.value;



  TaskWithProject? activeTaskWithProject;
  Task draftTask = Task.blank();
  bool shouldRenderForm = false;

  void showForm() {
    if (_uiFlagsController.isClosed) return;
    shouldRenderForm = true;
    _uiFlagsController.add(currentUiFlags.copyWith(isFormVisible: true));
  }

  void hideForm() {
    if (_uiFlagsController.isClosed) return;
    _uiFlagsController.add(currentUiFlags.copyWith(isFormVisible: false));
    draftTask = Task.blank();
  }

  void disableForm() {
    shouldRenderForm = false;
    activeTaskWithProject = null;
  }

  //Для формы редактирования задач

  // 3. Текущий фильтр отображения (день/неделя/месяц)
  final BehaviorSubject<TaskFilterConfig> _filterController =
      BehaviorSubject<TaskFilterConfig>.seeded(
        TaskFilterConfig(anchorDate: DateTime.now()),
      );
  Stream<TaskFilterConfig> get currentFilter => _filterController.stream;
  TaskFilterConfig get currentFilterValue => _filterController.value;

  StreamSubscription<dynamic>? _combineSubscription;

  // 4. Выбранные задачи
  final List<Task> selectedTasks = [];

  

  // Метод для UI: обновить только часть фильтра
  bool isEventMode = false;
  // Хелперы для управления флагами
  void toggleEventMode() {
    if (_uiFlagsController.isClosed) return;
    _uiFlagsController.add(currentUiFlags.copyWith(isEventMode: !currentUiFlags.isEventMode));
  }
  void updateFilter(
    TaskFilterConfig Function(TaskFilterConfig oldConfig) updater,
  ) {
    if (_filterController.isClosed) return;
    _filterController.add(updater(_filterController.value));
  }

  void resetFilters() {
    updateFilter((old) => TaskFilterConfig(anchorDate: old.anchorDate));
  }

  void initialize() {
    //Отменять существующую подписку перед созданием ново
    _combineSubscription?.cancel();

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
    if (_uiStateController.isClosed) return;
    if (tasks.isEmpty) {
      _uiStateController.add(TasksEmpty());
      return;
    }

    final scheduled = <TaskWithProject>[];
    final unscheduled = <TaskWithProject>[];

    for (final item in tasks) {
      final task = item.task;

      // 1. Фильтр по ДАТЕ и ПЕРИОДУ
      if (task.startsAt != null) {
        final taskDay = DateTime(
          task.startsAt!.year,
          task.startsAt!.month,
          task.startsAt!.day,
        );
        final anchorDay = DateTime(
          filter.anchorDate.year,
          filter.anchorDate.month,
          filter.anchorDate.day,
        );

        final bool dateMatches = switch (filter.period) {
          DatePeriod.day => taskDay.isAtSameMomentAs(anchorDay),
          DatePeriod.week => isDateInSameWeek(taskDay, anchorDay),
          DatePeriod.month =>
            task.startsAt!.year == filter.anchorDate.year &&
                task.startsAt!.month == filter.anchorDate.month,
          DatePeriod.year => task.startsAt!.year == filter.anchorDate.year,
        };

        if (!dateMatches) continue;
      } else {
      }

      // 2. Фильтр по ПРОЕКТАМ (Если список не пустой, проверяем совпадение)
      if (filter.projectIds.isNotEmpty &&
          !filter.projectIds.contains(task.projectId)) {
        continue;
      }

      // 3. Фильтр по ТЕГАМ
      if (filter.tagIds.isNotEmpty) {
        // Проверяем, есть ли у задачи хотя бы один из выбранных тегов
        final hasSelectedTag = task.tags.any(
          (tag) => filter.tagIds.contains(tag.id),
        );
        if (!hasSelectedTag) continue;
      }

      // 4. Фильтр по СТАТУСУ ВЫПОЛНЕНИЯ
      if (filter.showCompleted != null &&
          task.isCompleted != filter.showCompleted) {
        continue;
      }

      if (task.startsAt != null) {
        scheduled.add(item);
      } else {
        unscheduled.add(item);
      }
    }

    if (scheduled.isEmpty && unscheduled.isEmpty && selectedTasks.isEmpty) {
      _uiStateController.add(TasksEmpty());
    } else {
      _uiStateController.add(
        TasksLoaded(
          curTask: scheduled.isNotEmpty ? scheduled.first.task : null,
          tasks: scheduled,
          selectedTasks: List.from(selectedTasks),
          unscheduledTasks: unscheduled,
        ),
      );
    }
  }

  void clearTaskSelection() {
    if (_uiStateController.isClosed) return;
    final currentState = _uiStateController.value;
    selectedTasks.clear();

    if (currentState is TasksLoaded) {
      // Если стейт уже загружен, просто проталкиваем в него обновленный selectedTasks.
      // Передаем исходный (неотфильтрованный) список из Use Case здесь не нужно,
      // мы можем перевыпустить текущие задачи с новым списком выделения.
      _uiStateController.add(
        TasksLoaded(
          curTask: currentState.curTask,
          unscheduledTasks: currentState.unscheduledTasks,
          tasks: currentState.tasks, // Оставляем текущие отфильтрованные задачи
          selectedTasks: [],
        ),
      );
    }
  }

  void toggleTaskSelection(Task task) {
    if (_uiStateController.isClosed) return;
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
          unscheduledTasks: currentState.unscheduledTasks,
          tasks: currentState.tasks, // Оставляем текущие отфильтрованные задачи
          selectedTasks: List.from(
            selectedTasks,
          ), // Передаем копию списка, чтобы Flutter зафиксировал изменения
        ),
      );
    }
  }

  // ---UI ЛОГИКА ---
void startEditingTask(TaskWithProject item) {
    activeTaskWithProject = item;
    draftTask = item.task;  // ← копируем задачу в draft при начале редактирования
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
    final updated = task.copyWith(
      status: task.isCompleted ? TaskStatus.inProgress : TaskStatus.done,
    );
    await updateTask(updated);
  }

  Future<void> deleteTask(String id) async {
    await _repository.deleteTask(id);
  }

  Future<void> deleteSelectedTask() async {
    for (final t in selectedTasks) {
      await _repository.deleteTask(t.id);
    }
  }

  Future<void> markSelectedAsDone() async {
    for (final t in selectedTasks) {
      await _repository.updateTask(t.copyWith(status: TaskStatus.done));
    }
  }

  void dispose() {
    _combineSubscription?.cancel();
    _uiStateController.close();
    _uiFlagsController.close();
    _filterController.close();
  }
}
