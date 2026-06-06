import 'package:uuid/uuid.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';

enum TaskStatus { open, inProgress, done }

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
    DateTime? dueDate,
    String? projectId,
    String? space,
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
      dueDate: dueDate ?? this.dueDate,
      projectId: projectId ?? this.projectId,
      space: space ?? this.space,
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
