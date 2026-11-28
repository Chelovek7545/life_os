// models/goal_model.dart
import 'package:uuid/uuid.dart';

class Goal {
  final String id;
  final String name;
  final String description;
  final String color;
  final String sphereId;
  final DateTime? dueDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? storageRevision;

  Goal({
    required this.id,
    required this.name,
    required this.description,
    required this.color,
    required this.sphereId,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.storageRevision,
  });

  factory Goal.create({
    required String name,
    required String sphereId,
    String description = '',
    String color = '#E8A838',
    DateTime? dueDate,
  }) {
    final now = DateTime.now();
    return Goal(
      id: const Uuid().v4(),
      name: name,
      description: description,
      color: color,
      sphereId: sphereId,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  Goal copyWith({
    String? id,
    String? name,
    String? description,
    String? color,
    String? sphereId,
    DateTime? dueDate,
    bool clearDueDate = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      id: id ?? this.id,
      storageRevision: storageRevision,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      sphereId: sphereId ?? this.sphereId,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
