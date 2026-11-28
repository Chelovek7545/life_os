import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goals_api/goals_api.dart';
import 'package:graph_canvas/graph_canvas.dart' as graph;
import 'package:life_os/features/lifegraph/data/preferences_canvas_session.dart';
import 'package:life_os/features/lifegraph/presentation/canvas_export.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/canvases_panel.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:lifegraph_plugin/canvas_board.dart';
import 'package:projects_api/projects_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';

import '../../../support/test_app.dart';

Future<void> _until(
  WidgetTester tester,
  Finder finder, {
  bool exists = true,
}) async {
  for (var i = 0; i < 35; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty == exists) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  expect(finder, exists ? findsOneWidget : findsNothing);
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
        'Рука',
        'Добавить карточку',
        'Выделение рамкой',
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
    expect(find.byTooltip('Видимость слоёв'), findsNothing);
    expect(find.byTooltip('Разложить по веткам'), findsNothing);
    final tools = find.byKey(const ValueKey('canvas-tools'));
    final graphView = find.byType(graph.GraphView);
    expect(tester.getCenter(tools).dy, tester.getCenter(graphView).dy);
    final selection = find.byTooltip('Выделение рамкой');
    final hand = find.byTooltip('Рука');
    expect(selection, findsOneWidget);
    expect(tester.getCenter(selection).dx, tester.getCenter(hand).dx);
    expect(
      tester.getCenter(selection).dx,
      tester.getCenter(find.byTooltip('Добавить карточку')).dx,
    );
    final selectionControl = find.ancestor(
      of: selection,
      matching: find.byType(graph.ControlButton),
    );
    final handControl = find.ancestor(
      of: hand,
      matching: find.byType(graph.ControlButton),
    );
    await tester.tap(selection);
    await tester.pumpAndSettle();
    expect(tester.widget<graph.ControlButton>(selectionControl).active, isTrue);
    await tester.tap(hand);
    await tester.pumpAndSettle();
    expect(
      tester.widget<graph.ControlButton>(selectionControl).active,
      isFalse,
    );
    expect(tester.widget<graph.ControlButton>(handControl).active, isTrue);

    final camera = tester.widget<graph.GraphView>(graphView).camera!;
    final origin = editor.graph.single.position;
    final nodeCenter = camera.screenBoundsOfNode(task.id)!.center;
    await tester.dragFrom(
      nodeCenter,
      const Offset(90, 60),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(
      camera.screenBoundsOfNode(task.id)!.center.dx,
      greaterThan(nodeCenter.dx),
    );
    expect(editor.graph.single.position, origin);

    await tester.tap(selection);
    await tester.pumpAndSettle();
    expect(tester.widget<graph.ControlButton>(handControl).active, isFalse);
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

  testWidgets(
    'task editor shows live sequence and keeps the canvas interactive',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 780);
      addTearDown(tester.view.reset);
      final project = Project.create(name: 'Новый проект');
      final previous = Task.blank().copyWith(title: 'Подготовить материалы');
      final task = Task.blank().copyWith(
        title: 'Запланировать встречу',
        startsAt: Wrapped(DateTime(2027, 1, 12, 9, 30)),
        dueDate: Wrapped(DateTime(2027, 1, 20)),
        predecessorTaskIds: [previous.id],
        tags: const [Tag(id: 0, name: 'встречи', colorHex: 0xFF4A90D9)],
      );
      final next = Task.blank().copyWith(
        title: 'Отправить итоги',
        predecessorTaskIds: [task.id],
      );
      final (app, editor) = (await tester.runAsync(() async {
        final app = await createTestApp(enableObsidian: false);
        await app.projectsRepository.addProject(project);
        for (final item in [previous, task, next]) {
          await app.tasksRepository.addTask(item);
        }
        final pulse = app.pulseScreenViewModel;
        final canvas = await pulse.createCanvas(title: 'Планирование');
        final editor = await pulse.openCanvas(canvas);
        await editor.addCanvasEntity(task.id, const Offset(1200, 1000));
        return (app, editor);
      }))!;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: LifeGraphScreen(viewModel: editor),
        ),
      );
      await _until(tester, find.text(task.title));
      final camera = tester
          .widget<graph.GraphView>(find.byType(graph.GraphView))
          .camera!;
      camera.revealNode(task.id);
      await tester.pumpAndSettle();
      await tester.tapAt(
        camera.screenBoundsOfNode(task.id)!.center,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Редактировать карточку'));
      final title = find.text('Редактировать задачу');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final entering = tester.getTopLeft(title).dx;
      final projectField = find.byType(DropdownButtonFormField<String>);
      await _until(tester, projectField);
      await _until(tester, find.text(next.title));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(title).dx, lessThan(entering));
      expect(tester.getTopLeft(title).dx, greaterThan(690));
      expect(find.text('Предыдущая задача'), findsOneWidget);
      expect(find.text(previous.title), findsOneWidget);
      expect(find.text('Следующая задача'), findsOneWidget);
      await tester.runAsync(
        () => app.tasksRepository.updateTask(
          next.copyWith(title: 'Отправить протокол'),
        ),
      );
      await _until(tester, find.text('Отправить протокол'));
      expect(find.text(next.title), findsNothing);

      final before = camera.screenBoundsOfNode(task.id)!.center;
      await tester.dragFrom(const Offset(260, 300), const Offset(85, 55));
      await tester.pumpAndSettle();
      expect(
        camera.screenBoundsOfNode(task.id)!.center.dx,
        greaterThan(before.dx),
      );
      final scale = camera.scale.value;
      final zoom = find.byTooltip('Увеличить масштаб');
      expect(zoom.hitTestable(), findsOneWidget);
      await tester.tap(zoom);
      await tester.pumpAndSettle();
      expect(camera.scale.value, greaterThan(scale));
      expect(title, findsOneWidget);

      final priority = find.byType(DropdownButtonFormField<int>);
      await tester.ensureVisible(priority);
      await tester.tap(priority);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Высокий').last);
      await tester.pumpAndSettle();

      await tester.ensureVisible(projectField);
      await tester.tap(projectField);
      await tester.pumpAndSettle();
      await tester.tap(find.text(project.name).last);
      await tester.pumpAndSettle();

      final clearDeadline = find.byTooltip('Очистить дату · Дедлайн');
      await tester.ensureVisible(clearDeadline);
      await tester.tap(clearDeadline);
      await tester.pumpAndSettle();
      final selectEnd = find.byTooltip('Выбрать дату · Окончание');
      await tester.ensureVisible(selectEnd);
      await tester.tap(selectEnd);
      await tester.pumpAndSettle();
      final calendar = tester.widget<CalendarDatePicker>(
        find.byType(CalendarDatePicker),
      );
      calendar.onDateChanged(DateTime(2027, 1, 13));
      await tester.pump();
      await tester.tap(find.text('Выбрать'));
      await tester.pumpAndSettle();

      await tester.runAsync(() => tester.tap(find.text('Сохранить')));
      await _until(tester, title, exists: false);
      await tester.pumpAndSettle();
      expect(title, findsNothing);
      final saved = (await tester.runAsync(
        () => app.tasksRepository.getById(task.id),
      ))!;
      expect(saved.priority, 2);
      expect(saved.projectId, project.id);
      expect(saved.startsAt, task.startsAt);
      expect(saved.endsAt?.day, 13);
      expect(saved.dueDate, isNull);
      expect(saved.description, isEmpty);
      expect(saved.tags.single.name, 'встречи');
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets('compact editor saves project, goal and sphere fields', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 580);
    addTearDown(tester.view.reset);
    final sphere = Sphere.create(name: 'Работа');
    final deadline = DateTime(2027, 3, 15);
    final goal = Goal.create(
      name: 'Запуск',
      sphereId: sphere.id,
      dueDate: deadline,
    );
    final project = Project.create(
      name: 'Пилот',
    ).copyWith(dueDate: Wrapped(deadline));
    final (app, editor) = (await tester.runAsync(() async {
      final app = await createTestApp(enableObsidian: false);
      await app.spheresRepository.addSphere(sphere);
      await app.goalsRepository.addGoal(goal);
      await app.projectsRepository.addProject(project);
      final pulse = app.pulseScreenViewModel;
      final canvas = await pulse.createCanvas(title: 'Рабочая доска');
      final editor = await pulse.openCanvas(canvas);
      await editor.addCanvasEntity(sphere.id, const Offset(900, 1000));
      await editor.addCanvasEntity(goal.id, const Offset(1200, 1000));
      await editor.addCanvasEntity(project.id, const Offset(1500, 1000));
      return (app, editor);
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.25)),
          child: child!,
        ),
        home: LifeGraphScreen(viewModel: editor),
      ),
    );
    await tester.pumpAndSettle();
    final camera = tester
        .widget<graph.GraphView>(find.byType(graph.GraphView))
        .camera!;
    Future<void> open(String id, String title) async {
      camera.revealNode(id);
      await tester.pumpAndSettle();
      await tester.longPressAt(camera.screenBoundsOfNode(id)!.center);
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
      expect(find.text('Сохранить').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    Future<void> save() async {
      await tester.runAsync(() => tester.tap(find.text('Сохранить')));
      await _until(tester, find.byTooltip('Закрыть редактор'), exists: false);
      await tester.pumpAndSettle();
    }

    await open(project.id, 'Редактировать проект');
    expect(find.byTooltip('Рука').hitTestable(), findsOneWidget);
    final zoom = find.byTooltip('Увеличить масштаб');
    expect(zoom.hitTestable(), findsOneWidget);
    final scale = camera.scale.value;
    await tester.tap(zoom);
    await tester.pumpAndSettle();
    expect(camera.scale.value, greaterThan(scale));
    expect(find.text('Редактировать проект'), findsOneWidget);
    final archived = find.byType(DropdownButtonFormField<bool>);
    await tester.ensureVisible(archived);
    await tester.tap(archived);
    await tester.pumpAndSettle();
    await tester.tap(find.text('В архиве').last);
    await tester.pumpAndSettle();
    await save();

    await open(goal.id, 'Редактировать цель');
    final clear = find.byTooltip('Очистить дату · Дедлайн');
    await tester.ensureVisible(clear);
    await tester.tap(clear);
    await save();

    await open(sphere.id, 'Редактировать сферу');
    final hex = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Цвет HEX',
    );
    await tester.ensureVisible(hex);
    await tester.enterText(hex, '#96C2AB');
    await save();

    await tester.runAsync(() async {
      final stored = (await app.projectsRepository.getProjectById(project.id))!;
      expect(stored.isArchived, isTrue);
      expect(stored.dueDate, deadline);
      expect((await app.goalsRepository.getGoal(goal.id))!.dueDate, isNull);
      expect(
        (await app.spheresRepository.getSphere(sphere.id))!.color,
        '#96C2AB',
      );
    });
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester, app);
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
