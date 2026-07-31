import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';

/// Мини-календарь на текущий месяц.
///
/// StatelessWidget — перерисовывается при каждом билде.
/// Показывает 4 строки × 7 дней, подсвечивает сегодня.
///
/// Заглушка — в будущем можно добавить события из БД.
class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key});

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
                return Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.primaryContainer.withValues(alpha: 0.3) : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isValid ? '$day' : '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isToday ? AppColors.primary : AppColors.onSurface,
                      ),
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
