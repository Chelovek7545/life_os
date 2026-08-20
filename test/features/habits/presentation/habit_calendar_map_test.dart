import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_calendar_map.dart';

import '../../../test_helpers.dart';

void main() {
  group('HabitCalendarMap', () {
    final now = DateTime.now();
    final habit = Habit(
      id: 'h-1',
      title: 'Read',
      type: const MorningHabit(),
      schedule: const HabitSchedule(daysOfWeek: kAllWeekdays),
      colorHex: '#4FC3F7',
      createdAt: DateTime(now.year, now.month, 1),
      updatedAt: DateTime.now(),
    );

    Widget createMap({Set<String>? completed}) {
      return createTestWidget(
        child: HabitCalendarMap(
          habit: habit,
          completedDateKeys: completed ?? const {},
        ),
      );
    }

    testWidgets('renders current month title', (tester) async {
      await tester.pumpWidget(createMap());
      await tester.pump();

      const monthNames = [
        'Январь',
        'Февраль',
        'Март',
        'Апрель',
        'Май',
        'Июнь',
        'Июль',
        'Август',
        'Сентябрь',
        'Октябрь',
        'Ноябрь',
        'Декабрь',
      ];
      expect(
        find.text('${monthNames[now.month - 1]} ${now.year}'),
        findsOneWidget,
      );
    });

    testWidgets('shows completed days count', (tester) async {
      final yesterday = now.subtract(const Duration(days: 1));
      await tester.pumpWidget(
        createMap(completed: {formatDateKey(yesterday), formatDateKey(now)}),
      );
      await tester.pump();

      expect(find.text('2 дн.'), findsOneWidget);
    });

    testWidgets('shows habit title and icon', (tester) async {
      await tester.pumpWidget(createMap());
      await tester.pump();

      expect(find.text('Read'), findsOneWidget);
      expect(find.byIcon(Icons.task_alt), findsOneWidget);
    });
  });
}
