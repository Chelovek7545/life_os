import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';

void main() {
  group('EditProjectCard', () {
    testWidgets('renders form with title and description fields', (
      tester,
    ) async {
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
              child: EditProjectCard(onSave: (_, _, _, _) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      expect(find.text('CONFIGURE NEW PROJECT'), findsOneWidget);
      expect(find.text('OBJECT TITLE'), findsOneWidget);
      expect(find.text('DESCRIPTION MODULE'), findsOneWidget);
    });

    testWidgets('shows CONFIGURE NEW PROJECT title when creating', (
      tester,
    ) async {
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
              child: EditProjectCard(onSave: (_, _, _, _) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      expect(find.text('CONFIGURE NEW PROJECT'), findsOneWidget);
    });

    testWidgets('calls onCancel when cancel button tapped', (tester) async {
      bool cancelled = false;
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
                onSave: (_, _, _, _) {},
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('CANCEL'));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('calls onSave with form data', (tester) async {
      String? savedName;
      String? savedDesc;
      String? savedColor;

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
                onSave: (name, desc, color, dueDate) {
                  savedName = name;
                  savedDesc = desc;
                  savedColor = color;
                },
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextFormField).first, 'My Project');
      await tester.enterText(
        find.byType(TextFormField).last,
        'Description text',
      );

      await tester.tap(find.text('INITIALIZE PROJECT'));
      await tester.pump();

      expect(savedName, 'My Project');
      expect(savedDesc, 'Description text');
      expect(savedColor, isNotNull);
    });

    testWidgets('shows INITIALIZE PROJECT when creating', (tester) async {
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
              child: EditProjectCard(onSave: (_, _, _, _) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      expect(find.text('INITIALIZE PROJECT'), findsOneWidget);
    });

    testWidgets('renders color palette options', (tester) async {
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
              child: EditProjectCard(onSave: (_, _, _, _) {}, onCancel: () {}),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('does not save when title is empty', (tester) async {
      bool saved = false;
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
                onSave: (_, _, _, _) => saved = true,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '');
      await tester.tap(find.text('INITIALIZE PROJECT'));
      await tester.pump();

      expect(saved, isFalse);
    });
  });
}
