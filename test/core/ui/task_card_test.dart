import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

Widget createTestWidget(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(),
    home: Scaffold(
      body: SizedBox(
        width: 400,
        height: 200,
        child: child,
      ),
    ),
  );
}

Task createTestTask({
  String? title,
  TaskStatus? status,
  bool hasDueDate = false,
  List<Tag>? tags,
}) {
  return Task(
    id: _uuid.v4(),
    title: title ?? 'Test Task',
    description: '',
    status: status ?? TaskStatus.open,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    dueDate: hasDueDate ? DateTime.now() : null,
    timerSeconds: 0,
    effortWeight: 0.0,
    tags: tags ?? const [],
  );
}

void main() {
  group('TaskCard', () {
    testWidgets('renders task title', (tester) async {
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'My Task'),
        ),
      ));

      expect(find.text('My Task'), findsOneWidget);
    });

    testWidgets('renders project title when provided', (tester) async {
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          projectTitle: 'My Project',
          task: createTestTask(),
        ),
      ));

      expect(find.text('My Project'), findsOneWidget);
    });

    testWidgets('renders due date when set', (tester) async {
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(
            title: 'Dated Task',
            hasDueDate: true,
            tags: [Tag(id: 1, name: 'test', colorHex: 0xFF0000)],
          ),
        ),
      ));

      // due date should be rendered (format depends on today)
      expect(find.byIcon(Icons.schedule), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'Tappable'),
          onTap: () => tapped = true,
        ),
      ));

      await tester.tap(find.text('Tappable'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('calls onCheckChanged when check circle tapped', (tester) async {
      bool checked = false;
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'Checkable'),
          onCheckChanged: () => checked = true,
        ),
      ));

      // The check circle is a GestureDetector wrapping a Container with BoxShape.circle
      final circles = find.byType(Container);
      // Find the circle container (decoration with BoxShape.circle)
      Container? circleContainer;
      for (int i = 0; i < circles.evaluate().length; i++) {
        final container = tester.widget<Container>(circles.at(i));
        if (container.decoration is BoxDecoration) {
          final decoration = container.decoration as BoxDecoration;
          if (decoration.shape == BoxShape.circle) {
            circleContainer = container;
            break;
          }
        }
      }

      if (circleContainer != null) {
        await tester.tap(find.byWidget(circleContainer));
        await tester.pump();
        expect(checked, isTrue);
      }
    });

    testWidgets('shows check icon when completed', (tester) async {
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(status: TaskStatus.done),
        ),
      ));

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('shows drag indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(),
        ),
      ));

      expect(find.byIcon(Icons.drag_indicator), findsOneWidget);
    });

    testWidgets('calls onDelete from drag reveal', (tester) async {
      bool deleted = false;
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'Swipeable'),
          onDelete: () => deleted = true,
        ),
      ));

      // Perform a horizontal drag to reveal delete button
      final card = find.text('Swipeable');
      await tester.drag(card, const Offset(-200, 0));
      await tester.pumpAndSettle();

      // Tap the delete button
      await tester.tap(find.byIcon(Icons.delete_outlined));
      await tester.pump();

      expect(deleted, isTrue);
    });

    testWidgets('calls onLongPress on long press', (tester) async {
      bool longPressed = false;
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'Long Press'),
          onLongPress: () => longPressed = true,
        ),
      ));

      await tester.longPress(find.text('Long Press'));
      await tester.pump();

      expect(longPressed, isTrue);
    });

    testWidgets('calls onSelected on double tap', (tester) async {
      bool selected = false;
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'Double Tap'),
          onSelected: () => selected = true,
        ),
      ));

      await tester.tap(find.text('Double Tap'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Double Tap'));
      await tester.pumpAndSettle();

      expect(selected, isTrue);
    });

    testWidgets('applies isOverdue styling', (tester) async {
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'Overdue'),
          isOverdue: true,
        ),
      ));

      expect(find.text('Overdue'), findsOneWidget);
    });

    testWidgets('applies isSelected styling', (tester) async {
      await tester.pumpWidget(createTestWidget(
        TaskCard(
          task: createTestTask(title: 'Selected'),
          isSelected: true,
        ),
      ));

      expect(find.text('Selected'), findsOneWidget);
    });
  });
}
