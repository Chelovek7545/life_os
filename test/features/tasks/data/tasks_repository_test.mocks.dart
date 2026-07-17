import 'dart:async' as i3;

import 'package:drift/drift.dart' as i4;
import 'package:life_os/core/database/database.dart' as i6;
import 'package:life_os/features/tasks/data/tasks_dao.dart' as i2;
import 'package:life_os/features/tasks/domain/task_model.dart' as i5;
import 'package:mockito/mockito.dart' as i1;

class MockTasksDao extends i1.Mock implements i2.TasksDao {
  MockTasksDao() {
    i1.throwOnMissingStub(this);
  }

  @override
  i3.Stream<List<i5.Task>> watchAllTasksWithTags() =>
      (super.noSuchMethod(
            Invocation.method(#watchAllTasksWithTags, []),
            returnValue: i3.Stream<List<i5.Task>>.empty(),
          )
          as i3.Stream<List<i5.Task>>);

  @override
  i3.Stream<List<i5.Task>> watchTasksForProject(String? projectId) =>
      (super.noSuchMethod(
            Invocation.method(#watchTasksForProject, [projectId]),
            returnValue: i3.Stream<List<i5.Task>>.empty(),
          )
          as i3.Stream<List<i5.Task>>);

  @override
  i3.Future<i6.TaskModel?> getById(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#getById, [id]),
            returnValue: i3.Future<i6.TaskModel?>.value(),
          )
          as i3.Future<i6.TaskModel?>);

  @override
  i3.Future<void> insertTaskWithTags(
    i4.Insertable<dynamic>? taskCompanion,
    List<String>? tagNames,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#insertTaskWithTags, [taskCompanion, tagNames]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);

  @override
  i3.Future<bool> updateTaskWithTags(
    i4.Insertable<dynamic>? taskCompanion,
    List<String>? tagNames,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#updateTaskWithTags, [taskCompanion, tagNames]),
            returnValue: i3.Future<bool>.value(true),
          )
          as i3.Future<bool>);

  @override
  i3.Future<void> deleteTask(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#deleteTask, [id]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);
}
