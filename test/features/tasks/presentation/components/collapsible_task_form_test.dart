import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxdart/rxdart.dart';

import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/tasks/presentation/components/collapsible_task_form.dart';

import '../../../../test_helpers.dart';

void main() {
  group('CollapsibleTaskForm', () {
    late Task task;
    late BehaviorSubject<List<Project>> projectsStream;
    late List<Project> projects;
    late Task submittedTask;
    bool submitted = false;

    setUp(() {
      task = createMockTask(title: 'Test Task');
      projects = [
        createMockProject(id: 'proj-1', name: 'Project A'),
      ];
      projectsStream = BehaviorSubject<List<Project>>.seeded(projects);
      submitted = false;
    });

    tearDown(() {
      projectsStream.close();
    });

    Widget createForm({bool isEditMode = false}) {
      return createTestWidget(
        child: CollapsibleTaskForm(
          task: task,
          height: 500,
          onSubmit: (t) {
            submitted = true;
            submittedTask = t;
          },
          onCancel: () {},
          onDelete: (_) {},
          projects: projectsStream.stream,
          isEditMode: isEditMode,
        ),
      );
    }

    testWidgets('renders form with header and controls', (tester) async {
      await tester.pumpWidget(createForm());
      await tester.pump();

      expect(find.byType(CollapsibleTaskForm), findsOneWidget);
      expect(find.text('New task'), findsOneWidget);
    });

    testWidgets('shows Edit task title in edit mode', (tester) async {
      await tester.pumpWidget(createForm(isEditMode: true));
      await tester.pump();

      expect(find.text('Edit task'), findsOneWidget);
    });

    testWidgets('shows cancel button', (tester) async {
      await tester.pumpWidget(createForm());
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('shows save button', (tester) async {
      await tester.pumpWidget(createForm());
      await tester.pump();

      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('save button submits task', (tester) async {
      await tester.pumpWidget(createForm());
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(submitted, isTrue);
    });
  });
}
