import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graph_canvas/graph_canvas.dart' as graph;
import 'package:life_os/features/lifegraph/data/preferences_canvas_session.dart';
import 'package:life_os/features/lifegraph/presentation/canvas_export.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/canvases_panel.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:lifegraph_plugin/canvas_board.dart';
import 'package:tasks_api/tasks_api.dart';

import '../../../support/test_app.dart';

Future<void> _until(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 35; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(finder, findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('canvas chrome and context menu work in a wide viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 780);
    addTearDown(tester.view.reset);
    final task = Task.blank().copyWith(title: 'Проверить экспорт');
    final (app, editor) = (await tester.runAsync(() async {
      final app = await createTestApp(enableObsidian: false);
      await app.tasksRepository.addTask(task);
      final pulse = app.pulseScreenViewModel;
      final canvas = await pulse.createCanvas(title: 'Доска редактора');
      final editor = await pulse.openCanvas(canvas);
      await editor.addCanvasEntity(task.id, const Offset(1200, 1000));
      await editor.flush();
      return (app, editor);
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LifeGraphScreen(viewModel: editor),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Доска редактора'), findsOneWidget);
    expect(
      tester.widget<graph.GraphView>(find.byType(graph.GraphView)).theme,
      same(AppGraphThemes.dark),
    );
    final roundControls = tester.widgetList<graph.ControlButton>(
      find.byType(graph.ControlButton),
    );
    expect(
      roundControls.map((button) => button.tooltip),
      containsAll([
        'Назад',
        'Увеличить масштаб',
        'Уменьшить масштаб',
        'Вписать канвас',
        'Поиск по канвасу',
        'Фильтры канваса',
        'Настройки отображения',
        'Экспорт канваса',
        'Заметки канваса',
        'Видимость слоёв',
        'Добавить карточку',
        'Выделение рамкой',
        'Разложить по веткам',
      ]),
    );
    expect(
      roundControls.every(
        (button) => identical(button.theme, AppGraphThemes.dark),
      ),
      isTrue,
    );
    final zoomIndicator = find.byKey(const ValueKey('canvas-zoom-indicator'));
    final zoomLabel = find.descendant(
      of: zoomIndicator,
      matching: find.byType(Text),
    );
    final initialZoom = tester.widget<Text>(zoomLabel).data;
    expect(initialZoom, matches(r'^\d+%$'));
    await tester.tap(find.byTooltip('Увеличить масштаб'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(zoomLabel).data, isNot(initialZoom));
    expect(find.byTooltip('Режим фокуса'), findsNothing);
    expect(find.byTooltip('Показать весь граф'), findsNothing);
    final selection = find.byTooltip('Выделение рамкой');
    expect(selection, findsOneWidget);
    expect(
      tester.getCenter(selection).dx,
      tester.getCenter(find.byTooltip('Видимость слоёв')).dx,
    );
    expect(
      tester.getCenter(selection).dx,
      tester.getCenter(find.byTooltip('Добавить карточку')).dx,
    );
    final selectionControl = find.ancestor(
      of: selection,
      matching: find.byType(graph.ControlButton),
    );
    await tester.tap(selection);
    await tester.pumpAndSettle();
    expect(tester.widget<graph.ControlButton>(selectionControl).active, isTrue);
    await tester.tap(selection);
    await tester.pumpAndSettle();

    final settings = find.byTooltip('Настройки отображения');
    await tester.tap(settings);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Сетка'));
    await tester.tap(find.text('Анимации'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    final view = tester.widget<graph.GraphView>(find.byType(graph.GraphView));
    expect(view.showGrid, isFalse);
    expect(view.animateTransitions, isFalse);

    await tester.tap(find.byTooltip('Фильтры канваса'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Выполнено'));
    await tester.tap(find.text('Выполнено'));
    await tester.tap(find.text('Применить'));
    await tester.pumpAndSettle();
    expect(find.text(task.title), findsNothing);

    await tester.tap(find.byTooltip('Поиск по канвасу'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'экспорт');
    await tester.pump();
    await tester.tap(find.text(task.title).last);
    await tester.pumpAndSettle();
    final bounds = view.camera!.screenBoundsOfNode(task.id)!;
    expect(bounds.center.dx, closeTo(600, .5));
    expect(bounds.center.dy, closeTo(390, .5));

    await tester.tapAt(
      bounds.center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Редактировать карточку'), findsOneWidget);
    expect(find.byTooltip('Связать с карточкой'), findsOneWidget);
    expect(find.byTooltip('Другие действия'), findsOneWidget);
    final contextButtons = tester.widgetList<IconButton>(
      find.byWidgetPredicate(
        (widget) =>
            widget is IconButton &&
            const {
              'Редактировать карточку',
              'Связать с карточкой',
              'Дублировать как стикер',
              'Убрать с канваса',
              'Другие действия',
            }.contains(widget.tooltip),
      ),
    );
    expect(contextButtons, hasLength(5));
    for (final button in contextButtons) {
      expect(button.style?.backgroundColor?.resolve({}), Colors.transparent);
      expect(button.style?.shape?.resolve({}), isA<RoundedRectangleBorder>());
    }
    await tester.runAsync(
      () => tester.tap(find.byTooltip('Дублировать как стикер')),
    );
    await _until(tester, find.byType(graph.DefaultNoteCard));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<graph.DefaultNoteCard>(find.byType(graph.DefaultNoteCard))
          .theme,
      same(AppGraphThemes.dark),
    );
    expect(editor.notes.single.text, contains(task.title));

    await tester.tapAt(
      bounds.center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.byTooltip('Убрать с канваса')));
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => editor.graphStream
          .firstWhere((nodes) => nodes.isEmpty)
          .timeout(const Duration(seconds: 2)),
    );
    expect(editor.nodeById(task.id), isNull);
    expect(
      await tester.runAsync(() => app.tasksRepository.getById(task.id)),
      isNotNull,
    );

    await tester.tap(find.byTooltip('Экспорт канваса'));
    await tester.pumpAndSettle();
    for (final format in CanvasExportFormat.values) {
      expect(find.text(format.label), findsOneWidget);
    }
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester, app);
  });

  testWidgets('narrow editor can switch boards inside the canvas flow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.reset);
    final app = (await tester.runAsync(() async {
      final app = await createTestApp(enableObsidian: false);
      await app.pulseScreenViewModel.createCanvas(title: 'Первая доска');
      await app.pulseScreenViewModel.createCanvas(title: 'Вторая доска');
      return app;
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: CanvasesPanel(model: app.pulseScreenViewModel)),
      ),
    );
    await tester.runAsync(() => tester.tap(find.text('Первая доска')));
    await _until(tester, find.byTooltip('Переключить канвас'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Переключить канвас'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Вторая доска')));
    final header = find.descendant(
      of: find.byType(LifeGraphScreen),
      matching: find.text('Вторая доска'),
    );
    await _until(tester, header);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Добавить карточку'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester, app);
  });

  testWidgets('creates tasks and projects directly on a canvas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1100, 740);
    addTearDown(tester.view.reset);
    final (app, editor) = (await tester.runAsync(() async {
      final app = await createTestApp(enableObsidian: false);
      final pulse = app.pulseScreenViewModel;
      final canvas = await pulse.createCanvas(title: 'Новые объекты');
      return (app, await pulse.openCanvas(canvas));
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LifeGraphScreen(viewModel: editor),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> submit(String name) async {
      await tester.enterText(find.byType(TextField).first, name);
      await tester.runAsync(() => tester.tap(find.text('Создать')));
      await _until(
        tester,
        find.descendant(
          of: find.byType(graph.GraphView),
          matching: find.text(name),
        ),
      );
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byTooltip('Добавить карточку'));
    await tester.pumpAndSettle();
    expect(find.text('Добавить из списка'), findsOneWidget);
    await tester.tap(find.text('Создать задачу'));
    await tester.pumpAndSettle();
    await submit('Задача с канваса');

    await tester.tapAt(
      const Offset(250, 200),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать проект'));
    await tester.pumpAndSettle();
    await submit('Проект с канваса');

    await tester.runAsync(() async {
      final task = editor.graph.singleWhere(
        (node) => node.label == 'Задача с канваса',
      );
      expect((await app.tasksRepository.getById(task.id))?.title, task.label);
      expect(
        (await app.projectsRepository.getAllProjects()).single.name,
        'Проект с канваса',
      );
    });
    expect(tester.takeException(), isNull);
    final canvasId = editor.currentCanvasId!;
    await disposeTestApp(tester, app);
    final raw = (await tester.runAsync(() async {
      final session = await PreferencesCanvasSession.open(canvasId);
      return session.read();
    }))!;
    expect(CanvasBoardDocument(raw).nodes, hasLength(2));
  });

  test(
    'export encodes the full canvas as an image and as structured data',
    () async {
      final doc = <String, Object?>{
        'nodes': [
          {
            'id': 'one',
            'type': 'text',
            'x': -35,
            'y': 5,
            'width': 240,
            'height': 100,
            'text': '<script>Пример</script>',
          },
          {
            'id': 'two',
            'type': 'text',
            'x': 310,
            'y': 95,
            'width': 140,
            'height': 100,
            'text': 'Вторая карточка',
          },
        ],
        'edges': [
          {'id': 'link', 'fromNode': 'one', 'toNode': 'two'},
        ],
      };
      final svg = utf8.decode(
        await encodeCanvasExport(CanvasExportFormat.svg, doc),
      );
      expect(svg, contains('<path'));
      expect(svg, contains('&lt;script&gt;'));
      expect(svg, isNot(contains('<script>')));
      final png = await encodeCanvasExport(CanvasExportFormat.png, doc);
      expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
      for (final format in [
        CanvasExportFormat.json,
        CanvasExportFormat.pulse,
      ]) {
        expect(
          jsonDecode(utf8.decode(await encodeCanvasExport(format, doc))),
          doc,
        );
      }
    },
  );
}
