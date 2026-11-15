import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/app.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/features/workspace/presentation/workspace_project_tasks.dart';
import 'package:life_os/features/workspace/presentation/workspace_screen.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  testWidgets(
    'date period includes boundary days and overlapping tasks and resets on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final day = DateUtils.dateOnly(DateTime.now());
      final last = DateTime(day.year, day.month, day.day + 2);
      Task task(String title, DateTime? start, [DateTime? end]) =>
          Task.blank().copyWith(
            title: title,
            startsAt: Wrapped(start),
            endsAt: Wrapped(end),
          );
      final tasks = [
        task('Start boundary', day.copyWith(hour: 0)),
        task('End boundary', last.copyWith(hour: 23, minute: 59)),
        task('Overlapping', DateTime(day.year, day.month, day.day - 2), day),
        task(
          'Before period',
          DateTime(day.year, day.month, day.day - 1, 23, 59),
        ),
        task('After period', DateTime(last.year, last.month, last.day + 1)),
        task('Undated', null),
        task('Deadline only', null).copyWith(dueDate: Wrapped(day)),
        task(
          'Invalid end',
          day.copyWith(hour: 13),
          DateTime(day.year, day.month, day.day - 1),
        ),
      ];
      await tester.runAsync(() async {
        for (final item in tasks) {
          await app.tasksRepository.addTask(item);
        }
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('workspace');
      await pumpStorage(tester);
      final controller = tester
          .widget<WorkspaceScreen>(find.byType(WorkspaceScreen))
          .controller;
      controller.setEditing(true);
      final id = controller.selectedId;
      controller.closePane(controller.layout.root.panes.last.id);
      controller.changeEditor(id, 'projectTasks');
      controller.setEditing(false);
      controller.selectProjectTaskDates(id, day, last);
      await pumpStorage(tester);
      final column = find.byKey(
        const ValueKey('project-tasks.column:unassigned'),
      );
      expect(
        find.descendant(of: column, matching: find.text('4')),
        findsOneWidget,
      );
      expect(find.text('Start boundary'), findsOneWidget);
      for (final title in [
        'Before period',
        'After period',
        'Undated',
        'Deadline only',
      ]) {
        expect(find.text(title), findsNothing);
      }
      final originalFilter = app.tasksViewModel.currentFilterValue;
      await tester.tap(find.byKey(const ValueKey('project-tasks.today')));
      await pumpStorage(tester);
      expect((controller.layout.root.find(id) as WorkspacePane).dateTo, day);
      expect(
        find.descendant(of: column, matching: find.text('3')),
        findsOneWidget,
      );
      expect(app.tasksViewModel.currentFilterValue, originalFilter);
      tester.view.physicalSize = const Size(390, 844);
      await pumpStorage(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('project-tasks.dates')));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      final dialog = tester.element(find.byType(DateRangePickerDialog));
      final localizations = MaterialLocalizations.of(dialog);
      await tester.tap(find.byTooltip(localizations.inputDateModeButtonLabel));
      await tester.pumpAndSettle();
      final inputs = find.descendant(
        of: find.byType(DateRangePickerDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(
        inputs.first,
        localizations.formatCompactDate(day),
      );
      await tester.enterText(
        inputs.last,
        localizations.formatCompactDate(last),
      );
      await tester.tap(find.text('Применить'));
      await pumpStorage(tester);
      expect((controller.layout.root.find(id) as WorkspacePane).dateTo, last);
      expect(
        find.descendant(of: column, matching: find.text('4')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey('project-tasks.dates')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop();
      await pumpStorage(tester);
      expect((controller.layout.root.find(id) as WorkspacePane).dateTo, last);
      await tester.tap(find.byTooltip('Сбросить период'));
      await pumpStorage(tester);
      expect(find.text('Все даты'), findsOneWidget);
      expect(
        find.descendant(of: column, matching: find.text('8')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'project board groups all dates, selects projects and shares task edits',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final a = Project.create(name: 'Альфа', color: '#FF5500');
      final b = Project.create(name: 'Бета');
      final future = Task.blank().copyWith(
        title: 'Задача следующего года',
        projectId: Wrapped(a.id),
        startsAt: Wrapped(DateTime(DateTime.now().year + 1, 2, 1)),
      );
      final done = Task.blank().copyWith(
        title: 'Готовая задача',
        projectId: Wrapped(b.id),
        status: TaskStatus.done,
      );
      final loose = Task.blank().copyWith(title: 'Без привязки');
      await tester.runAsync(() async {
        await app.projectsRepository.addProject(a);
        await app.projectsRepository.addProject(b);
        for (final task in [future, done, loose]) {
          await app.tasksRepository.addTask(task);
        }
      });
      final primaryFilter = app.tasksViewModel.currentFilterValue;
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('workspace');
      await pumpStorage(tester);
      final controller = tester
          .widget<WorkspaceScreen>(find.byType(WorkspaceScreen))
          .controller;
      controller.setEditing(true);
      final id = controller.selectedId;
      controller.closePane(controller.layout.root.panes.last.id);
      controller.changeEditor(id, 'projectTasks');
      controller.setEditing(false);
      await pumpStorage(tester);
      final board = find.byType(WorkspaceProjectTasks);
      Finder column(String projectId) =>
          find.byKey(ValueKey('project-tasks.column:$projectId'));
      expect(
        find.descendant(of: column(a.id), matching: find.text(future.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: column(b.id), matching: find.text(done.title)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: column('unassigned'),
          matching: find.text(loose.title),
        ),
        findsOneWidget,
      );
      final card = tester.widget<TaskCard>(
        find.byKey(ValueKey('project-task:${future.id}')),
      );
      card.onCheckChanged!();
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(future.id),
        ))!.isCompleted,
        isTrue,
      );
      expect(app.tasksViewModel.currentFilterValue, primaryFilter);

      await tester.tap(
        find.descendant(of: board, matching: find.byIcon(Icons.filter_list)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('project-picker:${b.id}')));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Без проекта'));
      await tester.tap(find.text('Применить'));
      await pumpStorage(tester);
      expect(column(a.id), findsOneWidget);
      expect(column(b.id), findsNothing);
      expect(column('unassigned'), findsNothing);
      final selection = controller.layout.root.find(id) as WorkspacePane;
      expect(selection.projectIds, [a.id]);
      expect(selection.showUnassigned, isFalse);

      final c = Project.create(name: 'Гамма');
      await tester.runAsync(() => app.projectsRepository.addProject(c));
      await pumpStorage(tester);
      expect(column(c.id), findsNothing);
      controller.selectProjects(id, null, true);
      await pumpStorage(tester);
      expect(column(c.id), findsOneWidget);
      controller.selectProjects(id, [], false);
      await pumpStorage(tester);
      expect(find.text('Выберите проекты для отображения'), findsOneWidget);

      controller.selectProjects(id, [a.id], false);
      await pumpStorage(tester);
      final beforeOpen = controller.layout.encode();
      tester
          .widget<TaskCard>(find.byKey(ValueKey('project-task:${future.id}')))
          .onTap!();
      await pumpStorage(tester);
      expect(app.navigation.selectedId, 'workspace');
      expect(controller.layout.encode(), beforeOpen);
      app.tasksViewModel.hideForm();
      await pumpStorage(tester);
      tester.view.physicalSize = const Size(390, 844);
      await pumpStorage(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(of: board, matching: find.byIcon(Icons.filter_list)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Бета');
      await tester.pump();
      expect(find.byKey(ValueKey('project-picker:${a.id}')), findsNothing);
      expect(find.byKey(ValueKey('project-picker:${b.id}')), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect((controller.layout.root.find(id) as WorkspacePane).projectIds, [
        a.id,
      ]);
      final model = tester.widget<WorkspaceProjectTasks>(board).model;
      await disposeTestApp(tester, app);
      expect(model.isActive, isFalse);
    },
  );
}
