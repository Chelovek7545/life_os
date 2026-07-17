import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:test/test.dart';

void main() {
  group('Task', () {
    group('constructor', () {
      test('creates Task with all required fields', () {
        final now = DateTime.now();
        final task = Task(
          id: 'test-id',
          title: 'Test Task',
          description: 'Description',
          status: TaskStatus.inProgress,
          createdAt: now,
          updatedAt: now,
          startsAt: now,
          endsAt: now.add(const Duration(hours: 1)),
          dueDate: now.add(const Duration(days: 1)),
          projectId: 'project-1',
          space: 'personal',
          timerSeconds: 3600,
          effortWeight: 1.5,
          tags: [Tag(id: 1, name: 'work', colorHex: 0xFF0000)],
        );

        expect(task.id, 'test-id');
        expect(task.title, 'Test Task');
        expect(task.status, TaskStatus.inProgress);
        expect(task.tags.length, 1);
      });

      test('Task.blank creates valid task with defaults', () {
        final task = Task.blank();

        expect(task.id, isNotEmpty);
        expect(task.title, 'Untitled');
        expect(task.description, '');
        expect(task.status, TaskStatus.open);
        expect(task.createdAt, isNotNull);
        expect(task.updatedAt, isNotNull);
        expect(task.timerSeconds, 0);
        expect(task.effortWeight, 0.0);
        expect(task.tags, isEmpty);
        expect(task.startsAt, isNull);
        expect(task.endsAt, isNull);
        expect(task.dueDate, isNull);
        expect(task.projectId, isNull);
        expect(task.space, isNull);
      });
    });

    group('isCompleted', () {
      test('returns true when status is done', () {
        final task = Task.blank().copyWith(status: TaskStatus.done);
        expect(task.isCompleted, isTrue);
      });

      test('returns false for other statuses', () {
        expect(
          Task.blank().copyWith(status: TaskStatus.open).isCompleted,
          isFalse,
        );
        expect(
          Task.blank().copyWith(status: TaskStatus.notStarted).isCompleted,
          isFalse,
        );
        expect(
          Task.blank().copyWith(status: TaskStatus.inProgress).isCompleted,
          isFalse,
        );
      });
    });

    group('duration', () {
      test('calculates duration when both startsAt and endsAt are set', () {
        final start = DateTime(2024, 1, 1, 9, 0);
        final end = DateTime(2024, 1, 1, 11, 30);
        final task = Task.blank().copyWith(
          startsAt: Wrapped(start),
          endsAt: Wrapped(end),
        );

        expect(task.duration, const Duration(hours: 2, minutes: 30));
      });

      test('returns 15 minutes default when endsAt is null', () {
        final task = Task.blank().copyWith(
          startsAt: Wrapped(DateTime.now()),
          endsAt: const Wrapped(null),
        );

        expect(task.duration, const Duration(minutes: 15));
      });

      test('returns 15 minutes default when startsAt is null', () {
        final task = Task.blank().copyWith(
          startsAt: const Wrapped(null),
          endsAt: Wrapped(DateTime.now()),
        );

        expect(task.duration, const Duration(minutes: 15));
      });
    });

    group('copyWith', () {
      test('returns new Task with updated fields', () {
        final original = Task.blank();
        final newTitle = 'Updated Title';
        final newStatus = TaskStatus.done;

        final updated = original.copyWith(title: newTitle, status: newStatus);

        expect(updated.id, original.id);
        expect(updated.title, newTitle);
        expect(updated.status, newStatus);
        expect(updated.description, original.description);
        expect(updated.createdAt, original.createdAt);
      });

      test('Wrapped fields can be set to null', () {
        final task = Task.blank().copyWith(
          startsAt: Wrapped(DateTime.now()),
          endsAt: Wrapped(DateTime.now().add(const Duration(hours: 1))),
        );

        expect(task.startsAt, isNotNull);
        expect(task.endsAt, isNotNull);

        final cleared = task.copyWith(
          startsAt: const Wrapped(null),
          endsAt: const Wrapped(null),
        );

        expect(cleared.startsAt, isNull);
        expect(cleared.endsAt, isNull);
      });

      test('preserves tags when not provided', () {
        final tag = Tag(id: 1, name: 'tag', colorHex: 0xFF0000);
        final original = Task.blank().copyWith(tags: [tag]);

        final updated = original.copyWith(title: 'New Title');

        expect(updated.tags, [tag]);
      });

      test('updates tags when provided', () {
        final original = Task.blank().copyWith(
          tags: [Tag(id: 1, name: 'old', colorHex: 0)],
        );
        final newTag = Tag(id: 2, name: 'new', colorHex: 0);

        final updated = original.copyWith(tags: [newTag]);

        expect(updated.tags, [newTag]);
      });
    });

    group('TaskStatus', () {
      test('has expected values', () {
        expect(TaskStatus.values, [
          TaskStatus.notStarted,
          TaskStatus.inProgress,
          TaskStatus.done,
          TaskStatus.open,
        ]);
      });
    });
  });

  group('taskStatusFromStorage', () {
    test('parses valid status strings', () {
      expect(taskStatusFromStorage('notStarted'), TaskStatus.notStarted);
      expect(taskStatusFromStorage('inProgress'), TaskStatus.inProgress);
      expect(taskStatusFromStorage('done'), TaskStatus.done);
      expect(taskStatusFromStorage('open'), TaskStatus.open);
    });

    test('returns open for unknown values', () {
      expect(taskStatusFromStorage('unknown'), TaskStatus.open);
      expect(taskStatusFromStorage(''), TaskStatus.open);
    });
  });
}
