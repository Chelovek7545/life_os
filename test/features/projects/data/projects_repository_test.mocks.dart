import 'dart:async' as i3;

import 'package:life_os/core/database/database.dart' as i6;
import 'package:life_os/features/projects/data/projects_dao.dart' as i2;
import 'package:life_os/features/projects/domain/project_model.dart' as i5;
import 'package:mockito/mockito.dart' as i1;

class MockProjectsDao extends i1.Mock implements i2.ProjectsDao {
  MockProjectsDao() {
    i1.throwOnMissingStub(this);
  }

  @override
  i3.Stream<List<i5.Project>> watchAllProjects() =>
      (super.noSuchMethod(
            Invocation.method(#watchAllProjects, []),
            returnValue: i3.Stream<List<i5.Project>>.empty(),
          )
          as i3.Stream<List<i5.Project>>);

  @override
  i3.Future<List<i5.Project>> getAllProjects() =>
      (super.noSuchMethod(
            Invocation.method(#getAllProjects, []),
            returnValue: i3.Future<List<i5.Project>>.value(<i5.Project>[]),
          )
          as i3.Future<List<i5.Project>>);

  @override
  i3.Future<i6.ProjectModel?> getProjectById(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#getProjectById, [id]),
            returnValue: i3.Future<i6.ProjectModel?>.value(),
          )
          as i3.Future<i6.ProjectModel?>);

  @override
  i3.Future<void> createProject(i6.ProjectsCompanion? project) =>
      (super.noSuchMethod(
            Invocation.method(#createProject, [project]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);

  @override
  i3.Future<void> updateProject(i5.Project? project) =>
      (super.noSuchMethod(
            Invocation.method(#updateProject, [project]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);

  @override
  i3.Future<void> updateProjectName(String? id, String? newName) =>
      (super.noSuchMethod(
            Invocation.method(#updateProjectName, [id, newName]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);

  @override
  i3.Future<void> archiveProject(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#archiveProject, [id]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);

  @override
  i3.Future<void> unarchiveProject(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#unarchiveProject, [id]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);

  @override
  i3.Future<void> deleteProject(String? id) =>
      (super.noSuchMethod(
            Invocation.method(#deleteProject, [id]),
            returnValue: i3.Future<void>.value(),
            returnValueForMissingStub: i3.Future<void>.value(),
          )
          as i3.Future<void>);
}
