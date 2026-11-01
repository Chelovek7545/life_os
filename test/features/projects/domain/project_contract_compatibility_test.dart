import 'package:test/test.dart';
import 'package:core_contracts/core_contracts.dart' as core;
import 'package:tasks_api/tasks_api.dart' as tasks;
import 'package:projects_api/projects_api.dart' as projects;
import 'package:life_os/core/storage/storage_exception.dart' as old_storage;
import 'package:life_os/features/projects/domain/project_model.dart'
    as old_model;
import 'package:life_os/core/utils/wrapped.dart' as old_wrapper;

void main() {
  test(
    'old model and nullable-update exports keep the same types across APIs',
    () {
      final original = projects.Project.create(
        name: 'Keep',
        goalId: 'goal',
        parentProjectId: 'parent',
      ).copyWith(dueDate: core.Wrapped(DateTime(2030, 1, 2)));
      expect(original, isA<old_model.Project>());
      final cleared = original.copyWith(
        dueDate: const tasks.Wrapped(null),
        goalId: const projects.Wrapped(null),
        parentProejectId: const old_wrapper.Wrapped(null),
      );
      expect(cleared.dueDate, isNull);
      expect(cleared.goalId, isNull);
      expect(cleared.parentProejectId, isNull);
      expect(cleared.id, original.id);
      expect(cleared.createdAt, original.createdAt);
      expect(original.dueDate, isNotNull);
      expect(original.parentProejectId, 'parent');
    },
  );
  test('storage errors keep their identity, message and original cause', () {
    final cause = StateError('SQLite failed');
    final error = core.StorageException('Failed to save project.', cause);
    expect(error, isA<old_storage.StorageException>());
    expect(error.cause, same(cause));
    expect(error.toString(), 'Failed to save project.');
  });
}
