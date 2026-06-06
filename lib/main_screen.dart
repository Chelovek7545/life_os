import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
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

  static const _titles = ['Main', 'Projects & Routines', 'Timer', 'Ресурсы'];

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
          TasksScreen(viewModel: widget.diContainer.tasksViewModel),
          ProjectsScreen(viewModel: widget.diContainer.projectViewModel),
          TimerScreen(),
          ResourcesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onItemTapped,
        destinations: [
          NavigationDestination(icon: Icon(Icons.task), label: 'Tasks'),
          NavigationDestination(
            icon: Icon(Icons.table_rows_rounded),
            label: 'Projects',
          ),
          NavigationDestination(icon: Icon(Icons.timer), label: 'Timer'),
          NavigationDestination(
            icon: Icon(Icons.bookmarks),
            label: 'Resources',
          ),
        ],
      ),
    );
  }
}
