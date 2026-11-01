import 'get_tasks_with_projects_use_case.dart';

import 'package:tasks_api/tasks_api.dart';

sealed class TaskScreenState {
  const TaskScreenState();

  R when<R>({
    required R Function() loading,
    required R Function(String? aiSuggestion, bool isProcessing) empty,
    required R Function(
      List<TaskWithProject> tasks,
      List<Task> selectedTasks,
      bool isProcessing,
      Task? curTask,
      List<TaskWithProject> unscheduledTasks,
    )
    loaded,
    required R Function(String message) error,
  }) {
    return switch (this) {
      TasksLoading() => loading(),
      TasksEmpty(
        aiSuggestion: final aiSuggestion,
        isProcessing: final isProcessing,
      ) =>
        empty(aiSuggestion, isProcessing),
      TasksLoaded(
        tasks: final tasks,
        selectedTasks: final selectedTasks,
        isProcessing: final isProcessing,
        curTask: final curTask,
        unscheduledTasks: final unscheduledTasks,
      ) =>
        loaded(tasks, selectedTasks, isProcessing, curTask, unscheduledTasks),
      TasksError(message: final message) => error(message),
    };
  }

  // Добавляем maybeWhen для частичной обработки
  R? maybeWhen<R>({
    R Function()? loading,
    R Function(String? aiSuggestion, bool isProcessing)? empty,
    R Function(
      List<TaskWithProject> tasks,
      List<Task> selectedTasks,
      bool isProcessing,
      Task? curTask,
      List<TaskWithProject> unscheduledTasks,
    )?
    loaded,
    R Function(String message)? error,
    required R Function() orElse,
  }) {
    return switch (this) {
      TasksLoading() => loading?.call() ?? orElse(),
      TasksEmpty(
        aiSuggestion: final aiSuggestion,
        isProcessing: final isProcessing,
      ) =>
        empty?.call(aiSuggestion, isProcessing) ?? orElse(),
      TasksLoaded(
        tasks: final tasks,
        selectedTasks: final selectedTasks,
        isProcessing: final isProcessing,
        curTask: final curTask,
        unscheduledTasks: final unscheduledTasks,
      ) =>
        loaded?.call(
              tasks,
              selectedTasks,
              isProcessing,
              curTask,
              unscheduledTasks,
            ) ??
            orElse(),
      TasksError(message: final message) => error?.call(message) ?? orElse(),
    };
  }

  // Вспомогательные геттеры для проверки типа
  bool get isLoading => this is TasksLoading;
  bool get isEmpty => this is TasksEmpty;
  bool get isLoaded => this is TasksLoaded;
  bool get isError => this is TasksError;
}

final class TasksLoading extends TaskScreenState {
  const TasksLoading();
}

final class TasksEmpty extends TaskScreenState {
  const TasksEmpty({this.aiSuggestion, this.isProcessing = false});

  final String? aiSuggestion;
  final bool isProcessing;
}

final class TasksLoaded extends TaskScreenState {
  TasksLoaded({
    required List<TaskWithProject> tasks,
    required List<Task> selectedTasks,
    this.isProcessing = false,
    this.curTask,
    List<TaskWithProject> unscheduledTasks = const [],
  }) : tasks = List.unmodifiable(tasks),
       selectedTasks = List.unmodifiable(selectedTasks),
       unscheduledTasks = List.unmodifiable(unscheduledTasks);

  final List<Task> selectedTasks;
  final List<TaskWithProject> tasks;
  final List<TaskWithProject> unscheduledTasks;
  final Task? curTask;
  final bool isProcessing;
}

final class TasksError extends TaskScreenState {
  const TasksError(this.message);

  final String message;
}
