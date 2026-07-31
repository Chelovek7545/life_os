import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';
import 'package:life_os/features/dashboard/presentation/components/widgets/task_stats.dart';

/// Виджет статистики по задачам.
///
/// Показывает две метрики: выполнено (Done) и задач с дедлайном (Due).
/// Данные живые — обновляются при любом изменении в таблице tasks.
class StatisticsWidget extends StatefulWidget {
  const StatisticsWidget({super.key});

  @override
  State<StatisticsWidget> createState() => _StatisticsWidgetState();
}

class _StatisticsWidgetState extends State<StatisticsWidget> {
  final TasksRepository _repo = DependencyContainer().tasksRepository;
  int _done = 0;
  int _due = 0;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchTasks().listen((tasks) {
      if (!mounted) return;
      final stats = computeTaskStats(tasks);
      setState(() {
        _done = stats.done;
        _due = stats.due;
      });
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
            Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Stats',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(label: 'Done', value: '$_done', color: AppColors.primary),
            _StatItem(label: 'Due', value: '$_due', color: AppColors.tertiary),
          ],
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
