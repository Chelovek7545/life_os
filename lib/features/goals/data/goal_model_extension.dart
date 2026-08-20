import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/goals/domain/goal_model.dart';

extension GoalDataToDomain on GoalModel {
  Goal toDomain() {
    return Goal(
      id: id,
      name: name,
      description: description,
      color: color,
      sphereId: sphereId ?? '',
      dueDate: dueDate,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

extension GoalToDrift on Goal {
  GoalsCompanion toDrift() {
    return GoalsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      color: Value(color),
      sphereId: Value(sphereId),
      dueDate: Value(dueDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }
}