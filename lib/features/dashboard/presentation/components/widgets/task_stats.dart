import 'package:life_os/features/tasks/domain/task_model.dart';

/// Статистика по задачам для виджета дашборда.
({int done, int due}) computeTaskStats(List<Task> tasks) {
  var done = 0;
  var due = 0;
  for (final task in tasks) {
    if (task.isCompleted) {
      done++;
    } else if (task.dueDate != null) {
      due++;
    }
  }
  return (done: done, due: due);
}

/// Число задач с [Task.dueDate] в указанном месяце — «день месяца» -> count.
Map<int, int> tasksCountByDay(List<Task> tasks, int month, int year) {
  final counts = <int, int>{};
  for (final task in tasks) {
    final due = task.dueDate;
    if (due == null || due.month != month || due.year != year) continue;
    counts[due.day] = (counts[due.day] ?? 0) + 1;
  }
  return counts;
}
