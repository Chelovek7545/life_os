import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';

void main() {
  group('EditProjectCard', () {
<<<<<<< HEAD
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
              child: EditProjectCard(
                onSave: (_, __, ___, ____) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
=======
    testWidgets('renders form with title and description fields', (tester) async {
      await tester.pumpWidget(MaterialApp(
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
              onSave: (_, __, ___, ____) {},
              onCancel: () {},
            ),
          ),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      expect(find.text('CONFIGURE NEW PROJECT'), findsOneWidget);
      expect(find.text('OBJECT TITLE'), findsOneWidget);
      expect(find.text('DESCRIPTION MODULE'), findsOneWidget);
    });

<<<<<<< HEAD
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
              child: EditProjectCard(
                onSave: (_, __, ___, ____) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
=======
    testWidgets('shows CONFIGURE NEW PROJECT title when creating', (tester) async {
      await tester.pumpWidget(MaterialApp(
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
              onSave: (_, __, ___, ____) {},
              onCancel: () {},
            ),
          ),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      expect(find.text('CONFIGURE NEW PROJECT'), findsOneWidget);
    });

    testWidgets('calls onCancel when cancel button tapped', (tester) async {
      bool cancelled = false;
<<<<<<< HEAD
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
                onSave: (_, __, ___, ____) {},
                onCancel: () => cancelled = true,
              ),
            ),
          ),
        ),
      );
=======
      await tester.pumpWidget(MaterialApp(
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
              onSave: (_, __, ___, ____) {},
              onCancel: () => cancelled = true,
            ),
          ),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      await tester.tap(find.text('CANCEL'));
      await tester.pump();

      expect(cancelled, isTrue);
    });

    testWidgets('calls onSave with form data', (tester) async {
      String? savedName;
      String? savedDesc;
      String? savedColor;
      DateTime? savedDueDate;

<<<<<<< HEAD
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
                  savedDueDate = dueDate;
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
=======
      await tester.pumpWidget(MaterialApp(
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
                savedDueDate = dueDate;
              },
              onCancel: () {},
            ),
          ),
        ),
      ));

      await tester.enterText(find.byType(TextFormField).first, 'My Project');
      await tester.enterText(find.byType(TextFormField).last, 'Description text');
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      await tester.tap(find.text('INITIALIZE PROJECT'));
      await tester.pump();

      expect(savedName, 'My Project');
      expect(savedDesc, 'Description text');
      expect(savedColor, isNotNull);
    });

    testWidgets('shows INITIALIZE PROJECT when creating', (tester) async {
<<<<<<< HEAD
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
                onSave: (_, __, ___, ____) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
=======
      await tester.pumpWidget(MaterialApp(
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
              onSave: (_, __, ___, ____) {},
              onCancel: () {},
            ),
          ),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      expect(find.text('INITIALIZE PROJECT'), findsOneWidget);
    });

    testWidgets('renders color palette options', (tester) async {
<<<<<<< HEAD
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
                onSave: (_, __, ___, ____) {},
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
=======
      await tester.pumpWidget(MaterialApp(
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
              onSave: (_, __, ___, ____) {},
              onCancel: () {},
            ),
          ),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      expect(find.byIcon(Icons.check), findsWidgets);
    });

    testWidgets('does not save when title is empty', (tester) async {
      bool saved = false;
<<<<<<< HEAD
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
                onSave: (_, __, ___, ____) => saved = true,
                onCancel: () {},
              ),
            ),
          ),
        ),
      );
=======
      await tester.pumpWidget(MaterialApp(
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
              onSave: (_, __, ___, ____) => saved = true,
              onCancel: () {},
            ),
          ),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      final titleField = find.byType(TextFormField).first;
      await tester.enterText(titleField, '');
      await tester.tap(find.text('INITIALIZE PROJECT'));
      await tester.pump();

      expect(saved, isFalse);
    });
  });
}
