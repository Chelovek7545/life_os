import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/projects/domain/project_model.dart';

/// Extension для преобразования Drift модели в domain модель
extension ProjectDataToDomain on ProjectModel {
  Project toDomain() {
    return Project(
      id: id,
      name: name,
      description: description,
      color: color,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: isArchived,
    );
  }
}

/// Extension для преобразования domain модели в Drift companion
extension ProjectToDrift on Project {
  ProjectsCompanion toDrift() {
    return ProjectsCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      color: Value(color),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isArchived: Value(isArchived),
    );
  }
}
