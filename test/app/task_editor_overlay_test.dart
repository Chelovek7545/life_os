import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/features/planner/presentation/planner_screen.dart';
import 'package:life_os/features/tasks/presentation/components/task_form_content.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';
import '../support/test_app.dart';
import 'today_composition_test.dart' show pumpStorage;

void main() {
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
      app.navigation.open('planner');
      await pumpStorage(tester);
      final filter = app.tasksViewModel.currentFilterValue;
      final initialCalendarRect = tester.getRect(find.byType(PlannerScreen));
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
      expect(app.navigation.selectedId, 'planner');
      expect(tester.getRect(find.byType(PlannerScreen)), initialCalendarRect);
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
        'planner',
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
