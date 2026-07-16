enum DatePeriod { day, week, month, year }

class TaskFilterConfig {
  final DateTime anchorDate;
  final DatePeriod period;
  final List<String> projectIds;
  final List<int> tagIds;
  final bool? showCompleted;

  const TaskFilterConfig({
    required this.anchorDate,
    this.period = DatePeriod.day,
    this.projectIds = const [],
    this.tagIds = const [],
    this.showCompleted,
  });

  TaskFilterConfig copyWith({
    DateTime? anchorDate,
    DatePeriod? period,
    List<String>? projectIds,
    List<int>? tagIds,
    bool? Function()? showCompleted,
  }) {
    return TaskFilterConfig(
      anchorDate: anchorDate ?? this.anchorDate,
      period: period ?? this.period,
      projectIds: projectIds ?? this.projectIds,
      tagIds: tagIds ?? this.tagIds,
      showCompleted: showCompleted != null ? showCompleted() : this.showCompleted,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskFilterConfig &&
          runtimeType == other.runtimeType &&
          anchorDate == other.anchorDate &&
          period == other.period &&
          _listEquals(projectIds, other.projectIds) &&
          _listEquals(tagIds, other.tagIds) &&
          showCompleted == other.showCompleted;

  @override
  int get hashCode => Object.hash(
        anchorDate,
        period,
        Object.hashAll,
        Object.hashAll(tagIds),
        showCompleted,
      );

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}