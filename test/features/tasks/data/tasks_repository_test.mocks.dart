import 'dart:async' as _i3;

import 'package:drift/drift.dart' as _i4;
import 'package:life_os/core/database/database.dart' as _i6;
import 'package:life_os/features/tasks/data/tasks_dao.dart' as _i2;
import 'package:life_os/features/tasks/domain/task_model.dart' as _i5;
import 'package:mockito/mockito.dart' as _i1;

class MockTasksDao extends _i1.Mock implements _i2.TasksDao {
  MockTasksDao() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Stream<List<_i5.Task>> watchAllTasksWithTags() =>
      (super.noSuchMethod(
            Invocation.method(#watchAllTasksWithTags, []),
            returnValue: _i3.Stream<List<_i5.Task>>.empty(),
          )
          as _i3.Stream<List<_i5.Task>>);

  @override
  _i3.Stream<List<_i5.Task>> watchTasksForProject(String? projectId) =>
      (super.noSuchMethod(
            Invocation.method(#watchTasksForProject, [projectId]),
            returnValue: _i3.Stream<List<_i5.Task>>.empty(),
          )
          as _i3.Stream<List<_i5.Task>>);

  @override
  _i3.Future<_i6.TaskModel?> getById(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#getById, [id]),
            returnValue: _i3.Future<_i6.TaskModel?>.value(),
          )
          as _i3.Future<_i6.TaskModel?>);

  @override
  _i3.Future<void> insertTaskWithTags(
    _i4.Insertable<dynamic>? taskCompanion,
    List<String>? tagNames,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#insertTaskWithTags, [taskCompanion, tagNames]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);

  @override
  _i3.Future<bool> updateTaskWithTags(
    _i4.Insertable<dynamic>? taskCompanion,
    List<String>? tagNames,
  ) =>
      (super.noSuchMethod(
            Invocation.method(#updateTaskWithTags, [taskCompanion, tagNames]),
            returnValue: _i3.Future<bool>.value(true),
          )
          as _i3.Future<bool>);

  @override
  _i3.Future<void> deleteTask(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#deleteTask, [id]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);
}
