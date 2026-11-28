import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goals_api/goals_api.dart';
import 'package:graph_canvas/graph_canvas.dart' as graph;
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';
import 'package:life_os/core/ui/pill_switcher.dart';
import 'package:life_os/features/lifegraph/data/preferences_canvas_session.dart';
import 'package:life_os/features/lifegraph/presentation/canvas_export.dart';
import 'package:life_os/features/lifegraph/presentation/life_graph_screen.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/canvas_context_menu.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/canvases_panel.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_note_context_menu.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/graph_theme.dart';
import 'package:life_os/features/settings/settings_service.dart';
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

  testWidgets('card and note menus blur the canvas when they open', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 520);
    addTearDown(tester.view.reset);
    final oldBlur = SettingsService.hasBlur.value;
    SettingsService.hasBlur.value = true;
    addTearDown(() => SettingsService.hasBlur.value = oldBlur);
    const frame = ValueKey('context-menu-preview');
    late BuildContext anchorContext;
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          scrollBehavior: const AppScrollBehavior(),
          home: Builder(
            builder: (context) {
              anchorContext = context;
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: ColoredBox(color: Colors.white)),
                  Expanded(child: ColoredBox(color: Colors.black)),
                ],
              );
            },
          ),
        ),
      ),
    );
    final result = showCanvasNodeActions(
      anchorContext,
      const Rect.fromLTWH(260, 235, 280, 106),
      canEdit: true,
      canLink: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 64));

    final toolbar = find.byKey(const ValueKey('canvas-node-actions'));
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(frame),
    );
    Future<void> expectBlurredEdge(
      int sampleY, {
      int minimumContrast = 80,
    }) async {
      final samples = (await tester.runAsync(() async {
        final picture = await boundary.toImage();
        try {
          final pixels = (await picture.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          int redAt(int x) =>
              pixels.getUint8((sampleY * picture.width + x) * 4);
          return (near: redAt(396) - redAt(404), far: redAt(350) - redAt(450));
        } finally {
          picture.dispose();
        }
      }))!;
      expect(samples.far, greaterThan(minimumContrast), reason: '$samples');
      expect(samples.near.abs(), lessThan(samples.far * .65));
    }

    final sampleY = tester.getTopLeft(toolbar).dy.round() + 10;
    await expectBlurredEdge(sampleY);
    await tester.pumpAndSettle();
    await expectBlurredEdge(sampleY);
    Navigator.of(anchorContext).pop();
    await tester.pumpAndSettle();
    expect(await result, isNull);

    final noteAction = showGraphNoteContextMenu(
      anchorContext,
      const Offset(288, 164),
      canEdit: true,
      canConvert: true,
      canDelete: true,
      canSaveCopy: true,
    );
    await tester.pump();
    await expectBlurredEdge(169, minimumContrast: 55);
    await tester.pumpAndSettle();
    await expectBlurredEdge(169, minimumContrast: 55);
    final noteMenu = find.ancestor(
      of: find.text('Заметка'),
      matching: find.byType(BackdropFilter),
    );
    expect(tester.getSize(noteMenu).width, lessThanOrEqualTo(272));
    await tester.tap(find.text('Редактировать'));
    await tester.pumpAndSettle();
    expect(await noteAction, GraphNoteMenuAction.edit);
  });

  testWidgets('anchored actions fit above a button at the bottom edge', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 220);
    addTearDown(tester.view.reset);
    late BuildContext canvasContext;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            canvasContext = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    const button = Rect.fromLTRB(300, 184, 316, 212);
    final action = showCanvasContextMenu<int>(
      canvasContext,
      button,
      title: 'Карточка',
      actions: const [CanvasContextOption(1, 'Действие', Icons.edit_outlined)],
    );
    await tester.pumpAndSettle();
    final item = find.text('Действие');
    final menu = tester.getRect(
      find.ancestor(of: item, matching: find.byType(BackdropFilter)),
    );
    expect(menu.bottom, closeTo(button.top - 4, .5));
    expect(menu.right, closeTo(312, .5));
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(await action, 1);
  });

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
    final toolbarFinder = find.byKey(const ValueKey('canvas-node-actions'));
    final toolbar = tester.getRect(toolbarFinder);
    expect(toolbar.bottom, lessThan(bounds.top));
    expect(toolbar.center.dx, closeTo(bounds.center.dx, .5));
    final blurFinder = find.descendant(
      of: toolbarFinder,
      matching: find.byType(BackdropFilter),
    );
    final blurSetting = SettingsService.hasBlur.value;
    addTearDown(() => SettingsService.hasBlur.value = blurSetting);
    expect(tester.widget<BackdropFilter>(blurFinder).enabled, isTrue);
    SettingsService.hasBlur.value = false;
    await tester.pump();
    final withoutBlur = tester.widget<BackdropFilter>(blurFinder);
    expect(withoutBlur.enabled, isFalse);
    expect(
      (withoutBlur.child as Material).color,
      AppColors.surfaceContainer.withValues(alpha: .90),
    );
    SettingsService.hasBlur.value = blurSetting;
    await tester.pump();
    for (final button in contextButtons) {
      expect(button.style?.backgroundColor?.resolve({}), Colors.transparent);
      expect(button.style?.shape?.resolve({}), isA<RoundedRectangleBorder>());
      expect(
        button.style?.side?.resolve({WidgetState.focused})?.color,
        AppColors.primaryContainer,
      );
      expect(tester.getSize(find.byTooltip(button.tooltip!)).height, 48);
    }
    expect(
      contextButtons
          .firstWhere((button) => button.tooltip == 'Связать с карточкой')
          .onPressed,
      isNull,
    );

    final moreButton = find.byTooltip('Другие действия');
    final moreBounds = tester.getRect(moreButton);
    await tester.tap(moreButton);
    await tester.pumpAndSettle();
    final focusAction = find.text('Показать в центре');
    expect(focusAction, findsOneWidget);
    final moreMenu = tester.getRect(
      find.ancestor(of: focusAction, matching: find.byType(BackdropFilter)),
    );
    expect(moreMenu.top, closeTo(moreBounds.bottom + 4, .5));
    expect(moreMenu.right, closeTo(moreBounds.right, .5));
    await tester.tap(focusAction);
    await tester.pumpAndSettle();
    await tester.tapAt(
      bounds.center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(1.3)),
          child: child!,
        ),
        home: Scaffold(body: CanvasesPanel(model: app.pulseScreenViewModel)),
      ),
    );
    await tester.runAsync(() => tester.tap(find.text('Первая доска')));
    final switcher = find.byTooltip('Переключить канвас');
    await _until(tester, switcher);
    await tester.pumpAndSettle();
    final anchor = tester.getRect(switcher);
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    final menu = tester.getRect(
      find.byKey(const ValueKey('canvas-switch-surface')),
    );
    expect(menu.top, closeTo(anchor.bottom + 8, .1));
    expect(menu.left, closeTo(anchor.left, .1));
    expect(menu.right, lessThan(360));
    final current = find.widgetWithText(OutlinedButton, 'Первая доска');
    expect(tester.widget<OutlinedButton>(current).onPressed, isNull);
    expect(find.text('Текущий канвас'), findsOneWidget);
    expect(find.byTooltip('Закрыть').hitTestable(), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть'));
    await tester.pumpAndSettle();
    expect(find.text('Текущий канвас'), findsNothing);
    await tester.tap(switcher);
    await tester.pumpAndSettle();
    final camera = tester
        .widget<graph.GraphView>(find.byType(graph.GraphView))
        .camera!;
    final beforeDrag = camera.viewportCenter;
    await tester.dragFrom(
      const Offset(180, 475),
      const Offset(-70, -50),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('canvas-switch-surface')), findsNothing);
    expect(camera.viewportCenter, isNot(beforeDrag));
    await tester.tap(switcher);
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

      final statusSwitcher = find.byType(PillSwitcher);
      expect(tester.widget<PillSwitcher>(statusSwitcher).options, hasLength(4));
      expect(
        tester.widget<PillSwitcher>(statusSwitcher).selectedIndex,
        task.status.index,
      );
      final done = find.descendant(
        of: statusSwitcher,
        matching: find.byTooltip('Выполнено'),
      );
      await tester.ensureVisible(done);
      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(
        tester.widget<PillSwitcher>(statusSwitcher).selectedIndex,
        TaskStatus.done.index,
      );

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
      expect(saved.status, TaskStatus.done);
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

  testWidgets('unbounded canvas fits and edits distant cards', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 720);
    addTearDown(tester.view.reset);
    final near = Task.blank().copyWith(title: 'Далеко слева');
    final far = Task.blank().copyWith(title: 'Далеко справа');
    final (app, editor) = (await tester.runAsync(() async {
      final app = await createTestApp(enableObsidian: false);
      await app.tasksRepository.addTask(near);
      await app.tasksRepository.addTask(far);
      final pulse = app.pulseScreenViewModel;
      final canvas = await pulse.createCanvas(title: 'Большая доска');
      final editor = await pulse.openCanvas(canvas);
      await editor.addCanvasEntity(near.id, const Offset(-120000, -50000));
      await editor.addCanvasEntity(far.id, const Offset(210000, 80000));
      return (app, editor);
    }))!;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: LifeGraphScreen(viewModel: editor),
      ),
    );
    await tester.pumpAndSettle();
    final graphView = find.byType(graph.GraphView);
    final viewport = tester.getRect(graphView);
    final camera = tester.widget<graph.GraphView>(graphView).camera!;
    expect(camera.scale.value, lessThan(.01));
    for (final task in [near, far]) {
      expect(
        viewport.contains(camera.screenBoundsOfNode(task.id)!.center),
        isTrue,
      );
    }

    final center = camera.viewportCenter!;
    await tester.dragFrom(
      viewport.center,
      const Offset(140, 100),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(camera.viewportCenter!.dx, lessThan(center.dx - 4200));

    camera.focusCard(near.id);
    await tester.pumpAndSettle();
    camera.zoomBy(1 / camera.scale.value);
    await tester.pumpAndSettle();
    expect(find.text(far.title), findsNothing);
    expect(find.text(near.title).hitTestable(), findsOneWidget);

    final nearPosition = editor.graph
        .firstWhere((node) => node.id == near.id)
        .position;
    await tester.dragFrom(
      camera.screenBoundsOfNode(near.id)!.center,
      const Offset(-80, -50),
    );
    await tester.pumpAndSettle();
    final moved = editor.graph
        .firstWhere((node) => node.id == near.id)
        .position;
    expect(moved.dx, lessThan(nearPosition.dx - 50));
    expect(moved.dy, lessThan(nearPosition.dy - 30));

    final point = viewport.center + const Offset(180, 120);
    final expected =
        camera.viewportCenter! + (point - viewport.center) / camera.scale.value;
    await tester.tapAt(
      point,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Создать задачу'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Новая за краем');
    await tester.runAsync(() => tester.tap(find.text('Создать')));
    await _until(
      tester,
      find.descendant(of: graphView, matching: find.text('Новая за краем')),
    );
    final created = editor.graph.singleWhere(
      (node) => node.label == 'Новая за краем',
    );
    expect(created.position.dx, closeTo(expected.dx, 1));
    expect(created.position.dy, closeTo(expected.dy, 1));
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester, app);
  });

  testWidgets('note edge resize preserves opposite edges and saves geometry', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 720);
    addTearDown(tester.view.reset);
    final (app, canvas, editor) = (await tester.runAsync(() async {
      final app = await createTestApp(enableObsidian: false);
      final pulse = app.pulseScreenViewModel;
      final canvas = await pulse.createCanvas(title: 'Размер заметки');
      final editor = await pulse.openCanvas(canvas);
      await editor.createNote(position: const Offset(-120, 80));
      await editor.flush();
      return (app, canvas, editor);
    }))!;
    await tester.pumpWidget(
      MaterialApp(home: LifeGraphScreen(viewModel: editor)),
    );
    await tester.pumpAndSettle();
    final camera = tester
        .widget<graph.GraphView>(find.byType(graph.GraphView))
        .camera!;
    camera.zoomBy(.5 / camera.scale.value);
    await tester.pumpAndSettle();

    final note = find.byType(graph.DefaultNoteCard);
    final initial = editor.notes.single.position & editor.notes.single.size;
    final edge = tester.getRect(note).centerRight - const Offset(3, 0);
    await tester.dragFrom(
      edge,
      const Offset(40, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    final wider = editor.notes.single.position & editor.notes.single.size;
    expect(wider.topLeft, initial.topLeft);
    expect(wider.width, closeTo(initial.width + 80, .01));
    expect(wider.height, initial.height);

    final corner = tester.getTopLeft(note) + const Offset(3, 3);
    await tester.dragFrom(corner, const Offset(-30, -25));
    await tester.pumpAndSettle();
    final larger = editor.notes.single.position & editor.notes.single.size;
    expect(larger.bottomRight, wider.bottomRight);
    expect(larger.left, closeTo(wider.left - 60, .01));
    expect(larger.top, closeTo(wider.top - 50, .01));

    final topRight = tester.getTopRight(note) + const Offset(-3, 3);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.moveTo(topRight);
    await tester.pumpAndSettle();
    await mouse.down(topRight);
    await mouse.moveBy(const Offset(20, -15));
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    final resized = editor.notes.single.position & editor.notes.single.size;
    expect(resized.bottomLeft, larger.bottomLeft);
    expect(resized.width, closeTo(larger.width + 40, .01));
    expect(resized.height, closeTo(larger.height + 30, .01));

    await tester.pumpWidget(const SizedBox());
    var closed = false;
    final closing = editor.dispose().whenComplete(() => closed = true);
    for (var i = 0; i < 100 && !closed; i++) {
      await tester.pump(const Duration(milliseconds: 10));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 1)),
      );
    }
    expect(closed, isTrue);
    await closing;
    final reopened = (await tester.runAsync(
      () => app.pulseScreenViewModel.openCanvas(canvas),
    ))!;
    expect(reopened.notes.single.position, const Offset(-180, 0));
    expect(reopened.notes.single.size, const Size(392, 230));
    await tester.pumpWidget(
      MaterialApp(home: LifeGraphScreen(viewModel: reopened)),
    );
    await tester.pumpAndSettle();
    await tester.dragFrom(tester.getCenter(note), const Offset(60, 30));
    await tester.pumpAndSettle();
    expect(reopened.notes.single.position.dx, greaterThan(-180));
    expect(reopened.notes.single.position.dy, greaterThan(0));
    expect(reopened.notes.single.size, const Size(392, 230));
    await disposeTestApp(tester, app);
  });

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
