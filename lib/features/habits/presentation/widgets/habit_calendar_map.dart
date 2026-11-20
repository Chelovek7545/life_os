import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_panels.dart'
    show habitColorFor, habitIconFor;
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_panel_style.dart';

const _monthNames = [
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

class HabitCalendarMap extends StatelessWidget {
  const HabitCalendarMap({
    super.key,
    required this.habit,
    required this.completedDateKeys,
    this.onToggleDay,
  });

  final Habit habit;
  final Set<String> completedDateKeys;
  final ValueChanged<DateTime>? onToggleDay;

  @override
  Widget build(BuildContext context) {
    final accent = habitColorFor(habit.colorHex);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstMonth = DateTime(habit.createdAt.year, habit.createdAt.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: habitPanelCard(radius: 18),
          child: Row(
            children: [
              HabitIconBadge(
                icon: habitIconFor(habit.icon),
                color: accent,
                size: 36,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habit.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${completedDateKeys.length} дн.',
                  style: TextStyle(
                    color: accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (
          var month = DateTime(today.year, today.month);
          !month.isBefore(firstMonth);
          month = DateTime(month.year, month.month - 1)
        )
          _HabitMonthGrid(
            key: ValueKey(month),
            habit: habit,
            month: month,
            today: today,
            accent: accent,
            completedDateKeys: completedDateKeys,
            onToggleDay: onToggleDay,
          ),
      ],
    );
  }
}

class _HabitMonthGrid extends StatelessWidget {
  const _HabitMonthGrid({
    super.key,
    required this.habit,
    required this.month,
    required this.today,
    required this.accent,
    required this.completedDateKeys,
    required this.onToggleDay,
  });

  final Habit habit;
  final DateTime month;
  final DateTime today;
  final Color accent;
  final Set<String> completedDateKeys;
  final ValueChanged<DateTime>? onToggleDay;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingBlanks = month.weekday - DateTime.monday;
    final weeks = ((leadingBlanks + daysInMonth) / DateTime.daysPerWeek).ceil();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              '${_monthNames[month.month - 1]} ${month.year}',
              style: const TextStyle(
                color: habitPanelLabel,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          DecoratedBox(
            decoration: habitPanelCard(radius: 18),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 12, 6, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        for (final name in habitWeekdays)
                          Expanded(
                            child: Text(
                              name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: habitPanelLabel,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (var week = 0; week < weeks; week++)
                      SizedBox(
                        height: 40,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (
                              var weekday = 0;
                              weekday < DateTime.daysPerWeek;
                              weekday++
                            )
                              Expanded(
                                child: _buildCell(
                                  week * DateTime.daysPerWeek +
                                      weekday +
                                      1 -
                                      leadingBlanks,
                                  daysInMonth,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int day, int daysInMonth) {
    if (day < 1 || day > daysInMonth) return const SizedBox.shrink();

    final date = DateTime(month.year, month.month, day);
    final isToday = date == today;
    final dateKey = formatDateKey(date);
    final completed = completedDateKeys.contains(dateKey);
    final ringColor = habit.schedule.isScheduledOn(date)
        ? accent.withValues(alpha: date.isAfter(today) ? .36 : .60)
        : Colors.white24;
    final label = formatDate(date);

    return Semantics(
      label: isToday ? 'Сегодня, $label' : label,
      selected: completed,
      button: onToggleDay != null,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: InkWell(
          key: ValueKey('habit-day-$dateKey'),
          customBorder: const CircleBorder(),
          onTap: onToggleDay == null ? null : () => onToggleDay!(date),
          child: Center(
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? accent : null,
                border: Border.all(
                  color: isToday
                      ? Colors.white
                      : completed
                      ? accent
                      : ringColor,
                  width: isToday ? 1.8 : 1.2,
                ),
                boxShadow: completed
                    ? [
                        BoxShadow(
                          color: accent.withValues(alpha: .45),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
              ),
              child: completed
                  ? const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black26,
                        ),
                        child: SizedBox.square(dimension: 5),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
