import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:test/test.dart';

void main() {
  group('Project', () {
    group('constructor', () {
      test('creates Project with all required fields', () {
        final now = DateTime.now();
        final project = Project(
          id: 'proj-1',
          name: 'My Project',
          description: 'A test project',
          color: '#FF5733',
          createdAt: now,
          updatedAt: now,
          dueDate: now.add(const Duration(days: 7)),
          isArchived: false,
          goalId: 'goal-1',
        );

        expect(project.id, 'proj-1');
        expect(project.name, 'My Project');
        expect(project.description, 'A test project');
        expect(project.color, '#FF5733');
        expect(project.createdAt, now);
        expect(project.updatedAt, now);
        expect(project.dueDate, now.add(const Duration(days: 7)));
        expect(project.isArchived, isFalse);
        expect(project.goalId, 'goal-1');
      });

      test('defaults isArchived to false', () {
        final project = Project(
          id: 'p1',
          name: 'Default',
          description: '',
          color: '#000',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        expect(project.isArchived, isFalse);
      });
    });

    group('Project.create', () {
      test('creates a new Project with generated id', () {
        final project = Project.create(
          name: 'New Project',
          description: 'Desc',
          color: '#4A90D9',
        );

        expect(project.id, isNotEmpty);
        expect(project.name, 'New Project');
        expect(project.description, 'Desc');
        expect(project.color, '#4A90D9');
        expect(project.createdAt, isNotNull);
        expect(project.updatedAt, isNotNull);
        expect(project.isArchived, isFalse);
        expect(project.dueDate, isNull);
      });

      test('uses default color when not specified', () {
        final project = Project.create(name: 'Default Color');
        expect(project.color, '#4A90D9');
      });

      test('uses empty description when not specified', () {
        final project = Project.create(name: 'No Desc');
        expect(project.description, '');
      });
    });

    group('copyWith', () {
      test('returns new Project with updated fields', () {
        final original = Project.create(name: 'Original');
        final updated = original.copyWith(
          name: 'Updated',
          color: '#00FF00',
        );

        expect(updated.name, 'Updated');
        expect(updated.color, '#00FF00');
        expect(updated.id, original.id);
        expect(updated.createdAt, original.createdAt);
      });

      test('Wrapped fields can be set to null', () {
        final project = Project.create(name: 'Test').copyWith(
          dueDate: Wrapped(DateTime.now()),
        );

        expect(project.dueDate, isNotNull);

        final cleared = project.copyWith(dueDate: const Wrapped(null));
        expect(cleared.dueDate, isNull);
      });

      test('preserves fields when not provided', () {
        final original = Project.create(name: 'Original');
        final updated = original.copyWith(name: 'Renamed');

        expect(updated.id, original.id);
        expect(updated.description, original.description);
        expect(updated.color, original.color);
        expect(updated.createdAt, original.createdAt);
        expect(updated.isArchived, original.isArchived);
      });

      test('updates isArchived', () {
        final project = Project.create(name: 'Test');
        final archived = project.copyWith(isArchived: true);
        expect(archived.isArchived, isTrue);
      });
    });

    test('different projects have unique ids', () {
      final p1 = Project.create(name: 'A');
      final p2 = Project.create(name: 'B');
      expect(p1.id, isNot(p2.id));
    });
  });
}
