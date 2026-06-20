import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/dashboard/presentation/dashboard_screen.dart';
import 'package:life_os/features/projects/presentation/projects_screen.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';
import 'package:life_os/features/timer/presentation/timer_screen.dart';

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
    return Scaffold(
      appBar: AppBar(toolbarHeight: 0),
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
    (Icons.bolt_rounded, 'Pulse'),
    (Icons.format_list_bulleted_rounded, 'Tasks'),
    (Icons.grid_view_rounded, 'Projects'),
    (Icons.menu_book_rounded, 'Library'),
    //(Icons.gps_fixed_rounded, 'Goals'),
  ];

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFE4C4B8);
    const selectedBg = Color(0xFF3A2821);
    const navBg = Color(0xFF181818);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 24 - 4) / itemCount;

        return Container(
          height: constraints.maxHeight * 0.11,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: navBg,
            // borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white10),
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
                  margin: EdgeInsets.symmetric(horizontal:  itemWidth * 0.05),
                  width: itemWidth * 0.9,
                  decoration: BoxDecoration(
                    color: selectedBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              Row(

                
                children: List.generate(itemCount, (index) {

                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onTap(index),
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

class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  // Передаем текущий индекс и колбэк через конструктор
  _BottomNav({
    required this.selectedIndex,
    required this.onDestinationSelected,
  });
  final items = [
    (Icons.bolt, 'Pulse'),
    (Icons.list_alt, 'Tasks'),
    (Icons.grid_view, 'Projects'),
    (Icons.menu_book_outlined, 'Library'),
    (Icons.track_changes, 'Goals'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final icon = entry.value.$1;
          final label = entry.value.$2;

          // Теперь активность зависит от переданного извне индекса
          final isActive = index == selectedIndex;

          return GestureDetector(
            behavior: HitTestBehavior
                .opaque, // Чтобы кликалась вся область, а не только иконка
            onTap: () => onDestinationSelected(index),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppColors.primaryContainer : Colors.white38,
                  size: 22,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive
                        ? AppColors.primaryContainer
                        : Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
