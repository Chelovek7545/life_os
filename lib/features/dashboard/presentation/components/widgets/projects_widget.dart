import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/projects/data/projects_repository.dart';

/// Виджет дашборда — счётчик активных проектов.
///
/// Аналог [TaskListWidget], но для проектов.
/// Подписывается на [ProjectsRepository.watchAllProjects].
class ProjectsWidget extends StatefulWidget {
  const ProjectsWidget({super.key});

  @override
  State<ProjectsWidget> createState() => _ProjectsWidgetState();
}

class _ProjectsWidgetState extends State<ProjectsWidget> {
  final ProjectsRepository _repo = DependencyContainer().projectsRepository;
  int _count = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchAllProjects().listen((projects) {
      if (mounted) setState(() => _count = projects.length);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.hub_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Projects',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const Spacer(),
        Text(
          '$_count',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        Text(
          'active projects',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
