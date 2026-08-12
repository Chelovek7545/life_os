import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/features/habits/domain/habit_entry_model.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_visuals.dart';

const List<String> _monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const List<String> _weekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Карта дней привычки: по месяцам, каждый день — кружок, закрашенный цветом
/// привычки, если он был выполнен. Тап по дню отмечает/снимает выполнение
/// (в том числе задним числом и до даты создания привычки).
class HabitCalendarMap extends StatelessWidget {
  const HabitCalendarMap({
    super.key,
    required this.habit,
    required this.completedDateKeys,
    this.onToggleDay,
  });

  final Habit habit;

  /// Дата-ключи ("YYYY-MM-DD") выполненных дней.
  final Set<String> completedDateKeys;

  /// Вызывается при тапе по дню (null — тап недоступен).
  final ValueChanged<DateTime>? onToggleDay;

  static const double _cellSize = 18;

  @override
  Widget build(BuildContext context) {
    final accent = habitColorFor(habit.colorHex);
    final now = DateTime.now();
    final months = _monthsFrom(
      DateTime(habit.createdAt.year, habit.createdAt.month),
      DateTime(now.year, now.month),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(habitIconFor(habit.icon), color: accent, size: 15),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                habit.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${completedDateKeys.length} дн.',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final month in months)
          _HabitMonthGrid(
            habit: habit,
            month: month,
            completedDateKeys: completedDateKeys,
            accent: accent,
            onToggleDay: onToggleDay,
          ),
      ],
    );
  }

  List<DateTime> _monthsFrom(DateTime start, DateTime end) {
    final result = <DateTime>[];
    var current = DateTime(start.year, start.month);
    while (!current.isAfter(end)) {
      result.add(current);
      current = DateTime(
        current.year + (current.month == 12 ? 1 : 0),
        current.month == 12 ? 1 : current.month + 1,
      );
    }
    return result;
  }
}

class _HabitMonthGrid extends StatelessWidget {
  const _HabitMonthGrid({
    required this.habit,
    required this.month,
    required this.completedDateKeys,
    required this.accent,
    required this.onToggleDay,
  });

  final Habit habit;
  final DateTime month;
  final Set<String> completedDateKeys;
  final Color accent;
  final ValueChanged<DateTime>? onToggleDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = month.weekday - DateTime.monday;
    final weeks = ((leadingBlanks + daysInMonth) / 7).ceil();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_monthNames[month.month - 1]} ${month.year}',
            style: AppTypography.codeLabel.copyWith(
              color: AppColors.primary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var w = 0; w < 7; w++)
                Expanded(
                  child: Center(
                    child: Text(
                      _weekdayNames[w],
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          for (var week = 0; week < weeks; week++)
            Row(
              children: [
                for (var w = 0; w < 7; w++)
                  Expanded(child: _buildCell(week * 7 + w - leadingBlanks)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCell(int day) {
    if (day < 1 || day > DateTime(month.year, month.month + 1, 0).day) {
      return const SizedBox(
        height: HabitCalendarMap._cellSize,
        width: HabitCalendarMap._cellSize,
      );
    }

    final date = DateTime(month.year, month.month, day);
    final now = DateTime.now();
    final today =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    final dateKey = formatDateKey(date);

    final completed = completedDateKeys.contains(dateKey);
    final scheduled = habit.schedule.isScheduledOn(date);

    final Color fillColor;
    final Color ringColor;
    final bool isFilled;
    if (completed) {
      isFilled = true;
      fillColor = accent;
      ringColor = accent;
    } else {
      isFilled = false;
      fillColor = Colors.transparent;
      ringColor = scheduled
          ? accent.withValues(alpha: isFuture ? 0.25 : 0.55)
          : Colors.white12;
    }

    return Center(
      child: GestureDetector(
        key: ValueKey('habit-day-$dateKey'),
        behavior: HitTestBehavior.opaque,
        onTap: onToggleDay == null ? null : () => onToggleDay!(date),
        child: Container(
          width: HabitCalendarMap._cellSize,
          height: HabitCalendarMap._cellSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? fillColor : null,
            border: Border.all(
              color: today ? Colors.white : ringColor,
              width: today ? 2 : 1,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.45),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: isFilled
              ? const Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black26,
                    ),
                    child: SizedBox(width: 4, height: 4),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
