import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/habits/domain/habit_visuals.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onSkip,
    this.onTap,
    this.onDelete,
  });

  final HabitWithEntry item;
  final VoidCallback onToggle;
  final VoidCallback onSkip;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  String get _scheduleLabel {
    final habit = item.habit;
    final days = habit.schedule.daysOfWeek.toSet();

    String daysLabel;
    if (days.length == 7) {
      daysLabel = 'Every day';
    } else if (days.length == 5 &&
        days.containsAll({1, 2, 3, 4, 5})) {
      daysLabel = 'Weekdays';
    } else if (days.length == 2 && days.containsAll({6, 7})) {
      daysLabel = 'Weekends';
    } else {
      final sorted = days.toList()..sort();
      daysLabel = sorted.map((d) => getWeekDayName(d)).join(' · ');
    }

    final duration = habit.schedule.durationWeeks;
    final durationLabel = duration == null
        ? 'ongoing'
        : duration == 1
        ? '1 week'
        : '$duration weeks';

    return '$daysLabel · $durationLabel';
  }

  String get _typeLabel {
    final type = item.habit.type;
    final time = type.timeLabel;
    return time == null ? type.label : '${type.label} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final habit = item.habit;
    final accent = habitColorFor(habit.colorHex);

    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      borderRadius: AppRadius.xl,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        onTap: onTap,
        onLongPress: onDelete,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Icon(
                habitIconFor(habit.icon),
                color: accent,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    habit.title,
                    style: AppTypography.bodyMd.copyWith(
                      color: item.isCompleted
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                      fontWeight: FontWeight.w600,
                      decoration: item.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _typeLabel,
                    style: AppTypography.codeLabel.copyWith(fontSize: 10),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _scheduleLabel,
                            style: AppTypography.codeLabel.copyWith(
                              fontSize: 10,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (item.streak.hasCurrent) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Icon(
                          Icons.local_fire_department,
                          size: 14,
                          color: item.streak.current >= 7
                              ? const Color(0xFFFFB300)
                              : AppColors.primaryContainer,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${item.streak.current}',
                          style: AppTypography.codeLabel.copyWith(
                            fontSize: 12,
                            color: item.streak.current >= 7
                                ? const Color(0xFFFFB300)
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              tooltip: 'Skip',
              // Всегда активна: повторный тап снимает пропуск.
              onPressed: onSkip,
              icon: Icon(
                Icons.block_rounded,
                size: 18,
                color: item.isSkipped
                    ? AppColors.onSurfaceVariant
                    : AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            IconButton(
              tooltip: 'Toggle',
              onPressed: onToggle,
              icon: Icon(
                item.isCompleted
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: item.isCompleted ? accent : AppColors.onSurfaceVariant,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
