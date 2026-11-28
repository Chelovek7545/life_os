import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goals_api/goals_api.dart';
import 'package:life_os/features/lifegraph/presentation/widgets/canvases_panel.dart';
import 'package:projects_api/projects_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:tasks_api/tasks_api.dart';

import '../../support/test_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'canvases keep explicit membership, local links and live task data',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final pulse = app.pulseScreenViewModel;
      final sphere = Sphere.create(name: 'Сфера');
      final goal = Goal.create(name: 'Цель', sphereId: sphere.id);
      final project = Project.create(name: 'Проект', goalId: goal.id);
      final selected = Task.blank().copyWith(
        title: 'Выбранная',
        projectId: Wrapped(project.id),
      );
      final omitted = Task.blank().copyWith(
        title: 'Пропущенная',
        projectId: Wrapped(project.id),
      );
      await app.spheresRepository.addSphere(sphere);
      await app.goalsRepository.addGoal(goal);
      await app.projectsRepository.addProject(project);
      await app.tasksRepository.addTask(selected);
      await app.tasksRepository.addTask(omitted);
      expect(pulse.canvases, isEmpty);

      final board = await pulse.createCanvas(
        title: '  План  ',
        sourceId: project.id,
        selectedIds: {project.id, selected.id, sphere.id},
      );
      expect(board.id, isNot(project.id));
      expect(board.title, 'План');
      expect(board.cardCount, 2);
      final model = await pulse.openCanvas(board);
      expect(model.graph.map((card) => card.id), [project.id, selected.id]);
      expect(model.nodeById(selected.id)?.parentId, project.id);
      expect(
        model.availableCanvasEntities.map((entity) => entity.id),
        containsAll([sphere.id, goal.id, omitted.id]),
      );

      final statusChanged = model.graphStream.firstWhere(
        (_) => model.nodeById(selected.id)?.taskStatus == TaskStatus.done,
      );
      await app.tasksRepository.setTaskStatus(selected.id, TaskStatus.done);
      await statusChanged.timeout(const Duration(seconds: 5));
      final newer = Task.blank().copyWith(
        title: 'Новая задача',
        projectId: Wrapped(project.id),
      );
      await app.tasksRepository.addTask(newer);
      await model.graphStream
          .firstWhere(
            (_) => model.availableCanvasEntities.any(
              (node) => node.id == newer.id,
            ),
          )
          .timeout(const Duration(seconds: 5));
      expect(model.nodeById(newer.id), isNull);

      await model.addCanvasEntity(sphere.id, const Offset(700, 500));
      await model.connectCanvasCards(sphere.id, selected.id);
      expect(model.nodeById(selected.id)?.parentId, sphere.id);
      expect(
        (await app.tasksRepository.getById(selected.id))?.projectId,
        project.id,
      );
      await model.removeCanvasSelection([project.id], const []);
      expect(
        (await app.projectsRepository.getAllProjects()).single.id,
        project.id,
      );
      await model.dispose();
      await pulse.reloadCanvases();

      final reopened = await pulse.openCanvas(pulse.canvases.single);
      expect(reopened.nodeById(selected.id)?.parentId, sphere.id);
      expect(
        reopened.graph.singleWhere((node) => node.id == sphere.id).position,
        const Offset(700, 500),
      );
      expect(reopened.nodeById(project.id), isNull);
      await reopened.dispose();
    },
  );

  test('a board without entities saves stickers and can be reopened', () async {
    final app = await createTestApp(enableObsidian: false);
    addTearDown(app.dispose);
    final pulse = app.pulseScreenViewModel;
    final board = await pulse.createCanvas(title: 'Свободная доска');
    expect(board.sourceId, isNull);
    final first = await pulse.openCanvas(board);
    expect(first.graph, isEmpty);
    await first.createNoteWithText(title: 'Заметка', text: 'Текст');
    await first.dispose();
    await pulse.reloadCanvases();
    expect(pulse.canvases.single.cardCount, 1);
    final reopened = await pulse.openCanvas(pulse.canvases.single);
    expect(reopened.notes.single.text, 'Заметка\n\nТекст');
    await reopened.removeCanvasSelection(const [], [reopened.notes.single.id]);
    await reopened.dispose();
    await pulse.reloadCanvases();
    expect(pulse.canvases.single.cardCount, 0);
  });

  test(
    'canvases preserve coordinates beyond both sides of the old bounds',
    () async {
      final app = await createTestApp(enableObsidian: false);
      addTearDown(app.dispose);
      final pulse = app.pulseScreenViewModel;
      final task = Task.blank().copyWith(title: 'Дальняя задача');
      await app.tasksRepository.addTask(task);
      final board = await pulse.createCanvas(title: 'Свободное пространство');
      final model = await pulse.openCanvas(board);
      await model.addCanvasEntity(task.id, const Offset(-18000, -9000));
      await model.createNoteWithText(
        title: '',
        text: 'Стикер далеко справа',
        position: const Offset(32000, 17000),
      );
      expect(model.graph.single.position, const Offset(-18000, -9000));
      expect(model.notes.single.position, const Offset(32000, 17000));

      model.commitMove(task.id, 26000, -11000);
      model.commitNoteMove(model.notes.single.id, -14000, 22000);
      await model.dispose();
      await pulse.reloadCanvases();

      final reopened = await pulse.openCanvas(pulse.canvases.single);
      expect(reopened.graph.single.position, const Offset(26000, -11000));
      expect(reopened.notes.single.position, const Offset(-14000, 22000));
      await reopened.dispose();
    },
  );

  testWidgets('Pulse panel creates a canvas with selected branches', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(380, 840);
    addTearDown(tester.view.reset);
    final project = Project.create(name: 'Проект для импорта');
    final excluded = Task.blank().copyWith(
      title: 'Убрать из импорта',
      projectId: Wrapped(project.id),
    );
    final app = (await tester.runAsync(() async {
      final container = await createTestApp(enableObsidian: false);
      await container.projectsRepository.addProject(project);
      await container.tasksRepository.addTask(excluded);
      return container;
    }))!;
    final pulse = app.pulseScreenViewModel;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: CanvasesPanel(model: pulse)),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('canvas-create')));
    await tester.pumpAndSettle();
    final name = find.byKey(const ValueKey('canvas-name'));
    await tester.enterText(name, 'Импорт из проекта');
    Future<void> waitFor(Finder finder) async {
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (finder.evaluate().isNotEmpty) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }
      expect(finder, findsOneWidget);
    }

    await tester.runAsync(() => tester.tap(find.text('Из структуры')));
    final source = find.text('Сфера, цель или проект');
    await waitFor(source);
    await tester.tap(source);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проект · ${project.name}').last);
    await tester.pumpAndSettle();
    final checkbox = find.byKey(ValueKey('canvas-include:${excluded.id}'));
    await tester.ensureVisible(checkbox);
    await tester.pumpAndSettle();
    await tester.tap(checkbox);
    await tester.pumpAndSettle();
    expect(find.text('Будет добавлено: 1 карточка'), findsOneWidget);
    await tester.runAsync(() => tester.tap(find.text('Создать канвас')));
    final addCard = find.byTooltip('Добавить карточку');
    await waitFor(addCard);
    await tester.pumpAndSettle();
    final board = pulse.canvases.single;
    expect(board.title, 'Импорт из проекта');
    expect(board.cardCount, 1);
    expect(addCard, findsOneWidget);
    expect(tester.takeException(), isNull);
    await disposeTestApp(tester, app);
  });
}
