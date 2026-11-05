import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';

void main() {
  Future<List<DateTime>> mount(
    WidgetTester tester, {
    double width = 300,
  }) async {
    var selected = DateTime(2026, 12, 30);
    final changes = <DateTime>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: width,
              child: StatefulBuilder(
                builder: (context, setState) => CalendarRow(
                  selectedDate: selected,
                  onDaySelected: (date) {
                    changes.add(date);
                    setState(() => selected = date);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return changes;
  }

  ScrollController controller(WidgetTester tester) => tester
      .widget<ListView>(
        find.descendant(
          of: find.byType(CalendarRow),
          matching: find.byType(ListView),
        ),
      )
      .controller!;

  testWidgets(
    'only a deliberate drag beyond the edge changes week, once per swipe',
    (tester) async {
      final changes = await mount(tester);
      final row = find.byType(CalendarRow);
      await tester.drag(row, const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      controller(tester).jumpTo(controller(tester).position.maxScrollExtent);
      await tester.pump();
      await tester.drag(row, const Offset(-40, 0));
      await tester.pumpAndSettle();
      expect(changes, isEmpty);
      await tester.drag(row, const Offset(-300, 0));
      await tester.pumpAndSettle();
      expect(changes, [DateTime(2027, 1, 6)]);
      expect(controller(tester).offset, 0);
      await tester.drag(row, const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(changes, [DateTime(2027, 1, 6), DateTime(2026, 12, 30)]);
      expect(
        controller(tester).offset,
        controller(tester).position.maxScrollExtent,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a swipe changes week when all seven days fit', (tester) async {
    final changes = await mount(tester, width: 780);
    expect(controller(tester).position.maxScrollExtent, 0);
    await tester.drag(find.byType(CalendarRow), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(changes, [DateTime(2027, 1, 6)]);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'horizontal wheel and Shift wheel change at edges without repeated flips',
    (tester) async {
      final changes = await mount(tester);
      final point = tester.getCenter(find.byType(CalendarRow));
      Future<void> wheel(Offset delta) async {
        tester.binding.handlePointerEvent(
          PointerScrollEvent(position: point, scrollDelta: delta),
        );
        await tester.pump();
      }

      await wheel(const Offset(90, 0));
      expect(changes, isEmpty);
      controller(tester).jumpTo(controller(tester).position.maxScrollExtent);
      await tester.pump();
      await wheel(const Offset(40, 0));
      expect(changes, isEmpty);
      await wheel(const Offset(40, 0));
      expect(changes, [DateTime(2027, 1, 6)]);
      controller(tester).jumpTo(controller(tester).position.maxScrollExtent);
      await wheel(const Offset(200, 0));
      expect(changes, hasLength(1));
      await tester.pump(const Duration(milliseconds: 300));
      controller(tester).jumpTo(0);
      await wheel(const Offset(-80, 0));
      expect(changes.last, DateTime(2026, 12, 30));
      await tester.pump(const Duration(milliseconds: 300));
      controller(tester).jumpTo(controller(tester).position.maxScrollExtent);
      await wheel(const Offset(0, 100));
      expect(changes, hasLength(2));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await wheel(const Offset(0, 80));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(changes.last, DateTime(2027, 1, 6));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    },
  );
}
