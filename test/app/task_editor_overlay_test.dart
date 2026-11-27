import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/features/lifegraph/presentation/pulse_screen.dart';
import 'package:life_os/features/tasks/presentation/components/task_form_content.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';
import 'package:life_os/features/tasks/presentation/widgets/existing_task_picker_dialog.dart';
import 'package:tasks_api/tasks_api.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  testWidgets(
    'task settings replace and remove sequence links across filters',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      try {
        final previous = Task.blank().copyWith(
          title: 'Подготовить материалы',
          status: TaskStatus.done,
        );
        final task = Task.blank().copyWith(
          title: 'Собрать прототип',
          startsAt: Wrapped(app.tasksViewModel.currentFilterValue.anchorDate),
        );
        final next = Task.blank().copyWith(
          title: 'Проверить прототип',
          status: TaskStatus.done,
        );
        final child = Task.blank().copyWith(
          title: 'Сверстать форму',
          status: TaskStatus.done,
          parentTaskId: Wrapped(task.id),
        );
        final repository = app.tasksRepository;
        await tester.runAsync(() async {
          for (final item in [previous, task, next, child]) {
            await repository.addTask(item);
          }
          await repository.linkTaskAfter(task.id, previous.id);
          await repository.linkTaskAfter(next.id, task.id);
        });

        await tester.pumpWidget(MyApp(diContainer: app));
        app.navigation.open('tasks');
        app.tasksViewModel.updateFilter(
          (filter) => filter.copyWith(showCompleted: () => false),
        );
        await pumpStorage(tester);
        expect(find.text(previous.title), findsNothing);
        expect(find.text(next.title), findsNothing);
        await tester.tap(find.text(task.title).hitTestable().first);
        await pumpStorage(tester);

        final surface = find.byKey(const ValueKey('task-editor.surface'));
        Finder textInEditor(String text) =>
            find.descendant(of: surface, matching: find.text(text));
        final sequence = find.byKey(const ValueKey('task-editor.sequence'));
        final picker = find.byType(ExistingTaskPickerDialog);
        Finder textInSequence(String text) =>
            find.descendant(of: sequence, matching: find.text(text));
        Future<void> openPicker(String title) async {
          await tester.ensureVisible(textInSequence(title).first);
          await tester.tap(textInSequence(title).first);
          await tester.pumpAndSettle();
          expect(picker, findsOneWidget);
        }

        final current = textInSequence('Текущая задача');
        expect(
          tester.getTopLeft(sequence).dy,
          greaterThan(tester.getBottomLeft(textInEditor('DueDate')).dy),
        );
        expect(current, findsOneWidget);
        expect(textInSequence('Предыдущая задача'), findsOneWidget);
        expect(textInSequence(previous.title), findsOneWidget);
        expect(textInSequence('Следующая задача'), findsOneWidget);
        expect(textInSequence(next.title), findsOneWidget);
        expect(
          tester.getCenter(current).dy,
          greaterThan(tester.getCenter(textInSequence(previous.title)).dy),
        );
        expect(
          tester.getCenter(current).dy,
          lessThan(tester.getCenter(textInSequence(next.title)).dy),
        );
        expect(textInEditor(child.title), findsNothing);

        await openPicker(previous.title);
        expect(find.widgetWithText(ListTile, next.title), findsNothing);
        await tester.enterText(
          find.descendant(of: picker, matching: find.byType(TextField)),
          child.title,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, child.title));
        await pumpStorage(tester);
        expect(textInSequence(child.title), findsOneWidget);
        expect(textInSequence(previous.title), findsNothing);

        final second = Task.blank().copyWith(
          title: 'Показать прототип',
          status: TaskStatus.done,
        );
        await tester.runAsync(() async {
          await repository.addTask(second);
          await repository.linkTaskAfter(second.id, task.id);
        });
        await pumpStorage(tester);
        expect(textInSequence('Следующая задача'), findsNWidgets(2));
        await openPicker(next.title);
        expect(find.widgetWithText(ListTile, second.title), findsNothing);
        await tester.tap(find.widgetWithText(ListTile, previous.title));
        await pumpStorage(tester);
        expect(textInSequence(next.title), findsNothing);
        expect(textInSequence(previous.title), findsOneWidget);
        expect(textInSequence(second.title), findsOneWidget);
        expect(
          (await tester.runAsync(
            () => repository.getById(next.id),
          ))!.predecessorTaskId,
          isNull,
        );
        expect(
          (await tester.runAsync(
            () => repository.getById(previous.id),
          ))!.predecessorTaskId,
          task.id,
        );

        final firstRemove = find
            .descendant(of: sequence, matching: find.byTooltip('Убрать связь'))
            .first;
        await tester.ensureVisible(firstRemove);
        await tester.tap(firstRemove);
        await pumpStorage(tester);
        expect(textInSequence(child.title), findsNothing);
        for (final linked in [previous, second]) {
          await openPicker(linked.title);
          await tester.tap(find.text('Убрать связь'));
          await pumpStorage(tester);
          expect(textInSequence(linked.title), findsNothing);
        }
        expect(textInSequence('Без связи'), findsNWidgets(2));
        expect(
          (await tester.runAsync(
            () => repository.getById(task.id),
          ))!.predecessorTaskId,
          isNull,
        );
        expect(
          (await tester.runAsync(
            () => repository.getById(child.id),
          ))!.parentTaskId,
          task.id,
        );
        await openPicker('Без связи');
        await tester.tap(find.widgetWithText(ListTile, previous.title));
        await pumpStorage(tester);
        expect(textInSequence(previous.title), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('task-editor.save')));
        await pumpStorage(tester);
        expect(surface, findsNothing);
        final saved = (await tester.runAsync(
          () => repository.getById(task.id),
        ))!;
        expect(saved.predecessorTaskId, previous.id);

        app.tasksViewModel.openTaskInEditor(saved);
        await pumpStorage(tester);
        final delete = textInEditor('Удалить задачу');
        await tester.ensureVisible(delete);
        await tester.tap(delete);
        await pumpStorage(tester);
        expect(surface, findsNothing);
        expect(
          await tester.runAsync(() => repository.getById(task.id)),
          isNull,
        );
        expect(
          await tester.runAsync(() => repository.getById(previous.id)),
          isNotNull,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await disposeTestApp(tester, app);
      }
    },
  );

  testWidgets(
    'global editor creates and edits without leaving a screen or resizing its content',
    (tester) async {
      tester.view.physicalSize = const Size(1500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('pulse');
      await pumpStorage(tester);
      final filter = app.tasksViewModel.currentFilterValue;
      final initialScreenRect = tester.getRect(find.byType(PulseScreen));
      final create = find.byKey(const ValueKey('task-editor.create'));
      final surface = find.byKey(const ValueKey('task-editor.surface'));
      app.tasksViewModel.showForm();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(tester.getTopLeft(surface).dx, greaterThan(1150));
      await tester.pumpAndSettle();
      expect(surface, findsOneWidget);
      expect(tester.getTopLeft(surface).dy, closeTo(0, 1));
      expect(tester.getRect(surface).right, closeTo(1500, 1));
      expect(tester.getSize(surface).width, closeTo(350, 1));
      expect(
        tester
            .widget<CollapsibleTaskForm>(find.byType(CollapsibleTaskForm))
            .forceExpanded,
        isTrue,
      );
      expect(create, findsNothing);
      expect(app.navigation.selectedId, 'pulse');
      expect(tester.getRect(find.byType(PulseScreen)), initialScreenRect);
      final title = find
          .descendant(of: surface, matching: find.byType(TextField))
          .first;
      await tester.enterText(title, 'Черновик поверх любого экрана');
      final form = tester.state(find.byType(TaskFormContent));
      await tester.tap(find.byKey(const ValueKey('navigation-rail:workspace')));
      await pumpStorage(tester);
      expect(find.text('Черновик поверх любого экрана'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('task-editor.save')).hitTestable(),
        findsOneWidget,
      );
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TaskFormContent)), same(form));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsNothing);
      expect(
        tester
            .widget<CollapsibleTaskForm>(find.byType(CollapsibleTaskForm))
            .forceExpanded,
        isFalse,
      );
      expect(find.text('Черновик поверх любого экрана'), findsOneWidget);
      final sheet = find.byType(CollapsibleSheet);
      final sheetContainer = find
          .descendant(of: sheet, matching: find.byType(AnimatedContainer))
          .first;
      expect(tester.getSize(sheetContainer).height, 190);
      final handle = find
          .descendant(of: sheet, matching: find.byType(GestureDetector))
          .first;
      await tester.drag(handle, const Offset(0, -250));
      await tester.pumpAndSettle();
      expect(tester.getSize(sheetContainer).height, greaterThan(190));
      await tester.tap(find.byKey(const ValueKey('task-editor.save')));
      await pumpStorage(tester);
      final saved = (await tester.runAsync(
        () => app.tasksRepository.watchTasks().first,
      ))!.single;
      expect(saved.title, 'Черновик поверх любого экрана');
      expect(surface, findsNothing);
      expect(app.navigation.selectedId, 'workspace');

      final context = app.navigation.contextFor(
        app.ui.screens.firstWhere((screen) => screen.id == 'workspace'),
      );
      expect(
        context.openScreen('tasks', argument: saved, select: false),
        isTrue,
      );
      await pumpStorage(tester);
      expect(app.navigation.selectedId, 'workspace');
      expect(app.tasksViewModel.currentFilterValue, filter);
      expect(find.text('Edit task'), findsOneWidget);
      await tester.enterText(
        find.descendant(of: surface, matching: find.byType(TextField)).first,
        'Изменено',
      );
      await tester.tap(find.byKey(const ValueKey('task-editor.save')));
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(saved.id),
        ))!.title,
        'Изменено',
      );

      for (final id in [
        'pulse',
        'tasks',
        'workspace',
        'projects',
        'resources',
      ]) {
        if (!app.ui.screens.any((screen) => screen.id == id)) continue;
        app.navigation.open(id);
        await pumpStorage(tester);
        expect(
          find.byType(AppBar),
          findsNothing,
          reason: 'No portrait Telegram app bar on $id',
        );
        expect(create, findsNothing);
        expect(find.byType(FloatingActionButton), findsNothing);
      }
      app.tasksViewModel.showForm();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('task-editor.close')));
      await tester.pumpAndSettle();
      expect(surface, findsNothing);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.watchTasks().first,
        ))!.length,
        1,
      );
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );
}
