import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/domain/use_cases/get_tasks_with_projects_use_case.dart';
import 'package:life_os/features/tasks/presentation/task_state.dart';
import 'package:test/test.dart';

import '../../../test_helpers.dart';

void main() {
  group('TaskScreenState', () {
    group('TasksLoading', () {
      test('isLoading returns true', () {
        const state = TasksLoading();
        expect(state.isLoading, isTrue);
        expect(state.isEmpty, isFalse);
        expect(state.isLoaded, isFalse);
        expect(state.isError, isFalse);
      });

      test('when calls loading callback', () {
        const state = TasksLoading();
        final result = state.when(
          loading: () => 'loading',
          empty: (_, __) => 'empty',
          loaded: (_, __, ___, ____) => 'loaded',
          error: (_) => 'error',
        );
        expect(result, 'loading');
      });

      test('maybeWhen calls loading callback', () {
        const state = TasksLoading();
        final result = state.maybeWhen(
          loading: () => 'loading',
          orElse: () => 'orElse',
        );
        expect(result, 'loading');
      });

      test('maybeWhen falls back to orElse when no match', () {
        const state = TasksLoading();
        final result = state.maybeWhen(
          loaded: (_, __, ___, ____) => 'loaded',
          orElse: () => 'orElse',
        );
        expect(result, 'orElse');
      });
    });

    group('TasksEmpty', () {
      test('isEmpty returns true', () {
        const state = TasksEmpty();
        expect(state.isEmpty, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isLoaded, isFalse);
        expect(state.isError, isFalse);
      });

      test('aiSuggestion defaults to null', () {
        const state = TasksEmpty();
        expect(state.aiSuggestion, isNull);
        expect(state.isProcessing, isFalse);
      });

      test('stores aiSuggestion and isProcessing', () {
        const state = TasksEmpty(aiSuggestion: 'Try x', isProcessing: true);
        expect(state.aiSuggestion, 'Try x');
        expect(state.isProcessing, isTrue);
      });

      test('when calls empty callback', () {
        const state = TasksEmpty(aiSuggestion: 'test');
        final result = state.when(
          loading: () => 'loading',
          empty: (aiSuggestion, isProcessing) => 'empty:$aiSuggestion',
          loaded: (_, __, ___, ____) => 'loaded',
          error: (_) => 'error',
        );
        expect(result, 'empty:test');
      });
    });

    group('TasksLoaded', () {
      final task = createMockTask();
      final tasks = [createMockTaskWithProject(task: task)];

      test('isLoaded returns true', () {
        final state = TasksLoaded(tasks: tasks, selectedTasks: []);
        expect(state.isLoaded, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isEmpty, isFalse);
        expect(state.isError, isFalse);
      });

      test('stores tasks and selectedTasks', () {
        final state = TasksLoaded(
          tasks: tasks,
          selectedTasks: [task],
          isProcessing: true,
          curTask: task,
        );
        expect(state.tasks, tasks);
        expect(state.selectedTasks, [task]);
        expect(state.isProcessing, isTrue);
        expect(state.curTask, task);
      });

      test('isProcessing defaults to false', () {
        final state = TasksLoaded(tasks: tasks, selectedTasks: []);
        expect(state.isProcessing, isFalse);
      });

      test('curTask defaults to null', () {
        final state = TasksLoaded(tasks: tasks, selectedTasks: []);
        expect(state.curTask, isNull);
      });

      test('when calls loaded callback', () {
        final state = TasksLoaded(
          tasks: tasks,
          selectedTasks: [task],
          curTask: task,
        );
        final result = state.when(
          loading: () => 'loading',
          empty: (_, __) => 'empty',
          loaded: (t, s, p, c) => 'loaded:${t.length}:${s.length}',
          error: (_) => 'error',
        );
        expect(result, 'loaded:1:1');
      });

      test('maybeWhen calls loaded callback', () {
        final state = TasksLoaded(tasks: tasks, selectedTasks: []);
        final result = state.maybeWhen(
          loaded: (_, __, ___, ____) => 'loaded',
          orElse: () => 'orElse',
        );
        expect(result, 'loaded');
      });
    });

    group('TasksError', () {
      test('isError returns true', () {
        const state = TasksError('error');
        expect(state.isError, isTrue);
        expect(state.isLoading, isFalse);
        expect(state.isEmpty, isFalse);
        expect(state.isLoaded, isFalse);
      });

      test('stores message', () {
        const state = TasksError('Something went wrong');
        expect(state.message, 'Something went wrong');
      });

      test('when calls error callback', () {
        const state = TasksError('fail');
        final result = state.when(
          loading: () => 'loading',
          empty: (_, __) => 'empty',
          loaded: (_, __, ___, ____) => 'loaded',
          error: (msg) => 'error:$msg',
        );
        expect(result, 'error:fail');
      });
    });
  });
}
