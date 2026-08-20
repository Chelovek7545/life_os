import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_streak.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/habits_calendar_panel.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_calendar_map.dart';
import 'package:rxdart/rxdart.dart';

import '../../../test_helpers.dart';

class FakeHabitsViewModel extends Fake implements HabitsViewModel {
  final BehaviorSubject<HabitsScreenState> _stateController;

  final Set<String> completedKeys;
  final List<(String habitId, DateTime date)> toggled = [];

  FakeHabitsViewModel({
    HabitsScreenState? initialState,
    this.completedKeys = const {},
  }) : _stateController = BehaviorSubject<HabitsScreenState>.seeded(
         initialState ?? const HabitsLoading(),
       );

  @override
  Stream<HabitsScreenState> get state => _stateController.stream;

  @override
  Set<String> completedDateKeysOf(String habitId) => completedKeys;

  @override
  Future<void> toggleHabit(Habit habit, DateTime date) async {
    toggled.add((habit.id, date));
  }

  @override
  void initialize() {}

  @override
  void dispose() {
    _stateController.close();
  }
}

HabitWithEntry habitWithEntry(Habit habit) {
  final now = DateTime.now();
  return HabitWithEntry(
    habit: habit,
    entry: null,
    streak: const HabitStreak(),
    isScheduled: habit.schedule.isScheduledOn(now),
    isExpired: !habit.schedule.isActiveOn(now, createdAt: habit.createdAt),
  );
}

void main() {
  group('HabitsCalendarPanel', () {
    late FakeHabitsViewModel viewModel;

    setUp(() {
      viewModel = FakeHabitsViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    Future<void> pumpPanel(WidgetTester tester, List<Habit> habits) async {
      viewModel._stateController.add(
        HabitsLoaded(habits: habits.map(habitWithEntry).toList()),
      );
      await tester.pumpWidget(
        createTestWidget(
          child: SizedBox(
            height: 500,
            child: HabitsCalendarPanel(viewModel: viewModel),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows empty message when no habits', (tester) async {
      await pumpPanel(tester, const []);

      expect(find.text('Привычек пока нет'), findsOneWidget);
    });

    testWidgets('shows a tab per habit and map of the first', (tester) async {
      await pumpPanel(tester, [
        Habit.create(title: 'Read', type: const MorningHabit()),
        Habit.create(title: 'Run', type: const EveningHabit()),
      ]);

      expect(find.byType(Tab), findsNWidgets(2));
      expect(find.byType(HabitCalendarMap), findsOneWidget);
      expect(find.text('Read'), findsWidgets);
    });

    testWidgets('tapping a tab switches the map', (tester) async {
      await pumpPanel(tester, [
        Habit.create(title: 'Read', type: const MorningHabit()),
        Habit.create(title: 'Run', type: const EveningHabit()),
      ]);

      await tester.tap(find.text('Run'));
      await tester.pumpAndSettle();

      expect(find.byType(HabitCalendarMap), findsOneWidget);
    });

    testWidgets('tapping a day toggles the habit for that date', (tester) async {
      final habit = Habit.create(title: 'Read', type: const MorningHabit());
      await pumpPanel(tester, [habit]);

      final today = DateTime.now();
      final key = ValueKey<String>(
        'habit-day-${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}',
      );
      await tester.tap(find.byKey(key));
      await tester.pump();

      final expectedDate = DateTime(today.year, today.month, today.day);
      expect(viewModel.toggled, [(habit.id, expectedDate)]);
    });

    testWidgets('renders inside CollapsibleSheet without layout errors',
        (tester) async {
      final habit = Habit.create(title: 'Read', type: const MorningHabit());
      viewModel._stateController.add(
        HabitsLoaded(habits: [habitWithEntry(habit)]),
      );
      await tester.pumpWidget(
        createTestWidget(
          child: SizedBox(
            width: 400,
            height: 500,
            child: CollapsibleSheet(
              snapPoints: const [60, 190, 400],
              initialHeight: 400,
              scrollableBody: false,
              header: const SizedBox(height: 60),
              bodyBuilder: (progress, snapIndex) =>
                  HabitsCalendarPanel(viewModel: viewModel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(HabitCalendarMap), findsOneWidget);
      expect(find.text('Тап по дню — отметить или снять выполнение'),
          findsOneWidget);
    });

    testWidgets('dragging to minimum does not overflow', (tester) async {
      final habit = Habit.create(title: 'Read', type: const MorningHabit());
      viewModel._stateController.add(
        HabitsLoaded(habits: [habitWithEntry(habit)]),
      );
      await tester.pumpWidget(
        createTestWidget(
          child: SizedBox(
            width: 400,
            height: 500,
            child: CollapsibleSheet(
              snapPoints: const [60, 190, 400],
              initialHeight: 400,
              scrollableBody: false,
              header: const SizedBox(width: double.infinity, height: 60),
              bodyBuilder: (progress, snapIndex) =>
                  HabitsCalendarPanel(viewModel: viewModel),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Свайп вниз до минимума: тело шторки сжимается до нулевой высоты.
      await tester.dragFrom(const Offset(200, 130), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
