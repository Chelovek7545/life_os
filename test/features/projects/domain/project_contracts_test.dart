import 'package:test/test.dart';
import 'package:core_contracts/core_contracts.dart' as core;
import 'package:tasks_api/tasks_api.dart' as tasks;
import 'package:projects_api/projects_api.dart' as projects;

void main() {
  test('nullable updates share the core wrapper across public APIs', () {
    final original = projects.Project.create(
      name: 'Keep',
      goalId: 'goal',
      parentProjectId: 'parent',
    ).copyWith(dueDate: core.Wrapped(DateTime(2030, 1, 2)));
    final cleared = original.copyWith(
      dueDate: const tasks.Wrapped(null),
      goalId: const projects.Wrapped(null),
      parentProejectId: const core.Wrapped(null),
    );
    expect(cleared.dueDate, isNull);
    expect(cleared.goalId, isNull);
    expect(cleared.parentProejectId, isNull);
    expect(cleared.id, original.id);
    expect(cleared.createdAt, original.createdAt);
    expect(original.dueDate, isNotNull);
    expect(original.parentProejectId, 'parent');
  });
  test('storage errors keep their identity, message and original cause', () {
    final cause = StateError('SQLite failed');
    final error = core.StorageException('Failed to save project.', cause);
    expect(error.cause, same(cause));
    expect(error.toString(), 'Failed to save project.');
  });
}
