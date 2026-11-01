import 'package:uuid/uuid.dart';
import 'tag.dart';
import 'package:core_contracts/core_contracts.dart' show Wrapped;

enum TaskStatus { open, notStarted, inProgress, done }

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,

    required this.updatedAt,

    this.startsAt,
    this.endsAt,
    required this.timerSeconds,
    required this.effortWeight,
    required this.tags,
    this.dueDate,
    this.projectId,
    this.parentTaskId,
    this.space,
    this.spaceId,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  final DateTime? startsAt;
  final DateTime? endsAt;

  final DateTime? dueDate;
  final String? projectId;
  final String? parentTaskId;
  final String? space;
  final String? spaceId;
  final int priority;
  final int timerSeconds;
  final double effortWeight;
  final List<Tag> tags;

  bool get isCompleted => status == TaskStatus.done;

  Duration get duration {
    if (startsAt != null && endsAt != null) {
      return endsAt!.difference(startsAt!);
    }
    return const Duration(minutes: 15);
  }

  factory Task.blank() {
    return Task(
      id: const Uuid().v4(), // или можно генирировать UUID
      title: 'Untitled',
      description: '',
      status: TaskStatus.open,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),

      timerSeconds: 0,
      effortWeight: 0.0,
      tags: const [],
    );
  }

  Task copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Wrapped<DateTime?>? startsAt,
    Wrapped<DateTime?>? endsAt,

    Wrapped<DateTime?>? dueDate,
    Wrapped<String?>? projectId,
    Wrapped<String?>? parentTaskId,
    Wrapped<String?>? space,
    Wrapped<String?>? spaceId,
    int? priority,
    int? timerSeconds,
    double? effortWeight,
    List<Tag>? tags,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate != null ? dueDate.value : this.dueDate,
      startsAt: startsAt != null ? startsAt.value : this.startsAt,
      endsAt: endsAt != null ? endsAt.value : this.endsAt,

      projectId: projectId != null ? projectId.value : this.projectId,
      parentTaskId: parentTaskId != null
          ? parentTaskId.value
          : this.parentTaskId,
      space: space != null ? space.value : this.space,
      spaceId: spaceId != null ? spaceId.value : this.spaceId,
      priority: priority ?? this.priority,
      timerSeconds: timerSeconds ?? this.timerSeconds,
      effortWeight: effortWeight ?? this.effortWeight,
      tags: tags ?? this.tags,
    );
  }
}

TaskStatus taskStatusFromStorage(String value) {
  return TaskStatus.values.firstWhere(
    (TaskStatus status) => status.name == value,
    orElse: () => TaskStatus.open,
  );
}
