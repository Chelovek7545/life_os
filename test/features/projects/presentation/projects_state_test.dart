import 'package:life_os/features/projects/presentation/projects_state.dart';
import 'package:test/test.dart';

import '../../../test_helpers.dart';

void main() {
  group('ProjectsScreenState', () {
    group('ProjectsLoading', () {
      test('isLoading returns true', () {
        const state = ProjectsLoading();
        expect(state.isLoading, isTrue);
        expect(state.isLoaded, isFalse);
        expect(state.isError, isFalse);
      });

      test('when calls loading callback', () {
        const state = ProjectsLoading();
        final result = state.when(
          loading: () => 'loading',
          loaded: (_, __, ___) => 'loaded',
          error: (_) => 'error',
        );
        expect(result, 'loading');
      });

      test('maybeWhen calls loading callback', () {
        const state = ProjectsLoading();
        final result = state.maybeWhen(
          loading: () => 'loading',
          orElse: () => 'orElse',
        );
        expect(result, 'loading');
      });

      test('maybeWhen falls back to orElse when no match', () {
        const state = ProjectsLoading();
        final result = state.maybeWhen(
          loaded: (_, __, ___) => 'loaded',
          orElse: () => 'orElse',
        );
        expect(result, 'orElse');
      });
    });

    group('ProjectsLoaded', () {
      final projects = [
        createMockProject(name: 'Project A'),
        createMockProject(name: 'Project B'),
      ];

      test('isLoaded returns true', () {
        final state = ProjectsLoaded(projects: projects);
        expect(state.isLoaded, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isError, isFalse);
      });

      test('stores projects and curProject', () {
        final state = ProjectsLoaded(
          projects: projects,
          curProject: projects.first,
          isProcessing: true,
        );
        expect(state.projects, projects);
        expect(state.curProject, projects.first);
        expect(state.isProcessing, isTrue);
      });

      test('isProcessing defaults to false', () {
        final state = ProjectsLoaded(projects: projects);
        expect(state.isProcessing, isFalse);
      });

      test('curProject defaults to null', () {
        final state = ProjectsLoaded(projects: projects);
        expect(state.curProject, isNull);
      });

      test('when calls loaded callback', () {
        final state = ProjectsLoaded(projects: projects);
        final result = state.when(
          loading: () => 'loading',
          loaded: (p, _, __) => 'loaded:${p.length}',
          error: (_) => 'error',
        );
        expect(result, 'loaded:2');
      });

      test('maybeWhen calls loaded callback', () {
        final state = ProjectsLoaded(projects: projects);
        final result = state.maybeWhen(
          loaded: (_, __, ___) => 'loaded',
          orElse: () => 'orElse',
        );
        expect(result, 'loaded');
      });
    });

    group('ProjectsError', () {
      test('isError returns true', () {
        const state = ProjectsError('error');
        expect(state.isError, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isLoaded, isFalse);
      });

      test('stores message', () {
        const state = ProjectsError('Something went wrong');
        expect(state.message, 'Something went wrong');
      });

      test('when calls error callback', () {
        const state = ProjectsError('fail');
        final result = state.when(
          loading: () => 'loading',
          loaded: (_, __, ___) => 'loaded',
          error: (msg) => 'error:$msg',
        );
        expect(result, 'error:fail');
      });
    });
  });
}
