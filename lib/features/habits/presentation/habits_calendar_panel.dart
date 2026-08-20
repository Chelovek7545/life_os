import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_calendar_map.dart';

/// Содержимое шторки с картой выполненных дней по каждой привычке.
///
/// Сверху — табы по привычкам, ниже — карта выбранной привычки
/// (кружки за каждый день месяца, закрашенные, если привычка выполнена).
/// Используется внутри [CollapsibleSheet] на экране Pulse.
class HabitsCalendarPanel extends StatelessWidget {
  const HabitsCalendarPanel({super.key, required this.viewModel, required this.progress});

  final HabitsViewModel viewModel;
  final double progress;


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // При сжатии шторки тело может стать короче фиксированных элементов
        // (подсказка + табы). Тогда контент не помещается и выдаёт overflow —
        // прячем его целиком, шапка остаётся перетаскиваемой.



        return Material(
          type: MaterialType.transparency,
          child: SizedBox(
            height: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Тап по дню — отметить или снять выполнение',
                  style: TextStyle(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
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
                          return DefaultTabController(
                            length: items.length,
                            child: Column(
                              children: [
                                TabBar(
                                  isScrollable: true,
                                  tabAlignment: TabAlignment.start,
                                  dividerColor: AppColors.borderGlass,
                                  labelColor: AppColors.primary,
                                  unselectedLabelColor:
                                      AppColors.onSurfaceVariant,
                                  labelStyle: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  tabs: [
                                    for (final item in items)
                                      Tab(
                                        child: Text(
                                          item.habit.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                                Expanded(
                                  child: TabBarView(
                                    children: [
                                      for (final item in items)
                                        _HabitMapPage(
                                          viewModel: viewModel,
                                          habitId: item.habit.id,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HabitMapPage extends StatelessWidget {
  const _HabitMapPage({required this.viewModel, required this.habitId});

  final HabitsViewModel viewModel;
  final String habitId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HabitsScreenState>(
      stream: viewModel.state,
      initialData: const HabitsLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const HabitsLoading();
        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => Center(child: Text(message)),
          loaded: (items) {
            final item = items.where((i) => i.habit.id == habitId).firstOrNull;
            if (item == null) {
              return const SizedBox.shrink();
            }
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              child: HabitCalendarMap(
                habit: item.habit,
                completedDateKeys: viewModel.completedDateKeysOf(habitId),
                onToggleDay: (date) => viewModel.toggleHabit(item.habit, date),
              ),
            );
          },
        );
      },
    );
  }
}

/// Шапка коллапсируемой шторки карты привычек.
class HabitsMapHeader extends StatelessWidget {
  const HabitsMapHeader({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60, // Должно совпадать с CollapsibleSheet.minHeight
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: Colors.transparent, // Вся область шапки перетаскивается
      child: Row(
        children: [
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
          const SizedBox(width: 8),
          Text('HABIT MAP', style: AppTypography.codeLabel),
          const Spacer(),
          const Icon(Icons.drag_handle, size: 18, color: Colors.white24),
        ],
      ),
    );
  }
}
