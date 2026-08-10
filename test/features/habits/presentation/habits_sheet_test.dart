import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_streak.dart';
import 'package:life_os/features/habits/domain/habit_type.dart';
import 'package:life_os/features/habits/presentation/habits_sheet.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_edit_form.dart';
import 'package:rxdart/rxdart.dart';

import '../../../test_helpers.dart';

class FakeHabitsViewModel extends Fake implements HabitsViewModel {
  final BehaviorSubject<HabitsScreenState> _stateController;
  final BehaviorSubject<DateTime> _dateController;
  final BehaviorSubject<bool> _formController;

  final List<String> savedTitles = [];

  @override
  Habit? editingHabit;

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
  Future<void> toggleHabit(Habit habit, DateTime date) async {}

  @override
  Future<void> skipHabit(Habit habit, DateTime date) async {}

  @override
  Future<void> saveDraft(Habit habit) async {
    savedTitles.add(habit.title);
  }

  @override
  Future<void> deleteEditingHabit() async {}

  @override
  void showForm() {}

  @override
  void hideForm() {}

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

void main() {
  group('showAllHabitsSheet', () {
    late FakeHabitsViewModel viewModel;

    setUp(() {
      viewModel = FakeHabitsViewModel();
    });

    tearDown(() {
      viewModel.dispose();
    });

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAllHabitsSheet(
                context: context,
                viewModel: viewModel,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
    }

    void emitLoaded(List<Habit> habits) {
      viewModel._stateController.add(
        HabitsLoaded(
          habits: habits.map((h) => habitWithEntry(habit: h)).toList(),
        ),
      );
    }

    testWidgets('shows all habits regardless of schedule', (tester) async {
      emitLoaded([
        Habit.create(title: 'Every day habit', type: const MorningHabit()),
        Habit.create(title: 'Sunday habit', type: const LunchHabit()),
      ]);
      await openSheet(tester);

      expect(find.text('Every day habit'), findsOneWidget);
      expect(find.text('Sunday habit'), findsOneWidget);
    });

    testWidgets('shows empty message when no habits', (tester) async {
      emitLoaded(const []);
      await openSheet(tester);

      expect(find.text('Привычек пока нет'), findsOneWidget);
    });

    testWidgets('add button opens new habit form', (tester) async {
      emitLoaded(const []);
      await openSheet(tester);

      await tester.tap(find.byTooltip('New habit'));
      await tester.pumpAndSettle();

      expect(find.text('New habit'), findsOneWidget);
      expect(find.byType(HabitEditForm), findsOneWidget);
    });

    testWidgets('tapping a habit opens edit form', (tester) async {
      final habit = Habit.create(title: 'Read', type: const MorningHabit());
      emitLoaded([habit]);
      await openSheet(tester);

      await tester.tap(find.text('Read'));
      await tester.pumpAndSettle();

      expect(find.text('Edit habit'), findsOneWidget);
    });

    testWidgets('saving new habit from form calls view model', (tester) async {
      emitLoaded(const []);
      await openSheet(tester);

      await tester.tap(find.byTooltip('New habit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Drink water');
      final formScrollable = find
          .descendant(
            of: find.byType(HabitEditForm),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.text('Save'),
        300,
        scrollable: formScrollable,
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(viewModel.savedTitles, ['Drink water']);
    });
  });
}
