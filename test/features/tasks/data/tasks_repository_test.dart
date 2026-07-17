import 'dart:async';

import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/tasks/data/tasks_dao.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import '../../../test_helpers.dart';
import 'tasks_repository_test.mocks.dart';

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
<<<<<<< HEAD
        when(mockDao.watchTasksForProject('proj-1')).thenAnswer((_) => stream);
=======
        when(mockDao.watchTasksForProject('proj-1'))
            .thenAnswer((_) => stream);
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        final result = repository.watchTasksForProject('proj-1');

        expect(result, stream);
        verify(mockDao.watchTasksForProject('proj-1')).called(1);
      });
    });

    group('getById', () {
      test('returns null when task not found', () async {
<<<<<<< HEAD
        when(mockDao.getById('task-1')).thenAnswer((_) async => null);
=======
        when(mockDao.getById('task-1'))
            .thenAnswer((_) async => null);
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        final result = await repository.getById('task-1');

        expect(result, isNull);
        verify(mockDao.getById('task-1')).called(1);
      });
    });

    group('addTask', () {
      test('delegates to dao.insertTaskWithTags', () async {
        final task = createMockTask(tags: [createMockTag(id: 1, name: 'dev')]);
<<<<<<< HEAD
        when(mockDao.insertTaskWithTags(any, any)).thenAnswer((_) async => {});
=======
        when(mockDao.insertTaskWithTags(any, any))
            .thenAnswer((_) async => {});
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        await repository.addTask(task);

        verify(mockDao.insertTaskWithTags(any, any)).called(1);
      });

      test('throws StorageException on dao error', () async {
        final task = createMockTask();
<<<<<<< HEAD
        when(
          mockDao.insertTaskWithTags(any, any),
        ).thenAnswer((_) => Future.error(Exception('db error')));
=======
        when(mockDao.insertTaskWithTags(any, any))
            .thenAnswer((_) => Future.error(Exception('db error')));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        await expectLater(
          repository.addTask(task),
          throwsA(isA<StorageException>()),
        );
      });
    });

    group('updateTask', () {
      test('delegates to dao.updateTaskWithTags', () async {
        final task = createMockTask(tags: [createMockTag(id: 1, name: 'dev')]);
<<<<<<< HEAD
        when(
          mockDao.updateTaskWithTags(any, any),
        ).thenAnswer((_) async => true);
=======
        when(mockDao.updateTaskWithTags(any, any))
            .thenAnswer((_) async => true);
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        await repository.updateTask(task);

        verify(mockDao.updateTaskWithTags(any, any)).called(1);
      });

      test('throws StorageException on dao error', () async {
        final task = createMockTask();
<<<<<<< HEAD
        when(
          mockDao.updateTaskWithTags(any, any),
        ).thenAnswer((_) => Future.error(Exception('db error')));
=======
        when(mockDao.updateTaskWithTags(any, any))
            .thenAnswer((_) => Future.error(Exception('db error')));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        await expectLater(
          repository.updateTask(task),
          throwsA(isA<StorageException>()),
        );
      });
    });

    group('deleteTask', () {
      test('delegates to dao.deleteTask', () async {
<<<<<<< HEAD
        when(mockDao.deleteTask('task-1')).thenAnswer((_) async => {});
=======
        when(mockDao.deleteTask('task-1'))
            .thenAnswer((_) async => {});
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        await repository.deleteTask('task-1');

        verify(mockDao.deleteTask('task-1')).called(1);
      });

      test('throws StorageException on dao error', () async {
<<<<<<< HEAD
        when(
          mockDao.deleteTask('task-1'),
        ).thenAnswer((_) => Future.error(Exception('db error')));
=======
        when(mockDao.deleteTask('task-1'))
            .thenAnswer((_) => Future.error(Exception('db error')));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

        await expectLater(
          repository.deleteTask('task-1'),
          throwsA(isA<StorageException>()),
        );
      });
    });
  });
}
