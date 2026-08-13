import 'package:flutter/material.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:uuid/uuid.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';

//enum TaskStatus { notStarted, inProgress, done, open }

enum TaskStatus {
  open(
    title: 'Open',
    subtitle: 'Pending analysis',
    symbol: '…',
    color: Colors.blueGrey,
    icon: Icons.pending_actions,
  ),
  notStarted(
    title: 'To Do',
    subtitle: 'Awaiting deployment',
    symbol: '○',
    color: Colors.redAccent,
    icon: Icons.radio_button_unchecked,
  ),
  inProgress(
    title: 'In Progress',
    subtitle: 'Active execution',
    symbol: '▶',
    color: Colors.amberAccent,
    icon: Icons.hourglass_top, // Заполненный наполовину круг
  ),
  done(
    title: 'Done',
    subtitle: 'Mission complete',
    symbol: '✓',
    color: Colors.lightGreenAccent,
    icon: Icons.check_circle_outline,
  );

  final String title;
  final String subtitle;
  final IconData icon;
  final String symbol;
  final Color color;

  const TaskStatus({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.symbol,
    required this.color,
  });
}

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
      parentTaskId:
          parentTaskId != null ? parentTaskId.value : this.parentTaskId,
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
