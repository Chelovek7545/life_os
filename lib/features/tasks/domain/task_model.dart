import 'package:uuid/uuid.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';

enum TaskStatus {notStarted, inProgress, done, open}

class Wrapped<T> {
  final T value;
  const Wrapped(this.value);
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.isCompleted,
    required this.createdAt,
    required this.timerSeconds,
    required this.effortWeight,
    required this.tags,
    this.dueDate,
    this.projectId,
    this.space,
  });

  final String id;
  final String title;
  final String description;
  final TaskStatus status;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? dueDate;
  final String? projectId;
  final String? space;
  final int timerSeconds;
  final double effortWeight;
  final List<Tag> tags;

  factory Task.blank() {
    return Task(
      id: const Uuid().v4(), // или можно генирировать UUID
      title: 'Untitled',
      description: '',
      status: TaskStatus.open,
      isCompleted: false,
      createdAt: DateTime.now(),
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
    bool? isCompleted,
    DateTime? createdAt,
    Wrapped<DateTime?>? dueDate,
    Wrapped<String?>? projectId,
    Wrapped<String?>? space,
    int? timerSeconds,
    double? effortWeight,
    List<Tag>? tags,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
      dueDate: dueDate != null ? dueDate.value : this.dueDate,
      projectId: projectId != null ? projectId.value : this.projectId,
      space: space != null ? space.value : this.space,
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
