import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/app_dropdown_menu.dart';
import 'package:life_os/features/tasks/presentation/components/task_form_content.dart';
import 'package:tasks_api/tasks_api.dart';
import '../../../../test_helpers.dart';

void main() {
  testWidgets(
    'shared dropdowns preserve status selection and nullable project selection',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final original = createMockTask(projectId: 'project-a');
      Task? changed;
      Task? submitted;
      await tester.pumpWidget(
        createTestWidget(
          child: SingleChildScrollView(
            child: TaskFormContent(
              task: original,
              projects: Stream.value([
                createMockProject(id: 'project-a', name: 'Project A'),
              ]),
              isEditMode: true,
              onSubmit: (task) => submitted = task,
              onDelete: (_) {},
              onChanged: (task) => changed = task,
              midProgress: 1,
              maxProgress: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final status = find.byType(AppDropdownMenu<TaskStatus>);
      await tester.ensureVisible(status);
      await tester.tap(status);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'In Progress').hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(changed!.status, TaskStatus.inProgress);
      final project = find.byType(AppDropdownMenu<String?>);
      await tester.ensureVisible(project);
      await tester.tap(project);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(MenuItemButton, 'No project').hitTestable(),
      );
      await tester.pumpAndSettle();
      expect(changed!.projectId, isNull);
      tester.state<TaskFormContentState>(find.byType(TaskFormContent)).submit();
      expect(submitted!.status, TaskStatus.inProgress);
      expect(submitted!.projectId, isNull);
      expect(submitted!.id, original.id);
      expect(tester.takeException(), isNull);
    },
  );
}
