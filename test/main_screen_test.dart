import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/main_screen.dart';

void main() {
  group('SlidingNavBar', () {
    testWidgets('renders all nav items', (tester) async {
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
          home: const Scaffold(
            body: SlidingNavBar(selectedIndex: 0, onTap: _noop),
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
        home: const Scaffold(
          body: SlidingNavBar(selectedIndex: 0, onTap: _noop),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      expect(find.text('PULSE'), findsOneWidget);
      expect(find.text('TASKS'), findsOneWidget);
      expect(find.text('PROJECTS'), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
    });

    testWidgets('highlights selected item', (tester) async {
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
          home: const Scaffold(
            body: SlidingNavBar(selectedIndex: 2, onTap: _noop),
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
        home: const Scaffold(
          body: SlidingNavBar(selectedIndex: 2, onTap: _noop),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      expect(find.text('PROJECTS'), findsOneWidget);
    });

    testWidgets('calls onTap when item is tapped', (tester) async {
      int tapped = -1;
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
            body: SlidingNavBar(
              selectedIndex: 0,
              onTap: (index) => tapped = index,
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
          body: SlidingNavBar(
            selectedIndex: 0,
            onTap: (index) => tapped = index,
          ),
        ),
      ));
>>>>>>> d7ef432f3f844238948e716c680c6d6572345791

      await tester.tap(find.text('TASKS'));
      await tester.pump();

      expect(tapped, 1);
    });
  });
}

void _noop(int _) {}
