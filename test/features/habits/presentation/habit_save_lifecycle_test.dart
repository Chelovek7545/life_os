import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:life_os/features/habits/presentation/habits_sheet.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_edit_form.dart';
import '../support/memory_habits.dart';

void main() {
  for (final deleting in [false, true]) {
    testWidgets(
      '${deleting ? 'delete' : 'save'} waits for storage and keeps the form open for retry',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = MemoryHabits();
        final habit = Habit.create(title: 'Read', type: const MorningHabit());
        store.habits[habit.id] = habit;
        final model = HabitsViewModel(store)..initialize();
        await tester.runAsync(
          () => model.state.firstWhere((state) => state is HabitsLoaded),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showHabitEditSheet(
                    context: context,
                    viewModel: model,
                    habit: habit,
                  ),
                  child: const Text('Edit'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Edit'));
        await tester.pumpAndSettle();
        if (!deleting) {
          await tester.enterText(find.byType(TextField), 'Read more');
        }
        final action = deleting ? find.byTooltip('Delete') : find.text('Save');
        await tester.ensureVisible(action);
        store.writeGate = Completer<void>();
        await tester.tap(action);
        await tester.pump();
        expect(find.byType(HabitEditForm), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Save'),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Delete',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) => widget is IconButton && widget.tooltip == 'Close',
                ),
              )
              .onPressed,
          isNull,
        );
        store.writeGate!.completeError(StateError('Disk unavailable'));
        await tester.pumpAndSettle();
        expect(find.byType(HabitEditForm), findsOneWidget);
        expect(
          find.text('Не удалось сохранить изменения. Попробуйте ещё раз.'),
          findsOneWidget,
        );
        expect(store.habits[habit.id]!.title, 'Read');
        store.writeGate = null;
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(find.byType(HabitEditForm), findsNothing);
        if (deleting) {
          expect(store.habits, isEmpty);
        } else {
          expect(store.habits[habit.id]!.title, 'Read more');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(model.dispose);
      },
    );
  }
}
