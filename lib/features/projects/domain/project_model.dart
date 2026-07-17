// models/project_model.dart
import 'package:life_os/core/utils/wrapped.dart';
import 'package:uuid/uuid.dart';

class Project {
  final String id;
  final String name;
  final String description;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueDate;
  final bool isArchived;
  final String? goalId;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.createdAt,
    required this.updatedAt,

    this.dueDate,

    this.goalId,
    this.isArchived = false,
  });

  // Для создания нового проекта
  factory Project.create({
    required String name,
    String description = '',
    String goalId = '',
    String color = '#4A90D9',
  }) {
    final now = DateTime.now();
    return Project(
      id: Uuid().v4(), // Будет заменено на UUID при сохранении
      name: name,
      description: description,
      color: color,
      createdAt: now,
      updatedAt: now,
      isArchived: false,
    );
  }

  // Копирование с изменениями
  Project copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
    Wrapped<DateTime?>? dueDate,
    Wrapped<String?>? goalId,
    bool? isArchived,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueDate: dueDate != null ? dueDate.value : this.dueDate,

      isArchived: isArchived ?? this.isArchived,
      goalId: goalId != null ? goalId.value : this.goalId,
    );
  }
}
