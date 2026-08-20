import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';

void main() {
  group('habitTypeFromStorage', () {
    test('morning', () {
      final type = habitTypeFromStorage(HabitTypeKind.morning);
      expect(type, isA<MorningHabit>());
      expect(type.label, 'Morning');
    });

    test('lunch', () {
      expect(habitTypeFromStorage(HabitTypeKind.lunch), isA<LunchHabit>());
    });

    test('evening', () {
      expect(habitTypeFromStorage(HabitTypeKind.evening), isA<EveningHabit>());
    });

    test('time with stored string', () {
      final type = habitTypeFromStorage(HabitTypeKind.time, time: '21:30');
      expect(type, isA<TimeHabit>());
      final timeHabit = type as TimeHabit;
      expect(timeHabit.time.hour, 21);
      expect(timeHabit.time.minute, 30);
      expect(timeHabit.formatTime, '21:30');
      expect(timeHabit.timeLabel, '21:30');
    });

    test('time without stored string falls back to 09:00', () {
      final type = habitTypeFromStorage(HabitTypeKind.time) as TimeHabit;
      expect(type.formatTime, '09:00');
    });
  });

  group('formatStoredTime', () {
    test('pads single digits', () {
      expect(
        formatStoredTime(const TimeOfDay(hour: 9, minute: 5)),
        '09:05',
      );
    });
  });

  group('HabitType equality', () {
    test('same kind and time are equal', () {
      expect(const MorningHabit(), const MorningHabit());
      expect(
        const TimeHabit(time: TimeOfDay(hour: 9, minute: 0)),
        const TimeHabit(time: TimeOfDay(hour: 9, minute: 0)),
      );
    });

    test('different time is not equal', () {
      expect(
        const TimeHabit(time: TimeOfDay(hour: 9, minute: 0)),
        isNot(const TimeHabit(time: TimeOfDay(hour: 10, minute: 0))),
      );
    });
  });
}
