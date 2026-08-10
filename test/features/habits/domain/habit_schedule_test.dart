import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';

void main() {
  group('encode/decodeDaysOfWeek', () {
    test('round trip for all days', () {
      expect(decodeDaysOfWeek(encodeDaysOfWeek(kAllWeekdays)), kAllWeekdays);
    });

    test('round trip for Mon/Wed/Fri', () {
      const days = [1, 3, 5];
      expect(decodeDaysOfWeek(encodeDaysOfWeek(days)), days);
    });

    test('empty mask falls back to all days', () {
      expect(decodeDaysOfWeek(0), kAllWeekdays);
    });
  });

  group('HabitSchedule.isScheduledOn', () {
    test('matches weekday', () {
      const schedule = HabitSchedule(daysOfWeek: [1, 3, 5]);
      // 2026-08-10 is a Monday
      expect(schedule.isScheduledOn(DateTime(2026, 8, 10)), isTrue);
      // 2026-08-11 is a Tuesday
      expect(schedule.isScheduledOn(DateTime(2026, 8, 11)), isFalse);
    });
  });

  group('HabitSchedule.isActiveOn', () {
    final createdAt = DateTime(2026, 8, 1);

    test('repeating habit is always active', () {
      const schedule = HabitSchedule(daysOfWeek: [1]);
      expect(schedule.isActiveOn(DateTime(2026, 9, 15), createdAt: createdAt), isTrue);
    });

    test('finite habit expires after durationWeeks', () {
      const schedule = HabitSchedule(daysOfWeek: [1], durationWeeks: 1);
      // Day 1 active
      expect(schedule.isActiveOn(DateTime(2026, 8, 1), createdAt: createdAt), isTrue);
      // Day 7 active (end of week 1)
      expect(schedule.isActiveOn(DateTime(2026, 8, 7), createdAt: createdAt), isTrue);
      // Day 8 expired
      expect(schedule.isActiveOn(DateTime(2026, 8, 8), createdAt: createdAt), isFalse);
    });

    test('not active before creation', () {
      const schedule = HabitSchedule(daysOfWeek: [1], durationWeeks: 2);
      expect(schedule.isActiveOn(DateTime(2026, 7, 30), createdAt: createdAt), isFalse);
    });
  });

  group('copyWith', () {
    test('clears duration when requested', () {
      const schedule = HabitSchedule(daysOfWeek: [1], durationWeeks: 2);
      final cleared = schedule.copyWith(clearDurationWeeks: true);
      expect(cleared.durationWeeks, isNull);
    });
  });
}
