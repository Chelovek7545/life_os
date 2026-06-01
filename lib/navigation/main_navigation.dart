import 'package:flutter/material.dart';
import 'package:life_os/features/main/presentation/main_screen.dart';
import 'package:life_os/features/projects/presentation/projects_screen.dart';
import 'package:life_os/features/resources/presentation/resources_screen.dart';
import 'package:life_os/features/tasks/presentation/tasks_screen.dart';
import 'package:life_os/features/timer/presentation/timer_screen.dart';

abstract class MainNavigationRouteNames {
  static const loaderWidget = '/';
  static const auth = '/auth';
  static const tasks = '/tasks';
  static const main = '/main';
  static const projects = '/projects';
  static const timer = '/timer';
  static const resources = '/resources';
}

// class MainNavigation {
//   final routes = <String, Widget Function(BuildContext)>{
//     MainNavigationRouteNames.tasks: (_) => const TasksScreen(),
//     //MainNavigationRouteNames.main: (_) => const MainScreen(),
//     MainNavigationRouteNames.projects: (_) => const ProjectsScreen(),
//     MainNavigationRouteNames.timer: (_) => const TimerScreen(),
//     MainNavigationRouteNames.resources: (_) => const ResourcesScreen(),
//   };
// }
