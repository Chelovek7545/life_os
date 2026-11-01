import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import '../../../support/test_app.dart';

void main() {
  testWidgets('toggle works in the full app', (tester) async {
    final container = (await tester.runAsync(createTestApp))!;
    await tester.runAsync(
      () => container.habitsRepository.addHabit(
        Habit.create(
          title: 'Read',
          type: const MorningHabit(),
          schedule: HabitSchedule(daysOfWeek: [DateTime.now().weekday]),
        ),
      ),
    );
    await tester.runAsync(
      () => container.habitsViewModel.state.firstWhere(
        (state) => state is HabitsLoaded && state.habits.isNotEmpty,
      ),
    );
    await tester.pumpWidget(MyApp(diContainer: container));
    await tester.pump();
    await tester.pump();
    expect(find.text('Read'), findsOneWidget);
    await tester.tap(find.byTooltip('Toggle').first);
    await tester.pump();
    await tester.runAsync(
      () => container.habitsViewModel.state.firstWhere(
        (state) => state is HabitsLoaded && state.habits.single.isCompleted,
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsWidgets);
    await disposeTestApp(tester, container);
  });
}
