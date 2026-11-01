import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_components/graph_components.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/tasks/presentation/tasks_graph_components.dart';
import '../../../support/widget_dialog.dart';

Future<void> chooseDate(WidgetTester tester, String label, DateTime day) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
  tester
      .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
      .onDateChanged(day);
  await tester.pump();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'closing the creation form while the date picker is open leaves no stale updates',
    (tester) async {
      await openDialog(
        tester,
        GraphChildCreateDialog(
          spec: taskGraphComponent(),
          onSave: (_) async {},
        ),
      );
      final route = ModalRoute.of(
        tester.element(find.byType(GraphChildCreateDialog)),
      )!;
      await tester.tap(find.text('Выбрать дату'));
      await tester.pumpAndSettle();
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .removeRoute(route);
      await tester.pumpAndSettle();
      tester
          .widget<CalendarDatePicker>(find.byType(CalendarDatePicker))
          .onDateChanged(DateTime(2027, 2, 5));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.byType(GraphChildCreateDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'task schedule fields reach the generic draft and survive a failed creation',
    (tester) async {
      GraphNodeDraft? saved;
      var attempts = 0;
      final day = DateTime(2027, 2, 3);
      final due = DateTime(2027, 2, 5);
      await openDialog(
        tester,
        GraphChildCreateDialog(
          spec: taskGraphComponent(),
          onSave: (draft) async {
            saved = draft;
            if (++attempts == 1) throw StateError('Retry');
          },
        ),
      );
      await tester.enterText(find.byType(TextField).first, 'Scheduled');
      await chooseDate(tester, 'Set day', day);
      await chooseDate(tester, 'Выбрать дату', due);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(
        find.text('Не удалось создать узел. Повторите попытку.'),
        findsOneWidget,
      );
      expect(find.text('03.02.2027'), findsOneWidget);
      expect(find.text('05.02.2027'), findsOneWidget);
      await tester.tap(find.text('Создать'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(saved!.kind, 'task');
      expect(saved!.title, 'Scheduled');
      expect(
        saved!.attributes['startsAt'],
        day.add(const Duration(milliseconds: 1)),
      );
      expect(
        saved!.attributes['endsAt'],
        day.add(const Duration(milliseconds: 1)),
      );
      expect(saved!.attributes['dueDate'], due);
    },
  );

  testWidgets(
    'task status extension updates storage values without losing unrelated attributes',
    (tester) async {
      GraphNodeData? saved;
      final original = GraphNodeData(
        id: 'task',
        kind: 'task',
        title: 'Task',
        color: '#123456',
        attributes: {'taskStatus': TaskStatus.open.name, 'external': 'keep'},
      );
      await openDialog(
        tester,
        GraphNodeEditDialog(
          node: original,
          spec: taskGraphComponent(),
          onDelete: (_) async {},
          onSave: (node) async => saved = node,
        ),
      );
      await tester.tap(find.byIcon(Icons.check_circle_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сохранить'));
      await tester.pumpAndSettle();
      expect(saved!.attributes, {
        'taskStatus': TaskStatus.done.name,
        'external': 'keep',
      });
      expect(saved!.color, original.color);
    },
  );
}
