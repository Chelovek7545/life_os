// models/sphere_model.dart
import 'package:uuid/uuid.dart';

class Sphere {
  final String id;
  final String name;
  final String color;
  final DateTime createdAt;
  final DateTime updatedAt;

  Sphere({
    required this.id,
    required this.name,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Sphere.create({
    required String name,
    String color = '#4A90D9',
  }) {
    final now = DateTime.now();
    return Sphere(
      id: const Uuid().v4(),
      name: name,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
  }

  Sphere copyWith({
    String? id,
    String? name,
    String? color,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Sphere(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}