import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_panels.dart';
import 'package:habits_api/habits_api.dart';
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_card.dart';
import 'package:life_os/features/habits/presentation/habits_calendar_panel.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:projects_api/projects_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:life_os/core/ui/hierarchy/heirarchy_view.dart';
import 'package:life_os/features/lifegraph/presentation/pulse_screen.dart';
import 'package:life_os/app.dart';
import 'package:life_os/app/plugins/workspace_plugin_adapter.dart';
import 'package:life_os/features/tasks/presentation/components/task_calendar.dart';
import 'package:life_os/features/workspace/presentation/workspace_screen.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
  testWidgets(
    'all workspace editors show shared data and habits keep independent dates',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      final project = Project.create(name: 'Workspace project');
      final habit = Habit.create(
        title: 'Workspace habit',
        type: const MorningHabit(),
      );
      final sphere = Sphere.create(name: 'Workspace sphere');
      await tester.runAsync(() async {
        await app.projectsRepository.addProject(project);
        await app.habitsRepository.addHabit(habit);
        await app.spheresRepository.addSphere(sphere);
      });
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('workspace');
      await pumpStorage(tester);
      final workspace = find.byType(WorkspaceScreen);
      final screen = tester.widget<WorkspaceScreen>(workspace);
      final controller = screen.controller;
      controller.setEditing(true);
      expect(screen.editors.map((editor) => editor.id).toSet(), {
        'tasks',
        'calendar',
        'hierarchy',
        'habits',
        'stats',
        'spheres',
      });
      final id = controller.selectedId;
      controller.changeEditor(id, 'hierarchy');
      await pumpStorage(tester);
      expect(
        find.descendant(of: workspace, matching: find.byType(HierarchyColumn)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: workspace, matching: find.text(project.name)),
        findsOneWidget,
      );
      controller.changeEditor(id, 'habits');
      await pumpStorage(tester);
      final panelFinder = find.descendant(
        of: workspace,
        matching: find.byType(TodaysHabitsPanel),
      );
      final firstModel = tester
          .widget<TodaysHabitsPanel>(panelFinder)
          .viewModel;
      final primaryDate = app.habitsViewModel.selectedDate;
      await tester.tap(
        find.descendant(of: workspace, matching: find.byTooltip('Toggle')),
      );
      await pumpStorage(tester);
      expect(
        tester
            .widget<HabitCard>(
              find.descendant(of: workspace, matching: find.byType(HabitCard)),
            )
            .item
            .isCompleted,
        isTrue,
      );
      await tester.tap(
        find.descendant(
          of: workspace,
          matching: find.byTooltip('Редактировать привычки'),
        ),
      );
      await pumpStorage(tester);
      expect(find.byTooltip('New habit'), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await pumpStorage(tester);
      await tester.tap(
        find.descendant(
          of: workspace,
          matching: find.byTooltip('Карта выполненных дней'),
        ),
      );
      await pumpStorage(tester);
      expect(find.byType(HabitsCalendarPanel), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть карту привычек'));
      await pumpStorage(tester);
      final otherId = controller.layout.root.panes.last.id;
      controller.changeEditor(otherId, 'habits');
      await pumpStorage(tester);
      final models = tester
          .widgetList<TodaysHabitsPanel>(
            find.descendant(
              of: workspace,
              matching: find.byType(TodaysHabitsPanel),
            ),
          )
          .map((panel) => panel.viewModel)
          .toList();
      expect(identical(models[0], models[1]), isFalse);
      firstModel.selectDate(DateTime(2030, 1, 1));
      await pumpStorage(tester);
      expect(models[1].selectedDate, isNot(DateTime(2030, 1, 1)));
      expect(app.habitsViewModel.selectedDate, primaryDate);
      controller.changeEditor(id, 'stats');
      await pumpStorage(tester);
      expect(
        find.descendant(of: workspace, matching: find.byType(StatsPanel)),
        findsOneWidget,
      );
      controller.changeEditor(id, 'spheres');
      await pumpStorage(tester);
      expect(
        find.descendant(of: workspace, matching: find.text(sphere.name)),
        findsOneWidget,
      );
      await tester.runAsync(controller.flush);
      final prefs = await SharedPreferences.getInstance();
      expect(
        WorkspaceLayout.decode(
          prefs.getString('workspace.layout.v1')!,
          controller.editorIds,
        )!.root.panes.first.editorId,
        'spheres',
      );
      tester.view.physicalSize = const Size(390, 844);
      await pumpStorage(tester);
      expect(find.byType(AppBar), findsNothing);
      for (final editor in ['hierarchy', 'habits', 'stats', 'spheres']) {
        controller.changeEditor(controller.selectedId, editor);
        await pumpStorage(tester);
        expect(tester.takeException(), isNull, reason: editor);
      }
      await disposeTestApp(tester, app);
    },
  );

  testWidgets(
    'workspace panels share writes, isolate filters, restore layout and release resources',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1050);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final app = (await tester.runAsync(
        () => createTestApp(enableObsidian: false),
      ))!;
      await tester.pumpWidget(MyApp(diContainer: app));
      app.navigation.open('workspace');
      await pumpStorage(tester);
      final workspace = find.byType(WorkspaceScreen);
      final controller = tester.widget<WorkspaceScreen>(workspace).controller;
      controller.setEditing(true);
      final list = tester.widget<TasksPanel>(
        find.descendant(of: workspace, matching: find.byType(TasksPanel)),
      );
      final calendar = tester.widget<TaskCalendar>(
        find.descendant(of: workspace, matching: find.byType(TaskCalendar)),
      );
      final original = app.tasksViewModel.currentFilterValue;
      expect(identical(list.viewModel, calendar.viewModel), isFalse);
      final day = list.viewModel.currentFilterValue.anchorDate;
      final date = DateTime(day.year, day.month, day.day);
      final task = Task.blank().copyWith(
        title: 'Задача рабочего пространства',
        startsAt: Wrapped(date.copyWith(hour: 10)),
        endsAt: Wrapped(date.copyWith(hour: 11)),
      );
      await tester.runAsync(() => app.tasksRepository.addTask(task));
      await pumpStorage(tester);
      expect(
        find.descendant(of: workspace, matching: find.text(task.title)),
        findsWidgets,
      );
      final taskCard = tester.widget<TaskCard>(
        find.descendant(of: workspace, matching: find.byType(TaskCard)),
      );
      expect(taskCard.task.id, task.id);
      taskCard.onCheckChanged!();
      await pumpStorage(tester);
      expect(
        (await tester.runAsync(
          () => app.tasksRepository.getById(task.id),
        ))!.isCompleted,
        isTrue,
      );
      list.viewModel.updateFilter(
        (filter) => filter.copyWith(anchorDate: DateTime(2030, 1, 2)),
      );
      await pumpStorage(tester);
      expect(
        calendar.viewModel.currentFilterValue.anchorDate,
        isNot(DateTime(2030, 1, 2)),
      );
      expect(app.tasksViewModel.currentFilterValue, original);
      controller.split(controller.selectedId, WorkspaceAxis.vertical);
      controller.changeEditor(controller.selectedId, 'calendar');
      await pumpStorage(tester);
      final expected = controller.layout.encode();
      await tester.runAsync(controller.flush);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('workspace.layout.v1'), expected);
      tester.view.physicalSize = const Size(390, 844);
      await pumpStorage(tester);
      expect(tester.takeException(), isNull);
      // A fresh module restores layout through the actual preferences adapter.
      final registry = PluginUiRegistry();
      final navigation = PluginNavigationController(registry);
      final plugin = createWorkspacePlugin(
        ui: registry,
        tasks: app.tasksRepository,
        projects: app.projectsRepository,
        habits: app.habitsRepository,
        pulse: () => app.pulseScreenViewModel,
      );
      await tester.runAsync(plugin.start);
      final contribution = registry.screens.single;
      final restored =
          contribution.builder(
                tester.element(workspace),
                navigation.contextFor(contribution),
              )
              as WorkspaceScreen;
      expect(restored.controller.layout.encode(), expected);
      await tester.runAsync(plugin.stop);
      expect(restored.controller.isActive, isFalse);
      // Retained callbacks cannot change a stopped generation.
      restored.controller.split(
        restored.controller.selectedId,
        WorkspaceAxis.vertical,
      );
      expect(restored.controller.layout.encode(), expected);
      await tester.runAsync(plugin.start);
      final nextContribution = registry.screens.single;
      final restarted =
          nextContribution.builder(
                tester.element(workspace),
                navigation.contextFor(nextContribution),
              )
              as WorkspaceScreen;
      expect(identical(restarted.controller, restored.controller), isFalse);
      restored.controller.changeEditor(restored.controller.selectedId, 'tasks');
      expect(restarted.controller.layout.encode(), expected);
      await tester.runAsync(plugin.stop);
      navigation.dispose();
      registry.dispose();
      await disposeTestApp(tester, app);
      expect(list.viewModel.isActive, isFalse);
      expect(calendar.viewModel.isActive, isFalse);
      expect(controller.isActive, isFalse);
    },
  );

  testWidgets('invalid preference types fall back without blocking startup', (
    tester,
  ) async {
    final app = (await tester.runAsync(
      () => createTestApp(enableObsidian: false),
    ))!;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('workspace.layout.v1', 42);
    final registry = PluginUiRegistry();
    final navigation = PluginNavigationController(registry);
    final plugin = createWorkspacePlugin(
      ui: registry,
      tasks: app.tasksRepository,
      projects: app.projectsRepository,
      habits: app.habitsRepository,
      pulse: () => app.pulseScreenViewModel,
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.runAsync(plugin.start);
    final contribution = registry.screens.single;
    final screen =
        contribution.builder(
              tester.element(find.byType(SizedBox).first),
              navigation.contextFor(contribution),
            )
            as WorkspaceScreen;
    expect(screen.controller.layout.encode(), WorkspaceLayout.initial.encode());
    expect(prefs.get('workspace.layout.v1'), 42);
    await tester.runAsync(plugin.stop);
    navigation.dispose();
    registry.dispose();
    await disposeTestApp(tester, app);
  });
}
