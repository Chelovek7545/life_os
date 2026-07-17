import 'package:life_os/core/database/database.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/tasks/data/extensions/task_model_extension.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:test/test.dart';

void main() {
  group('TaskDataToDomain', () {
    test('toDomain converts TaskModel to Task', () {
      final now = DateTime.now();
      final model = TaskModel(
        id: 'task-1',
        title: 'Test',
        description: 'Desc',
        status: TaskStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        startsAt: now,
        endsAt: now.add(const Duration(hours: 1)),
        dueDate: now.add(const Duration(days: 1)),
        space: 'personal',
        projectId: 'proj-1',
        spaceId: null,
        timerSeconds: 600,
        priority: 0,
        effortWeight: 1.5,
      );

      final task = model.toDomain();

      expect(task.id, 'task-1');
      expect(task.title, 'Test');
      expect(task.status, TaskStatus.inProgress);
      expect(task.startsAt, now);
      expect(task.endsAt, now.add(const Duration(hours: 1)));
      expect(task.dueDate, now.add(const Duration(days: 1)));
      expect(task.projectId, 'proj-1');
      expect(task.timerSeconds, 600);
      expect(task.effortWeight, 1.5);
      expect(task.tags, isEmpty);
    });

    test('toDomain passes tags when provided', () {
      final model = TaskModel(
        id: 't1',
        title: 'T',
        description: '',
        status: TaskStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        timerSeconds: 0,
        priority: 0,
        effortWeight: 0.0,
      );
      final tags = [Tag(id: 1, name: 'urgent', colorHex: 0xFF0000)];

      final task = model.toDomain(tags: tags);

      expect(task.tags.length, 1);
      expect(task.tags.first.name, 'urgent');
    });
  });

  group('TaskToDrift', () {
    test('toDrift converts Task to TasksCompanion', () {
      final now = DateTime.now();
      final task = Task(
        id: 'task-1',
        title: 'Test Task',
        description: 'Description',
        status: TaskStatus.done,
        createdAt: now,
        updatedAt: now,
        startsAt: now,
        endsAt: now.add(const Duration(hours: 1)),
        dueDate: now.add(const Duration(days: 1)),
        projectId: 'proj-1',
        space: 'work',
        timerSeconds: 1200,
        effortWeight: 2.0,
        tags: [Tag(id: 1, name: 'test', colorHex: 0xFFFFFF)],
      );

      final companion = task.toDrift();

      expect(companion.id.value, 'task-1');
      expect(companion.title.value, 'Test Task');
      expect(companion.status.value, TaskStatus.done);
      expect(companion.startsAt.value, now);
      expect(companion.endsAt.value, now.add(const Duration(hours: 1)));
      expect(companion.projectId.value, 'proj-1');
      expect(companion.timerSeconds.value, 1200);
      expect(companion.effortWeight.value, 2.0);
    });

    test('toDrift handles nullable fields as null', () {
      final task = Task(
        id: 't1',
        title: 'Minimal',
        description: '',
        status: TaskStatus.open,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        timerSeconds: 0,
        effortWeight: 0.0,
        tags: const [],
      );

      final companion = task.toDrift();

      expect(companion.startsAt.value, isNull);
      expect(companion.endsAt.value, isNull);
      expect(companion.dueDate.value, isNull);
      expect(companion.projectId.value, isNull);
    });
  });
}
