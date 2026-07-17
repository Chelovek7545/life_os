import 'package:drift/drift.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

/// Extension для преобразования Drift модели в domain модель
extension TaskDataToDomain on TaskModel {
  Task toDomain({List<Tag>? tags}) {
    return Task(
      id: id,
      title: title,
      description: description,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      startsAt: startsAt,
      endsAt: endsAt,
      dueDate: dueDate,
      projectId: projectId,
      space: space,
      timerSeconds: timerSeconds,
      effortWeight: effortWeight,
      tags: tags ?? const [],
    );
  }
}

/// Extension для преобразования domain модели в Drift companion
extension TaskToDrift on Task {
  TasksCompanion toDrift() {
    return TasksCompanion(
      id: Value(id),
      title: Value(title),
      description: Value(description),
      status: Value(status),

      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      startsAt: Value(startsAt),
      endsAt: Value(endsAt),
      dueDate: Value(dueDate),
      projectId: Value(projectId),
      space: Value(space),
      timerSeconds: Value(timerSeconds),
      effortWeight: Value(effortWeight),
    );
  }
}
