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
      appBar: AppBar(toolbarHeight: 0,),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          DashboardScreen(viewModel: widget.diContainer.dashboardViewModel),
          TasksScreen(viewModel: widget.diContainer.tasksViewModel),
          ProjectsScreen(viewModel: widget.diContainer.projectViewModel),
          ResourcesScreen(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
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
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A)))),
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
            behavior: HitTestBehavior.opaque, // Чтобы кликалась вся область, а не только иконка
            onTap: () => onDestinationSelected(index),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(
                  icon,
                  color: isActive ? AppColors.primaryContainer : Colors.white38,
                  size: 22,
                ),
              const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isActive ? AppColors.primaryContainer : Colors.white38,
                    fontSize: 10,
                  ),
                ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}



