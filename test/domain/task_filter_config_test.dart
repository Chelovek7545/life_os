import 'package:life_os/features/tasks/domain/task_filter_config.dart';
import 'package:test/test.dart';

void main() {
  group('TaskFilterConfig', () {
    group('constructor', () {
      test('creates with required anchorDate and defaults', () {
        final date = DateTime(2024, 1, 15);
        final config = TaskFilterConfig(anchorDate: date);

        expect(config.anchorDate, date);
        expect(config.period, DatePeriod.day);
        expect(config.projectIds, isEmpty);
        expect(config.tagIds, isEmpty);
        expect(config.showCompleted, isNull);
      });

      test('creates with all fields specified', () {
        final date = DateTime(2024, 1, 15);
        final config = TaskFilterConfig(
          anchorDate: date,
          period: DatePeriod.week,
          projectIds: ['proj-1', 'proj-2'],
          tagIds: [1, 2, 3],
          showCompleted: true,
        );

        expect(config.anchorDate, date);
        expect(config.period, DatePeriod.week);
        expect(config.projectIds, ['proj-1', 'proj-2']);
        expect(config.tagIds, [1, 2, 3]);
        expect(config.showCompleted, true);
      });
    });

    group('copyWith', () {
      test('updates anchorDate', () {
        final config = TaskFilterConfig(anchorDate: DateTime(2024, 1, 1));
        final updated = config.copyWith(anchorDate: DateTime(2024, 2, 1));

        expect(updated.anchorDate, DateTime(2024, 2, 1));
        expect(updated.period, config.period);
        expect(updated.projectIds, config.projectIds);
      });

      test('updates period', () {
        final config = TaskFilterConfig(anchorDate: DateTime.now());
        final updated = config.copyWith(period: DatePeriod.month);

        expect(updated.period, DatePeriod.month);
        expect(updated.anchorDate, config.anchorDate);
      });

      test('updates projectIds', () {
        final config = TaskFilterConfig(anchorDate: DateTime.now());
        final updated = config.copyWith(projectIds: ['p1', 'p2']);

        expect(updated.projectIds, ['p1', 'p2']);
      });

      test('updates tagIds', () {
        final config = TaskFilterConfig(anchorDate: DateTime.now());
        final updated = config.copyWith(tagIds: [10, 20]);

        expect(updated.tagIds, [10, 20]);
      });

      test('updates showCompleted to true', () {
        final config = TaskFilterConfig(anchorDate: DateTime.now());
        final updated = config.copyWith(showCompleted: () => true);

        expect(updated.showCompleted, true);
      });

      test('updates showCompleted to false', () {
        final config = TaskFilterConfig(
          anchorDate: DateTime.now(),
          showCompleted: true,
        );
        final updated = config.copyWith(showCompleted: () => false);

        expect(updated.showCompleted, false);
      });

      test('resets showCompleted to null using function', () {
        final config = TaskFilterConfig(
          anchorDate: DateTime.now(),
          showCompleted: true,
        );
        final updated = config.copyWith(showCompleted: () => null);

        expect(updated.showCompleted, isNull);
      });

      test('preserves showCompleted when not provided', () {
        final config = TaskFilterConfig(
          anchorDate: DateTime.now(),
          showCompleted: true,
        );
        final updated = config.copyWith(period: DatePeriod.week);

        expect(updated.showCompleted, true);
      });

      test('updates multiple fields at once', () {
        final config = TaskFilterConfig(anchorDate: DateTime(2024, 1, 1));
        final updated = config.copyWith(
          anchorDate: DateTime(2024, 6, 15),
          period: DatePeriod.year,
          projectIds: ['new-proj'],
          tagIds: [99],
          showCompleted: () => false,
        );

        expect(updated.anchorDate, DateTime(2024, 6, 15));
        expect(updated.period, DatePeriod.year);
        expect(updated.projectIds, ['new-proj']);
        expect(updated.tagIds, [99]);
        expect(updated.showCompleted, false);
      });

      test('returns new instance (immutability)', () {
        final config = TaskFilterConfig(anchorDate: DateTime.now());
        final updated = config.copyWith(period: DatePeriod.week);

        expect(identical(config, updated), isFalse);
        expect(config.period, DatePeriod.day);
        expect(updated.period, DatePeriod.week);
      });
    });

    group('DatePeriod', () {
      test('has all expected values', () {
        expect(DatePeriod.values, [
          DatePeriod.day,
          DatePeriod.week,
          DatePeriod.month,
          DatePeriod.year,
        ]);
      });
    });

    group('equality', () {
      test('equal configs are equal', () {
        final date = DateTime(2024, 1, 15);
        final config1 = TaskFilterConfig(
          anchorDate: date,
          period: DatePeriod.week,
          projectIds: ['p1'],
          tagIds: [1],
          showCompleted: true,
        );
        final config2 = TaskFilterConfig(
          anchorDate: date,
          period: DatePeriod.week,
          projectIds: ['p1'],
          tagIds: [1],
          showCompleted: true,
        );

        expect(config1, config2);
        expect(config1.hashCode, config2.hashCode);
      });

      test('different configs are not equal', () {
        final config1 = TaskFilterConfig(anchorDate: DateTime(2024, 1, 1));
        final config2 = TaskFilterConfig(anchorDate: DateTime(2024, 1, 2));

        expect(config1, isNot(config2));
      });
    });
  });
}
