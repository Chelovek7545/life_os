import 'dart:async';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../test_helpers.dart';
import 'tasks_repository_test.mocks.dart';

@GenerateMocks([TasksDao])

void main() {
  late MockTasksDao mockDao;
  late TasksRepository repository;

  setUp(() {
    mockDao = MockTasksDao();
    repository = TasksRepository(mockDao);
  });

  group('TasksRepository', () {
    group('watchTasks', () {
      test('delegates to dao.watchAllTasksWithTags', () {
        final stream = Stream<List<Task>>.value([]);
        when(mockDao.watchAllTasksWithTags()).thenAnswer((_) => stream);

        final result = repository.watchTasks();

        expect(result, stream);
        verify(mockDao.watchAllTasksWithTags()).called(1);
      });
    });

    group('watchTasksForProject', () {
      test('delegates to dao.watchTasksForProject', () {
        final stream = Stream<List<Task>>.value([]);
        when(mockDao.watchTasksForProject('proj-1')).thenAnswer((_) => stream);

        final result = repository.watchTasksForProject('proj-1');

        expect(result, stream);
        verify(mockDao.watchTasksForProject('proj-1')).called(1);
      });
    });

    group('getById', () {
      test('returns null when task not found', () async {
        when(mockDao.getById('task-1')).thenAnswer((_) async => null);

        final result = await repository.getById('task-1');

        expect(result, isNull);
        verify(mockDao.getById('task-1')).called(1);
      });
    });

    group('addTask', () {
      test('delegates to dao.insertTaskWithTags', () async {
        final task = createMockTask(tags: [createMockTag(id: 1, name: 'dev')]);
        when(mockDao.insertTaskWithTags(any, any)).thenAnswer((_) async => {});

        await repository.addTask(task);

        verify(mockDao.insertTaskWithTags(any, any)).called(1);
      });

      test('throws StorageException on dao error', () async {
        final task = createMockTask();
        when(
          mockDao.insertTaskWithTags(any, any),
        ).thenAnswer((_) => Future.error(Exception('db error')));

        await expectLater(
          repository.addTask(task),
          throwsA(isA<StorageException>()),
        );
      });
    });

    group('updateTask', () {
      test('delegates to dao.updateTaskWithTags', () async {
        final task = createMockTask(tags: [createMockTag(id: 1, name: 'dev')]);
        when(
          mockDao.updateTaskWithTags(any, any),
        ).thenAnswer((_) async => true);

        await repository.updateTask(task);

        verify(mockDao.updateTaskWithTags(any, any)).called(1);
      });

      test('throws StorageException on dao error', () async {
        final task = createMockTask();
        when(
          mockDao.updateTaskWithTags(any, any),
        ).thenAnswer((_) => Future.error(Exception('db error')));

        await expectLater(
          repository.updateTask(task),
          throwsA(isA<StorageException>()),
        );
      });
    });

    group('deleteTask', () {
      test('delegates to dao.deleteTask', () async {
        when(mockDao.deleteTask('task-1')).thenAnswer((_) async => {});

        await repository.deleteTask('task-1');

        verify(mockDao.deleteTask('task-1')).called(1);
      });

      test('throws StorageException on dao error', () async {
        when(
          mockDao.deleteTask('task-1'),
        ).thenAnswer((_) => Future.error(Exception('db error')));

        await expectLater(
          repository.deleteTask('task-1'),
          throwsA(isA<StorageException>()),
        );
      });
    });
  });
}
