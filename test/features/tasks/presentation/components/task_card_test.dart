import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/presentation/components/task_card.dart';

Widget createTaskCard({
  String title = 'Test Task',
  DateTime? dueDate,
  String? projectTitle,
  List<Tag> tags = const [],
  bool completed = false,
  bool isSelected = false,
  VoidCallback? onTap,
  VoidCallback? onCheckChanged,
  VoidCallback? onLongPress,
  VoidCallback? onSelected,
}) {
  return MaterialApp(
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppColors.surfaceDim,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        onSurface: Colors.white,
      ),
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TaskCard(
          title: title,
          dueDate: dueDate,
          projectTitle: projectTitle,
          tags: tags,
          completed: completed,
          isSelected: isSelected,
          onTap: onTap,
          onCheckChanged: onCheckChanged,
          onLongPress: onLongPress,
          onSelected: onSelected,
        ),
      ),
    ),
  );
}

void main() {
  group('TaskCard', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(createTaskCard(title: 'My Task'));
      expect(find.text('My Task'), findsOneWidget);
    });

    testWidgets('renders due date when provided', (tester) async {
      final date = DateTime(2024, 12, 25);
      await tester.pumpWidget(createTaskCard(dueDate: date));
      expect(find.text('25.12.2024'), findsOneWidget);
    });

    testWidgets('does not render due date when null', (tester) async {
      await tester.pumpWidget(createTaskCard());
      expect(find.text('25.12.2024'), findsNothing);
    });

    testWidgets('renders project title when provided', (tester) async {
      await tester.pumpWidget(createTaskCard(projectTitle: 'Work'));
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('renders tags', (tester) async {
      final tags = [
        Tag(id: 1, name: 'urgent', colorHex: 0xFF0000),
        Tag(id: 2, name: 'design', colorHex: 0x00FF00),
      ];
      await tester.pumpWidget(createTaskCard(tags: tags));

      expect(find.text('urgent'), findsOneWidget);
      expect(find.text('design'), findsOneWidget);
    });

    testWidgets('calls onCheckChanged when completion button tapped', (tester) async {
      bool checked = false;
      await tester.pumpWidget(createTaskCard(
        completed: true,
        onCheckChanged: () => checked = true,
      ));

      await tester.tap(find.byIcon(Icons.check).last);
      await tester.pump();

      expect(checked, isTrue);
    });

    testWidgets('calls onSelected when select box tapped', (tester) async {
      bool selected = false;
      await tester.pumpWidget(createTaskCard(
        isSelected: false,
        onSelected: () => selected = true,
      ));

      await tester.tap(find.byType(AnimatedContainer).last);
      await tester.pump();

      expect(selected, isTrue);
    });

    testWidgets('calls onLongPress on long press', (tester) async {
      bool longPressed = false;
      await tester.pumpWidget(createTaskCard(
        onLongPress: () => longPressed = true,
      ));

      await tester.longPress(find.byType(TaskCard));
      await tester.pump();

      expect(longPressed, isTrue);
    });

    testWidgets('shows check icon when completed', (tester) async {
      await tester.pumpWidget(createTaskCard(completed: true));
      expect(find.byIcon(Icons.check), findsAtLeast(1));
    });
  });
}
