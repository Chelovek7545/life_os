import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen.dart';
import 'package:life_os/features/projects/presentation/projects_screen.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';

class MainScreen extends StatefulWidget {
  final DependencyContainer diContainer;
  const MainScreen({super.key, required this.diContainer});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  //static const _titles = ['Main', 'Projects & Routines', 'Timer', 'Ресурсы'];

  //final List<Widget> _screens =

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        
          backgroundColor: AppColors.surfaceDim,
          resizeToAvoidBottomInset: true,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            DashboardScreen(viewModel: widget.diContainer.dashboardViewModel),
            TasksScreen(viewModel: widget.diContainer.tasksViewModel),
            ProjectsScreen(viewModel: widget.diContainer.projectViewModel),
            ResourcesScreen(),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: SlidingNavBar(
            selectedIndex: _selectedIndex,
            onTap: _onItemTapped,
          ),
        ),
      ),
    );
  }
}

class SlidingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const SlidingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const itemCount = 4;

  static const items = [
    (Icons.bolt_rounded, 'PULSE'),
    (Icons.format_list_bulleted_rounded, 'TASKS'),
    (Icons.hub_outlined, 'PROJECTS'),
    (Icons.menu_book_rounded, 'LIBRARY'),
    //(Icons.gps_fixed_rounded, 'Goals'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 24 - 4) / itemCount;
        final double navBarHeight = constraints.maxHeight * 0.1 > 70.0
            ? constraints.maxHeight * 0.1
            : 70.0; // Высота навигационной панели
        return Container(
          height: navBarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceDim,
            // borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: Stack(
            alignment: AlignmentGeometry.center,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                left: itemWidth * selectedIndex,
                top: 1,
                bottom: 1,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: itemWidth * 0.05),
                  width: itemWidth * 0.9,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderGlass),
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),

              Row(
                children: List.generate(itemCount, (index) {
                  bool selected = selectedIndex == index;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onTap(index),
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        scale: selected ? 1.05 : 1.0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  if (selected)
                                    BoxShadow(
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        68,
                                        0,
                                      ).withValues(alpha: 0.6),
                                      blurRadius: 15,
                                      spreadRadius: -4,
                                    ),
                                ],
                              ),
                              child: Icon(
                                items[index].$1,
                                color: selected
                                    ? AppColors.primaryContainer
                                    : AppColors.onBackground,

                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[index].$2,
                              style: AppTypography.codeLabel.copyWith(
                                color: selected
                                    ? AppColors.primaryContainer
                                    : AppColors.onBackground,
                                shadows: [
                                  if (selected)
                                    Shadow(
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        68,
                                        0,
                                      ).withValues(alpha: 0.8),
                                      blurRadius: 20,
                                    ),
                                ],
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedOpacity(
                              opacity: selected ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                height: 2.5,
                                width: 20,
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color.fromARGB(
                                        255,
                                        255,
                                        68,
                                        0,
                                      ).withValues(alpha: 0.6),
                                      blurRadius: 15,
                                      spreadRadius: -4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const CustomBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.bolt_rounded, 'Pulse'),
      (Icons.format_list_bulleted_rounded, 'Tasks'),
      (Icons.grid_view_rounded, 'Projects'),
      (Icons.menu_book_rounded, 'Library'),
      (Icons.gps_fixed_rounded, 'Goals'),
    ];

    const accent = Color(0xFFE4C4B8);
    const selectedBg = Color(0xFF3A2821);
    const navBg = Color(0xFF181818);

    return Container(
      //margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: navBg,
        // borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final selected = selectedIndex == index;

          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected ? selectedBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(items[index].$1, color: accent, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    items[index].$2,
                    style: const TextStyle(
                      color: accent,
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
