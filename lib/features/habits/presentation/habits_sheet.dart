import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/glass_panel.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/habits/domain/habit_model.dart';
import 'package:life_os/features/habits/domain/habit_visuals.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_edit_form.dart';

/// Окно со списком всех привычек.
///
/// По тапу на привычку открывается форма редактирования, кнопка «+» —
/// создание новой.
Future<void> showAllHabitsSheet({
  required BuildContext context,
  required HabitsViewModel viewModel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: _AllHabitsSheet(viewModel: viewModel),
    ),
  );
}

/// Форма создания/редактирования привычки в виде нижнего окна.
Future<void> showHabitEditSheet({
  required BuildContext context,
  required HabitsViewModel viewModel,
  Habit? habit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: HabitEditForm(
        initial: habit,
        onDelete: habit == null
            ? null
            : () async {
                await viewModel.deleteEditingHabit();
                if (context.mounted) Navigator.of(context).pop();
              },
        onSave: (updated) {
          viewModel.editingHabit = habit;
          viewModel.saveDraft(updated);
          Navigator.of(context).pop();
        },
      ),
    ),
  );
}

class _AllHabitsSheet extends StatelessWidget {
  const _AllHabitsSheet({required this.viewModel});

  final HabitsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      borderRadius: 0,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Text('HABITS', style: AppTypography.codeLabel),
                const Spacer(),
                IconButton(
                  tooltip: 'New habit',
                  icon: const Icon(Icons.add),
                  onPressed: () =>
                      showHabitEditSheet(context: context, viewModel: viewModel),
                ),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<HabitsScreenState>(
              stream: viewModel.state,
              initialData: const HabitsLoading(),
              builder: (context, snapshot) {
                final state = snapshot.data ?? const HabitsLoading();
                return state.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (message) => Center(child: Text(message)),
                  loaded: (items) {
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Привычек пока нет',
                          style: TextStyle(color: Colors.white38),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _HabitListTile(
                          item: item,
                          onTap: () {
                            viewModel.startEditing(item.habit);
                            showHabitEditSheet(
                            context: context,
                            viewModel: viewModel,
                            habit: item.habit,
                          );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitListTile extends StatelessWidget {
  const _HabitListTile({required this.item, required this.onTap});

  final HabitWithEntry item;
  final VoidCallback onTap;

  String get _scheduleLabel {
    final habit = item.habit;
    final days = habit.schedule.daysOfWeek.toSet();

    String daysLabel;
    if (days.length == 7) {
      daysLabel = 'Every day';
    } else if (days.length == 5 && days.containsAll({1, 2, 3, 4, 5})) {
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

  @override
  Widget build(BuildContext context) {
    final habit = item.habit;
    final accent = habitColorFor(habit.colorHex);

    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(habitIconFor(habit.icon), color: accent, size: 18),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habit.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurface,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _scheduleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
