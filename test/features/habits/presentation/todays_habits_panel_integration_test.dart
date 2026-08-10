import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/habits/data/habits_dao.dart';
import 'package:life_os/features/habits/data/habits_repository.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';

import '../../../test_helpers.dart';

void main() {
  testWidgets('toggle updates the card after the DB round trip', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db));
    final vm = HabitsViewModel(repo);

    final weekday = DateTime.now().weekday;
    await repo.addHabit(
      Habit.create(
        title: 'Read',
        type: const MorningHabit(),
        schedule: HabitSchedule(daysOfWeek: [weekday]),
      ),
    );

    vm.initialize();

    await tester.pumpWidget(
      createTestWidget(
        child: TodaysHabitsPanel(viewModel: vm, expand: false),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Read'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    await tester.tap(find.byTooltip('Toggle'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    // Повторный тап возвращает в pending.
    await tester.tap(find.byTooltip('Toggle'));
    await tester.pump();
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    vm.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await db.close();
  });

  testWidgets('skip is toggleable back to pending', (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = HabitsRepository(HabitsDao(db));
    final vm = HabitsViewModel(repo);

    final weekday = DateTime.now().weekday;
    await repo.addHabit(
      Habit.create(
        title: 'Read',
        type: const MorningHabit(),
        schedule: HabitSchedule(daysOfWeek: [weekday]),
      ),
    );

    vm.initialize();
    await tester.pumpWidget(
      createTestWidget(
        child: TodaysHabitsPanel(viewModel: vm, expand: false),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byTooltip('Skip'));
    await tester.pump();
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    // Кнопка остаётся активной — повторный тап снимает пропуск.
    final skipButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.block_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(skipButton.onPressed, isNotNull);

    await tester.tap(find.byTooltip('Skip'));
    await tester.pump();
    expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget);

    vm.dispose();
    await tester.pump(const Duration(milliseconds: 10));
    await db.close();
  });
}
