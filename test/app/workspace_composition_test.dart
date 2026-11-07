import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_panels.dart';
import 'package:life_os/app.dart';
import 'package:life_os/app/plugins/workspace_plugin_adapter.dart';
import 'package:life_os/features/tasks/presentation/components/task_calendar.dart';
import 'package:life_os/features/workspace/presentation/workspace_screen.dart';
import 'package:life_os/features/workspace/workspace_layout.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
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
      await tester.runAsync(() => list.viewModel.toggleTask(task));
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
