import 'dart:async' as _i3;

import 'package:life_os/core/database/database.dart' as _i6;
import 'package:life_os/features/projects/data/projects_dao.dart' as _i2;
import 'package:life_os/features/projects/domain/project_model.dart' as _i5;
import 'package:mockito/mockito.dart' as _i1;

class MockProjectsDao extends _i1.Mock implements _i2.ProjectsDao {
  MockProjectsDao() {
    _i1.throwOnMissingStub(this);
  }

  @override
  _i3.Stream<List<_i5.Project>> watchAllProjects() =>
      (super.noSuchMethod(
            Invocation.method(#watchAllProjects, []),
            returnValue: _i3.Stream<List<_i5.Project>>.empty(),
          )
          as _i3.Stream<List<_i5.Project>>);

  @override
  _i3.Future<List<_i5.Project>> getAllProjects() =>
      (super.noSuchMethod(
            Invocation.method(#getAllProjects, []),
            returnValue: _i3.Future<List<_i5.Project>>.value(<_i5.Project>[]),
          )
          as _i3.Future<List<_i5.Project>>);

  @override
  _i3.Future<_i6.ProjectModel?> getProjectById(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#getProjectById, [id]),
            returnValue: _i3.Future<_i6.ProjectModel?>.value(),
          )
          as _i3.Future<_i6.ProjectModel?>);

  @override
  _i3.Future<void> createProject(_i6.ProjectsCompanion? project) =>
      (super.noSuchMethod(
            Invocation.method(#createProject, [project]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);

  @override
  _i3.Future<void> updateProject(_i5.Project? project) =>
      (super.noSuchMethod(
            Invocation.method(#updateProject, [project]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);

  @override
  _i3.Future<void> updateProjectName(String? id, String? newName) =>
      (super.noSuchMethod(
            Invocation.method(#updateProjectName, [id, newName]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);

  @override
  _i3.Future<void> archiveProject(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#archiveProject, [id]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);

  @override
  _i3.Future<void> unarchiveProject(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#unarchiveProject, [id]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);

  @override
  _i3.Future<void> deleteProject(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#deleteProject, [id]),
            returnValue: _i3.Future<void>.value(),
            returnValueForMissingStub: _i3.Future<void>.value(),
          )
          as _i3.Future<void>);
}
