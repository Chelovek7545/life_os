import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/projects/data/extensions/project_model_extension.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:test/test.dart';

void main() {
  group('ProjectDataToDomain', () {
    test('toDomain converts ProjectModel to Project', () {
      final now = DateTime.now();
      final model = ProjectModel(
        id: 'proj-1',
        name: 'My Project',
        description: 'Description',
        color: '#FF0000',
        createdAt: now,
        updatedAt: now,
        dueDate: now.add(const Duration(days: 7)),
        goalId: 'goal-1',
        isArchived: false,
      );

      final project = model.toDomain();

      expect(project.id, 'proj-1');
      expect(project.name, 'My Project');
      expect(project.description, 'Description');
      expect(project.color, '#FF0000');
      expect(project.createdAt, now);
      expect(project.updatedAt, now);
      expect(project.dueDate, now.add(const Duration(days: 7)));
      expect(project.isArchived, isFalse);
    });

    test('toDomain handles nullable fields', () {
      final model = ProjectModel(
        id: 'p1',
        name: 'Minimal',
        description: '',
        color: '#000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isArchived: false,
      );

      final project = model.toDomain();

      expect(project.dueDate, isNull);
      expect(project.goalId, isNull);
    });
  });

  group('ProjectToDrift', () {
    test('toDrift converts Project to ProjectsCompanion', () {
      final now = DateTime.now();
      final project = Project(
        id: 'proj-1',
        name: 'Test',
        description: 'Desc',
        color: '#00FF00',
        createdAt: now,
        updatedAt: now,
        dueDate: now.add(const Duration(days: 3)),
        isArchived: true,
      );

      final companion = project.toDrift();

      expect(companion.id.value, 'proj-1');
      expect(companion.name.value, 'Test');
      expect(companion.color.value, '#00FF00');
      expect(companion.dueDate.value, now.add(const Duration(days: 3)));
      expect(companion.isArchived.value, isTrue);
    });

    test('toDrift handles null dueDate', () {
      final project = Project(
        id: 'p1',
        name: 'No Due Date',
        description: '',
        color: '#000',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final companion = project.toDrift();

      expect(companion.dueDate.value, isNull);
    });
  });
}
