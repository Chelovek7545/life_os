import 'package:flutter/material.dart';
import 'package:life_os/features/dashboard/domain/dashboard_card_item.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen_state.dart';
import 'package:test/test.dart';

void main() {
  group('DashboardScreenState', () {
    group('when', () {
      test('initial calls initial callback', () {
        const state = DashboardScreenInitial();
        final result = state.when(
          initial: () => 'initial',
          loading: () => 'loading',
          loaded: (_) => 'loaded',
          error: (_) => 'error',
        );
        expect(result, 'initial');
      });

      test('loading calls loading callback', () {
        const state = DashboardScreenLoading();
        final result = state.when(
          initial: () => 'initial',
          loading: () => 'loading',
          loaded: (_) => 'loaded',
          error: (_) => 'error',
        );
        expect(result, 'loading');
      });

      test('loaded calls loaded callback with items', () {
        final items = [
          const DashboardCardItem(
            icon: Icons.task_alt,
            title: 'Tasks',
            value: '5',
          ),
        ];
        final state = DashboardScreenLoaded(items);
        final result = state.when(
          initial: () => 'initial',
          loading: () => 'loading',
          loaded: (i) => 'loaded:${i.length}',
          error: (_) => 'error',
        );
        expect(result, 'loaded:1');
      });

      test('error calls error callback with message', () {
        const state = DashboardScreenError('oops');
        final result = state.when(
          initial: () => 'initial',
          loading: () => 'loading',
          loaded: (_) => 'loaded',
          error: (msg) => 'error:$msg',
        );
        expect(result, 'error:oops');
      });
    });

    group('maybeWhen', () {
      test('initial calls initial callback when provided', () {
        const state = DashboardScreenInitial();
        final result = state.maybeWhen(
          initial: () => 'initial',
          orElse: () => 'fallback',
        );
        expect(result, 'initial');
      });

      test('initial falls back to orElse when handler missing', () {
        const state = DashboardScreenInitial();
        final result = state.maybeWhen(
          loading: () => 'loading',
          orElse: () => 'fallback',
        );
        expect(result, 'fallback');
      });
    });

    group('type checks', () {
      test('is DashboardScreenLoading', () {
        expect(const DashboardScreenLoading(), isA<DashboardScreenLoading>());
      });

      test('is DashboardScreenInitial', () {
        expect(const DashboardScreenInitial(), isA<DashboardScreenInitial>());
      });

      test('is DashboardScreenLoaded', () {
        expect(DashboardScreenLoaded([]), isA<DashboardScreenLoaded>());
      });

      test('is DashboardScreenError', () {
        expect(const DashboardScreenError('err'), isA<DashboardScreenError>());
      });
    });
  });
}
