import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';

/// Виджет дашборда — счётчик активных задач.
///
/// Подписывается на [TasksRepository.watchTasks] при инициализации
/// и показывает количество задач. Данные живые — обновляются
/// при любом изменении в таблице tasks.
class TaskListWidget extends StatefulWidget {
  const TaskListWidget({super.key});

  @override
  State<TaskListWidget> createState() => _TaskListWidgetState();
}

class _TaskListWidgetState extends State<TaskListWidget> {
  final TasksRepository _repo = DependencyContainer().tasksRepository;
  int _count = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchTasks().listen((tasks) {
      if (mounted) setState(() => _count = tasks.length);
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
            Icon(Icons.checklist_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Tasks',
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
          'active tasks',
          style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
