import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_schedule.dart';
import 'package:life_os/features/habits/domain/habit_streak.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';
import 'package:rxdart/rxdart.dart';

import '../../../test_helpers.dart';

class FakeHabitsViewModel extends Fake implements HabitsViewModel {
  final BehaviorSubject<HabitsScreenState> _stateController;
  final BehaviorSubject<DateTime> _dateController;
  final BehaviorSubject<bool> _formController;

  final List<String> toggledHabitIds = [];
  final List<String> skippedHabitIds = [];

  FakeHabitsViewModel({HabitsScreenState? initialState})
    : _stateController = BehaviorSubject<HabitsScreenState>.seeded(
        initialState ?? const HabitsLoading(),
      ),
      _dateController = BehaviorSubject<DateTime>.seeded(DateTime.now()),
      _formController = BehaviorSubject<bool>.seeded(false);

  @override
  Stream<HabitsScreenState> get state => _stateController.stream;

  @override
  Stream<DateTime> get selectedDateStream => _dateController.stream;

  @override
  DateTime get selectedDate => _dateController.value;

  @override
  Stream<bool> get isFormVisibleStream => _formController.stream;

  @override
  bool get isFormVisible => _formController.value;

  @override
  void initialize() {}

  @override
  void selectDate(DateTime date) {
    _dateController.add(date);
  }

  @override
  void dispose() {
    _stateController.close();
    _dateController.close();
    _formController.close();
  }

  @override
  Future<void> toggleHabit(Habit habit, DateTime date) async {
    toggledHabitIds.add(habit.id);
  }

  @override
  Future<void> skipHabit(Habit habit, DateTime date) async {
    skippedHabitIds.add(habit.id);
  }

  @override
  Future<void> saveDraft(Habit habit) async {}

  @override
  Future<void> deleteEditingHabit() async {}

  @override
  void showForm() {}

  @override
  void hideForm() {}

  @override
  Set<String> completedDateKeysOf(String habitId) => const {};

  @override
  void startEditing(Habit habit) {}
}

HabitWithEntry habitWithEntry({required Habit habit}) {
  final now = DateTime.now();
  return HabitWithEntry(
    habit: habit,
    entry: null,
    streak: const HabitStreak(),
    isScheduled: habit.schedule.isScheduledOn(now),
    isExpired: !habit.schedule.isActiveOn(now, createdAt: habit.createdAt),
  );
}

int get _todayWeekday => DateTime.now().weekday;

void main() {
  group('TodaysHabitsPanel', () {
    late FakeHabitsViewModel viewModel;

    setUp(() {
      viewModel = FakeHabitsViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    bool calendarOpened = false;

    Widget createWidget() {
      return createTestWidget(
        child: TodaysHabitsPanel(
          viewModel: viewModel,
          onOpenCalendar: () => calendarOpened = true,
          expand: false,
        ),
      );
    }

    void emitLoaded(List<Habit> habits) {
      viewModel._stateController.add(
        HabitsLoaded(
          habits: habits.map((h) => habitWithEntry(habit: h)).toList(),
        ),
      );
    }

    Habit habitScheduledToday({String title = 'Read', DateTime? createdAt}) {
      return Habit.create(
        title: title,
        type: const MorningHabit(),
        schedule: HabitSchedule(daysOfWeek: [_todayWeekday]),
      );
    }

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(createWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty message when no habits for today', (tester) async {
      emitLoaded(const []);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('На сегодня привычек нет'), findsOneWidget);
    });

    testWidgets('shows only habits scheduled today', (tester) async {
      final otherWeekday =
          _todayWeekday == 1 ? 2 : 1; // любой день, отличный от сегодняшнего
      emitLoaded([
        habitScheduledToday(title: 'Today habit'),
        Habit.create(
          title: 'Other day habit',
          type: const EveningHabit(),
          schedule: HabitSchedule(daysOfWeek: [otherWeekday]),
        ),
      ]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Today habit'), findsOneWidget);
      expect(find.text('Other day habit'), findsNothing);
    });

    testWidgets('hides expired habits', (tester) async {
      final expired = Habit(
        id: 'expired-habit',
        title: 'Expired habit',
        type: const MorningHabit(),
        schedule: HabitSchedule(
          daysOfWeek: [_todayWeekday],
          durationWeeks: 1,
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
        updatedAt: DateTime.now(),
      );
      emitLoaded([habitScheduledToday(), expired]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('Expired habit'), findsNothing);
      expect(find.text('Read'), findsOneWidget);
    });

    testWidgets('tapping toggle calls view model', (tester) async {
      final habit = habitScheduledToday();
      emitLoaded([habit]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.tap(find.byTooltip('Toggle'));
      await tester.pump();

      expect(viewModel.toggledHabitIds, [habit.id]);
    });

    testWidgets('tapping skip calls view model', (tester) async {
      final habit = habitScheduledToday();
      emitLoaded([habit]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.tap(find.byTooltip('Skip'));
      await tester.pump();

      expect(viewModel.skippedHabitIds, [habit.id]);
    });

    testWidgets('map button opens habit calendar', (tester) async {
      emitLoaded([habitScheduledToday()]);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      await tester.tap(find.byTooltip('Карта выполненных дней'));
      await tester.pump();

      expect(calendarOpened, isTrue);
    });
  });
}
