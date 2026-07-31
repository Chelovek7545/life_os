import 'dart:async';
import 'package:flutter/material.dart';
import 'package:life_os/core/di.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/dashboard/presentation/components/widgets/task_stats.dart';
import 'package:life_os/features/tasks/data/tasks_repository.dart';

/// Мини-календарь на текущий месяц с количеством задач по дням.
///
/// Подсвечивает сегодня и показывает точку под числом, если на этот день
/// назначены задачи (по [Task.dueDate]). Данные живые — из таблицы tasks.
class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  final TasksRepository _repo = DependencyContainer().tasksRepository;
  StreamSubscription? _sub;
  Map<int, int> _countsByDay = const {};

  @override
  void initState() {
    super.initState();
    _sub = _repo.watchTasks().listen((tasks) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _countsByDay = tasksCountByDay(tasks, now.month, now.year);
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
    final now = DateTime.now();
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final firstDay = DateTime(now.year, now.month, 1);
    final startWeekday = firstDay.weekday - 1;
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              '${_monthName(now.month)} ${now.year}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: days.map((d) => Expanded(
            child: Text(
              d,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: AppColors.onSurfaceVariant),
            ),
          )).toList(),
        ),
        const SizedBox(height: 4),
        ...List.generate(4, (row) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: List.generate(7, (col) {
                final day = row * 7 + col - startWeekday + 1;
                final isValid = day >= 1 && day <= daysInMonth;
                final isToday = isValid && day == now.day;
                final count = isValid ? (_countsByDay[day] ?? 0) : 0;
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.primaryContainer.withValues(alpha: 0.3)
                          : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isValid ? '$day' : '',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? AppColors.primary
                                : AppColors.onSurface,
                          ),
                        ),
                        SizedBox(height: 1),
                        if (count > 0)
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 4),
                      ],
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ],
    );
  }

  String _monthName(int m) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[m - 1];
  }
}
