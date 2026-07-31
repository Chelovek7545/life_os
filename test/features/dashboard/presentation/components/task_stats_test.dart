import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/dashboard/presentation/components/widgets/task_stats.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

Task _task({
  String id = 't',
  TaskStatus status = TaskStatus.open,
  DateTime? dueDate,
}) {
  return Task(
    id: id,
    title: 'Task $id',
    description: '',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    dueDate: dueDate,
    timerSeconds: 0,
    effortWeight: 0.0,
    tags: const [],
  );
}

void main() {
  group('computeTaskStats', () {
    test('returns zeros for empty list', () {
      final stats = computeTaskStats([]);
      expect(stats.done, 0);
      expect(stats.due, 0);
    });

    test('counts completed tasks as done', () {
      final stats = computeTaskStats([
        _task(id: '1', status: TaskStatus.done),
        _task(id: '2', status: TaskStatus.done),
        _task(id: '3', status: TaskStatus.open),
      ]);
      expect(stats.done, 2);
    });

    test('counts open tasks with dueDate as due', () {
      final stats = computeTaskStats([
        _task(id: '1', dueDate: DateTime(2026, 5, 10)),
        _task(id: '2', dueDate: DateTime(2026, 5, 12)),
        _task(id: '3'),
      ]);
      expect(stats.due, 2);
    });

    test('excludes completed tasks from due', () {
      final stats = computeTaskStats([
        _task(id: '1', status: TaskStatus.done, dueDate: DateTime(2026, 5, 10)),
      ]);
      expect(stats.due, 0);
      expect(stats.done, 1);
    });
  });

  group('tasksCountByDay', () {
    test('returns empty map for empty list', () {
      expect(tasksCountByDay([], 5, 2026), isEmpty);
    });

    test('groups tasks by day of the given month', () {
      final tasks = [
        _task(id: '1', dueDate: DateTime(2026, 5, 3, 10, 30)),
        _task(id: '2', dueDate: DateTime(2026, 5, 3, 18, 0)),
        _task(id: '3', dueDate: DateTime(2026, 5, 20)),
      ];
      final counts = tasksCountByDay(tasks, 5, 2026);
      expect(counts, {3: 2, 20: 1});
    });

    test('ignores tasks outside the given month', () {
      final tasks = [
        _task(id: '1', dueDate: DateTime(2026, 4, 30)),
        _task(id: '2', dueDate: DateTime(2026, 6, 1)),
        _task(id: '3', dueDate: DateTime(2025, 5, 15)),
        _task(id: '4'),
      ];
      final counts = tasksCountByDay(tasks, 5, 2026);
      expect(counts, isEmpty);
    });
  });
}
