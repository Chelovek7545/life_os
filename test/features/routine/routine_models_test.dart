import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/routine/domain/routine_models.dart';

void main() {
  test('copy weekday replaces target without changing source identities', () {
    final items = [
      RoutineItem(
        id: 'read',
        title: 'Read',
        slots: [
          RoutineSlot(id: 'mon', days: [1], start: 600, end: 630),
        ],
      ),
      RoutineItem(
        id: 'old',
        title: 'Old Tuesday',
        slots: [
          RoutineSlot(id: 'tue', days: [2]),
        ],
      ),
    ];
    final result = copyRoutineDay(items, 1, {2, 4});
    expect(result, hasLength(1));
    expect(result.single.id, 'read');
    expect(result.single.slots.first.id, 'mon');
    expect(result.single.slots.last.days, [2, 4]);
    expect(result.single.slots.last.id, isNot('mon'));
    expect(items.last.slots.single.days, [2]);
    expect(() => validateRoutineItems(result), returnsNormally);
  });
  RoutineOccurrence occurrence(
    String id,
    int day, {
    bool done = false,
    bool cancelled = false,
    int? start = 600,
    int? end = 660,
    String itemId = 'item',
  }) => RoutineOccurrence(
    id: id,
    date: DateTime(2026, 9, day),
    templateId: 't',
    item: RoutineItem(id: itemId, title: 'Занятие', slots: const []),
    slot: RoutineSlot(id: id, days: [1], start: start, end: end),
    completed: done,
    cancelled: cancelled,
  );
  test('weighted aggregate uses counts, not average day percentages', () {
    final s = RoutineStats([
      occurrence('a', 1, done: true),
      occurrence('b', 1, done: true),
      occurrence('c', 1, done: true),
      occurrence('d', 1),
      occurrence('e', 2, done: true),
      occurrence('f', 2),
      occurrence('g', 2, cancelled: true),
    ]);
    expect(s.total, 6);
    expect(s.done, 4);
    expect(s.rate, closeTo(2 / 3, .0001));
    expect(s.cancelled, 1);
    expect(s.doneMinutes, 240);
  });
  test('untimed and cancelled entries never create phantom minutes', () {
    final s = RoutineStats([
      occurrence('a', 1, done: true, start: null, end: null),
      occurrence('b', 1, cancelled: true),
    ]);
    expect(s.done, 1);
    expect(s.doneMinutes, 0);
    expect(s.plannedMinutes, 0);
  });
  test('empty denominator is null', () {
    expect(RoutineStats([]).rate, isNull);
    expect(RoutineStats([occurrence('x', 1, cancelled: true)]).rate, isNull);
  });
  test(
    'series ignores free dates and cancellations; today can remain pending',
    () {
      final s = RoutineStats([
        occurrence('a', 1, done: true),
        occurrence('b', 3, cancelled: true),
        occurrence('c', 5, done: true),
        occurrence('d', 7),
      ]);
      expect(s.streak('item', DateTime(2026, 9, 7)), (2, 2));
      expect(s.streak('item', DateTime(2026, 9, 8)), (0, 2));
    },
  );
  test('all slots of a day are needed to continue a streak', () {
    final s = RoutineStats([
      occurrence('a', 1, done: true),
      occurrence('b', 1),
      occurrence('c', 2, done: true),
    ]);
    expect(s.streak('item', DateTime(2026, 9, 3)), (1, 1));
  });
  test('night belongs to start date and has one duration', () {
    final o = occurrence('night', 1, start: 1380, end: 1500, done: true);
    expect(o.endsAt, DateTime(2026, 9, 2, 1));
    expect(RoutineStats([o]).doneMinutes, 120);
    expect(RoutineStats([o]).days.keys, ['2026-09-01']);
  });
  test('demo schedule has no overlaps and multiple spheres', () {
    final items = exampleRoutineItems();
    expect(() => validateRoutineItems(items), returnsNormally);
    expect(items.map((i) => i.sphere).toSet().length, greaterThan(3));
  });
  test('invalid time and title are rejected', () {
    for (final item in [
      RoutineItem(
        id: 'a',
        title: '',
        slots: [
          RoutineSlot(id: 's', days: [1]),
        ],
      ),
      RoutineItem(
        id: 'a',
        title: 'Title',
        slots: [
          RoutineSlot(id: 's', days: [1], start: 600, end: 500),
        ],
      ),
    ]) {
      expect(() => validateRoutineItems([item]), throwsFormatException);
    }
  });
  test('resolver does not multiply data for additional board views', () {
    final item = RoutineItem(
      id: 'a',
      title: 'Test',
      slots: [
        RoutineSlot(id: 's', days: [1]),
      ],
    );
    final data = RoutineSnapshot(
      versions: {
        'v': [item],
      },
      activations: [
        RoutineActivation(
          id: 'a',
          versionId: 'v',
          templateId: 't',
          from: DateTime(2026, 9, 7),
        ),
      ],
    );
    final a = data.resolve(DateTime(2026, 9, 7), DateTime(2026, 9, 14));
    final b = data.resolve(DateTime(2026, 9, 7), DateTime(2026, 9, 14));
    expect(a.map((o) => o.id), b.map((o) => o.id));
    expect(a.length, 2);
  });
}
