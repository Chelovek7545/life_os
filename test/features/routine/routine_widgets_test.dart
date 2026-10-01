import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/features/routine/data/routine_repository.dart';
import 'package:life_os/features/routine/presentation/routine_screen.dart';
import 'package:life_os/features/routine/presentation/routine_timetable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/features/routine/domain/routine_models.dart';
import 'package:life_os/features/routine/presentation/routine_canvas.dart';
import 'package:life_os/features/routine/presentation/routine_editors.dart';
import 'package:life_os/features/routine/presentation/routine_style.dart';
import 'package:life_os/features/routine/presentation/routine_views.dart';

void main() {
  testWidgets(
    'screen opens demo and supplies light text style inside dark app',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase(NativeDatabase.memory());
      final repo = RoutineRepository(db);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(body: RoutineScreen(repository: repo)),
        ),
      );
      await tester.runAsync(() => repo.load());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Посмотреть пример'));
      await tester.pumpAndSettle();
      expect(
        find.text('Демонстрационные данные · отметки не сохраняются'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Светлое оформление холста'));
      await tester.pumpAndSettle();
      expect(
        DefaultTextStyle.of(
          tester.element(find.text('Распорядок')),
        ).style.color,
        const Color(0xFF24283A),
      );
      expect(repo.snapshot.templates, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
        repo.dispose();
        await db.close();
      });
    },
  );
  final today = DateTime(2026, 9, 7, 10);
  List<RoutineOccurrence> demo() {
    final items = exampleRoutineItems();
    return RoutineSnapshot(
      versions: {'v': items},
      activations: [
        RoutineActivation(
          id: 'a',
          versionId: 'v',
          templateId: 't',
          from: DateTime(2026, 9, 1),
        ),
      ],
    ).resolve(DateTime(2026, 9, 1), DateTime(2026, 9, 30));
  }

  Widget host(Widget child, {bool dark = true}) => MaterialApp(
    theme: RoutinePalette(dark).theme,
    home: Scaffold(body: child),
  );
  testWidgets('day rows have working checkboxes with future disabled', (
    tester,
  ) async {
    final entries = demo()
        .where((o) => dayKey(o.date) == '2026-09-07')
        .toList();
    String? checked;
    await tester.pumpWidget(
      host(
        RoutineDayView(
          entries: entries,
          today: today,
          onToggle: (o) => checked = o.id,
          onEdit: (_) {},
          onMenu: (_, _) {},
          onAdd: () {},
        ),
      ),
    );
    await tester.tap(find.byType(RoutineCheck).first);
    await tester.pump();
    expect(checked, entries.first.id);
    expect(tester.takeException(), isNull);
    final future = demo().firstWhere((o) => o.date.isAfter(routineDay(today)));
    checked = null;
    await tester.pumpWidget(
      host(
        RoutineCheck(
          occurrence: future,
          today: today,
          onToggle: (o) => checked = o.id,
        ),
      ),
    );
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).onChanged, isNull);
    expect(checked, isNull);
  });
  testWidgets('week, tracker and analytics render in narrow board cards', (
    tester,
  ) async {
    final entries = demo();
    final views = <Widget>[
      RoutineTimetable(
        entries: entries,
        date: today,
        today: today,
        onToggle: (_) {},
        onEdit: (_) {},
        onAdd: (_, _) {},
        dayLabels: const {1: 'очный', 2: 'онлайн'},
      ),
      RoutineWeekView(
        entries: entries,
        date: today,
        today: today,
        onToggle: (_) {},
        onEdit: (_) {},
        onMove: (_, _, _) {},
        onNew: (_, _) {},
      ),
      RoutineTrackerView(
        entries: entries,
        from: DateTime(2026, 9, 1),
        to: DateTime(2026, 9, 30),
        today: today,
        onToggle: (_) {},
        onDay: (_) {},
      ),
      for (final section in ['overview', 'regularity', 'balance'])
        RoutineAnalyticsView(
          entries: entries,
          previous: const [],
          today: today,
          onDay: (_) {},
          section: section,
        ),
    ];
    for (final view in views) {
      await tester.pumpWidget(
        host(Center(child: SizedBox(width: 350, height: 320, child: view))),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '${view.runtimeType}');
    }
  });
  testWidgets('canvas drags, resizes, zooms and adds independent views', (
    tester,
  ) async {
    final transform = TransformationController();
    final panels = [RoutinePanel.create('day', 20, 20)];
    panels.single.height = 400;
    final key = GlobalKey<RoutineCanvasState>();
    var changes = 0;
    await tester.pumpWidget(
      host(
        RoutineCanvas(
          key: key,
          panels: panels,
          transform: transform,
          date: today,
          onChanged: () => changes++,
          builder: (_) => const Center(child: Text('Live table')),
        ),
      ),
    );
    final header = find.text('План дня');
    final gesture = await tester.startGesture(tester.getCenter(header));
    await gesture.moveBy(const Offset(40, 40));
    await tester.pump();
    await gesture.moveBy(const Offset(20, 10));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(panels.single.x, greaterThan(20));
    expect(panels.single.y, greaterThan(20));
    expect(tester.takeException(), isNull);
    final widthBefore = panels.single.width;
    final heightBefore = panels.single.height;
    await tester.drag(find.byIcon(Icons.south_east), const Offset(50, 30));
    await tester.pump();
    expect(panels.single.width, greaterThan(widthBefore));
    expect(panels.single.height, greaterThan(heightBefore));
    final before = transform.value.getMaxScaleOnAxis();
    key.currentState!.zoom(.8);
    await tester.pump();
    expect(transform.value.getMaxScaleOnAxis(), lessThan(before));
    key.currentState!.add('tracker');
    await tester.pump();
    expect(panels.length, 2);
    expect(panels.last.type, 'tracker');
    expect(changes, greaterThan(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    transform.dispose();
  });
  testWidgets('editor accepts a named untimed activity', (tester) async {
    RoutineItem? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showRoutineItemEditor(context);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Прогулка');
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();
    expect(result?.title, 'Прогулка');
    expect(result?.slots.single.timed, isFalse);
    expect(tester.takeException(), isNull);
  });
}
