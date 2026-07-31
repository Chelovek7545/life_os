import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

/// Виджет статистики — заглушка.
///
/// Показывает две метрики (Done / Due) с нулевыми значениями.
/// В будущем можно подключить реальные данные из аналитики.
class StatisticsWidget extends StatelessWidget {
  const StatisticsWidget({super.key});

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
            _StatItem(label: 'Done', value: '0', color: AppColors.primary),
            _StatItem(label: 'Due', value: '0', color: AppColors.tertiary),
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
