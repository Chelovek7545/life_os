import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';

void main() {
  group('EditProjectCard', () {
    testWidgets('renders form with title and description fields', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
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
              child: EditProjectCard(onSave: (_) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      expect(find.text('Новый проект'), findsOneWidget);
      expect(find.text('Название проекта'), findsOneWidget);
      expect(find.text('Описание'), findsOneWidget);
    });

    testWidgets('shows Новый проект title when creating', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
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
              child: EditProjectCard(onSave: (_) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      expect(find.text('Новый проект'), findsOneWidget);
    });

    testWidgets('calls onCancel when cancel button tapped', (tester) async {
      bool cancelled = false;
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
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
              child: EditProjectCard(
                onSave: (_) {},
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Отмена'));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('calls onSave with form data', (tester) async {
      String? savedName;
      String? savedDesc;
      String? savedColor;

      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
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
              child: EditProjectCard(
                onSave: (project) {
                  savedName = project.name;
                  savedDesc = project.description;
                  savedColor = project.color;
                },
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'My Project');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Description text',
      );

      await tester.tap(find.text('Создать проект'));
      await tester.pump();

      expect(savedName, 'My Project');
      expect(savedDesc, 'Description text');
      expect(savedColor, isNotNull);
    });

    testWidgets('shows Создать проект when creating', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
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
              child: EditProjectCard(onSave: (_) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      expect(find.text('Создать проект'), findsOneWidget);
    });

    testWidgets('opens and closes the color controls from the swatch', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
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
              child: EditProjectCard(onSave: (_) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      final colorButton = find.widgetWithText(OutlinedButton, 'Цвет');
      expect(find.byType(Slider), findsNothing);
      expect(find.text('HEX'), findsNothing);
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('#FF5C00'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).last, '#12');
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      expect(find.byType(Slider), findsNothing);
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      expect(find.text('#FF5C00'), findsOneWidget);
      await tester.tap(colorButton);
      await tester.pumpAndSettle();
      final blank = tester.getRect(find.widgetWithText(ChoiceChip, 'Пустой'));
      final study = tester.getRect(find.widgetWithText(ChoiceChip, 'Учёба'));
      expect(study.top, blank.top);
      expect(study.left - blank.right, closeTo(8, 0.1));
      await tester.tap(find.text('Учёба'));
      await tester.pump();
      final description = tester.widget<TextFormField>(
        find.byType(TextFormField).at(1),
      );
      expect(description.controller!.text, contains('План занятий'));
      await tester.tap(find.text('Пустой'));
      await tester.pump();
      expect(description.controller!.text, isEmpty);
    });

    testWidgets('does not save when title is empty', (tester) async {
      bool saved = false;
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
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
              child: EditProjectCard(
                onSave: (_) => saved = true,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '');
      await tester.tap(find.text('Создать проект'));
      await tester.pump();

      expect(saved, isFalse);
    });
  });
}
