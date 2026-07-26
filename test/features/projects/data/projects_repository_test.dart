import 'dart:async';

import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/projects/data/projects_dao.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../test_helpers.dart';
import 'projects_repository_test.mocks.dart';

@GenerateMocks([ProjectsDao])

void main() {
  late MockProjectsDao mockDao;
  late ProjectsRepository repository;

  setUp(() {
    mockDao = MockProjectsDao();
    repository = ProjectsRepository(mockDao);
  });

  group('ProjectsRepository', () {
    group('watchAllProjects', () {
      test('delegates to dao.watchAllProjects', () {
        final stream = Stream<List<Project>>.value([]);
        when(mockDao.watchAllProjects()).thenAnswer((_) => stream);

        final result = repository.watchAllProjects();

        expect(result, stream);
        verify(mockDao.watchAllProjects()).called(1);
      });
    });

    group('getAllProjects', () {
      test('delegates to dao.getAllProjects', () async {
        when(mockDao.getAllProjects()).thenAnswer((_) async => []);

        final result = await repository.getAllProjects();

        expect(result, isEmpty);
        verify(mockDao.getAllProjects()).called(1);
      });
    });

    group('getProjectById', () {
      test('returns null when project not found', () async {
        when(mockDao.getProjectById('proj-1')).thenAnswer((_) async => null);

        final result = await repository.getProjectById('proj-1');

        expect(result, isNull);
        verify(mockDao.getProjectById('proj-1')).called(1);
      });

      test('returns project when found and converts via toDomain', () async {
        final now = DateTime.now();
        final daoModel = ProjectModel(
          id: 'proj-1',
          name: 'Found Project',
          description: 'A project',
          color: '#00FF00',
          createdAt: now,
          updatedAt: now,
          isArchived: false,
          dueDate: null,
        );
        when(mockDao.getProjectById('proj-1'))
            .thenAnswer((_) async => daoModel);

        final result = await repository.getProjectById('proj-1');

        expect(result, isNotNull);
        expect(result!.id, 'proj-1');
        expect(result.name, 'Found Project');
        expect(result.color, '#00FF00');
        verify(mockDao.getProjectById('proj-1')).called(1);
      });
    });

    group('addProject', () {
      test('delegates to dao.createProject', () async {
        final project = createMockProject();
        when(mockDao.createProject(any)).thenAnswer((_) async => {});

        await repository.addProject(project);

        verify(mockDao.createProject(any)).called(1);
      });

      test('throws StorageException on dao error', () async {
        final project = createMockProject();
        when(
          mockDao.createProject(any),
        ).thenAnswer((_) => Future.error(Exception('db error')));

        await expectLater(
          repository.addProject(project),
          throwsA(isA<StorageException>()),
        );
      });
    });

    group('updateProject', () {
      test('delegates to dao.updateProject', () async {
        final project = createMockProject();
        when(mockDao.updateProject(any)).thenAnswer((_) async => {});

        await repository.updateProject(project);

        verify(mockDao.updateProject(project)).called(1);
      });

      test('throws StorageException on dao error', () async {
        final project = createMockProject();
        when(
          mockDao.updateProject(any),
        ).thenAnswer((_) => Future.error(Exception('db error')));

        await expectLater(
          repository.updateProject(project),
          throwsA(isA<StorageException>()),
        );
      });
    });

    group('deleteProject', () {
      test('delegates to dao.deleteProject', () async {
        when(mockDao.deleteProject('proj-1')).thenAnswer((_) async => {});

        await repository.deleteProject('proj-1');

        verify(mockDao.deleteProject('proj-1')).called(1);
      });

      test('swallows dao error silently', () async {
        when(mockDao.deleteProject(any))
            .thenAnswer((_) => Future.error(Exception('db error')));

        await repository.deleteProject('proj-1');

        verify(mockDao.deleteProject(any)).called(1);
      });
    });
  });
}
