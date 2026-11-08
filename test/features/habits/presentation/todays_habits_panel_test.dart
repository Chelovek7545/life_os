import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/settings/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_logic.dart';
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
  Future<void> dispose() async {
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

    testWidgets(
      'scrolling and stretching habits do not paint over the header',
      (tester) async {
        emitLoaded(
          List.generate(12, (i) => habitScheduledToday(title: 'Habit $i')),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            scrollBehavior: const AppScrollBehavior(),
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: Colors.black,
                    child: SizedBox(
                      width: 360,
                      height: 320,
                      child: TodaysHabitsPanel(
                        viewModel: viewModel,
                        onOpenCalendar: () {},
                        onEditHabits: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byType(ListView);
        final top =
            tester.getTopLeft(list).dy - tester.getTopLeft(find.byKey(key)).dy;
        final titleBottom =
            tester.getBottomLeft(find.text('Habits')).dy -
            tester.getTopLeft(find.byKey(key)).dy;
        expect(top - titleBottom, greaterThanOrEqualTo(8));
        Future<List<int>> headerPixels() async =>
            (await tester.runAsync(() async {
              final image =
                  await (key.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = (await image.toByteData(
                format: ui.ImageByteFormat.rawRgba,
              ))!.buffer.asUint8List();
              final header = bytes.take(image.width * top.floor() * 4).toList();
              image.dispose();
              return header;
            }))!;
        final originalHeader = await headerPixels();
        await tester.drag(list, const Offset(0, -140));
        await tester.pumpAndSettle();
        expect(listEquals(await headerPixels(), originalHeader), isTrue);
        final position = tester
            .state<ScrollableState>(
              find.descendant(of: list, matching: find.byType(Scrollable)),
            )
            .position;
        position.jumpTo(0);
        await tester.pumpAndSettle();
        final gesture = await tester.startGesture(tester.getCenter(list));
        await gesture.moveBy(const Offset(0, 140));
        await tester.pump(const Duration(milliseconds: 100));
        expect(listEquals(await headerPixels(), originalHeader), isTrue);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets(
      'glass habits fade smoothly at the top in full screen and smaller panels',
      (tester) async {
        final originalBlur = SettingsService.hasBlur.value;
        SettingsService.hasBlur.value = true;
        addTearDown(() => SettingsService.hasBlur.value = originalBlur);
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1;
        emitLoaded(
          List.generate(12, (i) => habitScheduledToday(title: 'Habit $i')),
        );
        for (final size in [const Size(1350, 872), const Size(360, 320)]) {
          tester.view.physicalSize = size;
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              scrollBehavior: const AppScrollBehavior(),
              theme: ThemeData.dark(),
              home: Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: AppColors.surfaceDim,
                    child: TodaysHabitsPanel(
                      viewModel: viewModel,
                      onOpenCalendar: () {},
                      onEditHabits: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final list = find.byType(ListView);
          final position = tester
              .state<ScrollableState>(
                find.descendant(of: list, matching: find.byType(Scrollable)),
              )
              .position;
          position.jumpTo(35);
          await tester.pumpAndSettle();
          final listTop =
              (tester.getTopLeft(list).dy -
                      tester.getTopLeft(find.byKey(key)).dy)
                  .round();
          final samples = (await tester.runAsync(() async {
            final image =
                await (key.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = (await image.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            int red(int y) =>
                bytes[((listTop + y) * image.width + image.width - 20) * 4];
            final samples = [red(1), red(10), red(30)];
            image.dispose();
            return samples;
          }))!;
          expect(
            samples[0],
            lessThan(samples[1]),
            reason: 'First card must blend into the top edge at $size',
          );
          expect(samples[1], lessThan(samples[2]));
          expect(
            samples[2],
            lessThan(60),
            reason: 'Glass background must not turn opaque white under a mask',
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('shows empty message when no habits for today', (tester) async {
      emitLoaded(const []);
      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.text('На сегодня привычек нет'), findsOneWidget);
    });

    testWidgets('shows only habits scheduled today', (tester) async {
      final otherWeekday = _todayWeekday == 1
          ? 2
          : 1; // любой день, отличный от сегодняшнего
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
        schedule: HabitSchedule(daysOfWeek: [_todayWeekday], durationWeeks: 1),
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
