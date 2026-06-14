enum DatePeriod { day, week, month, year }

class TaskFilterConfig {
  final DateTime anchorDate;
  final DatePeriod period;
  final List<String> projectIds; // Фильтр по нескольким проектам
  final List<int> tagIds;     // Фильтр по тегам
  final bool? showCompleted;     // null - все, true - только выполненные, false - только активные

  const TaskFilterConfig({
    required this.anchorDate,
    this.period = DatePeriod.day,
    this.projectIds = const [],
    this.tagIds = const [],
    this.showCompleted,
  });

  // Позволяет изменять только часть фильтров
  TaskFilterConfig copyWith({
    DateTime? anchorDate,
    DatePeriod? period,
    List<String>? projectIds,
    List<int>? tagIds,
    bool? Function()? showCompleted, // Хитрая обертка для возможности сброса в null
  }) {
    return TaskFilterConfig(
      anchorDate: anchorDate ?? this.anchorDate,
      period: period ?? this.period,
      projectIds: projectIds ?? this.projectIds,
      tagIds: tagIds ?? this.tagIds,
      showCompleted: showCompleted != null ? showCompleted() : this.showCompleted,
    );
  }
}