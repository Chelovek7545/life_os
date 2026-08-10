import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/features/habits/presentation/habits_state.dart';
import 'package:life_os/features/habits/presentation/habits_view_model.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_card.dart';

/// Сегодняшние привычки: панель для экрана Pulse.
///
/// Показывает только запланированные на сегодня и ещё активные привычки
/// с возможностью отметить выполненной или пропустить.
///
/// ViewModel живёт на уровне приложения (см. DependencyContainer), поэтому
/// панель только переинициализирует подписку, но не вызывает dispose.
class TodaysHabitsPanel extends StatefulWidget {
  const TodaysHabitsPanel({
    super.key,
    required this.viewModel,
    this.expand = true,
  });

  final HabitsViewModel viewModel;
  final bool expand;

  @override
  State<TodaysHabitsPanel> createState() => _TodaysHabitsPanelState();
}

class _TodaysHabitsPanelState extends State<TodaysHabitsPanel> {
  @override
  void initState() {
    super.initState();
    widget.viewModel.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final list = StreamBuilder<HabitsScreenState>(
      stream: widget.viewModel.state,
      initialData: const HabitsLoading(),
      builder: (context, snapshot) {
        final state = snapshot.data ?? const HabitsLoading();
        return state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => Center(child: Text(message)),
          loaded: (items) {
            final todayItems = items
                .where((item) => item.isScheduled && !item.isExpired)
                .toList();
            if (todayItems.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'На сегодня привычек нет',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: todayItems.length,
              shrinkWrap: !widget.expand,
              physics: widget.expand
                  ? null
                  : const NeverScrollableScrollPhysics(),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = todayItems[index];
                return HabitCard(
                  item: item,
                  onToggle: () => widget.viewModel.toggleHabit(
                    item.habit,
                    widget.viewModel.selectedDate,
                  ),
                  onSkip: () => widget.viewModel.skipHabit(
                    item.habit,
                    widget.viewModel.selectedDate,
                  ),
                );
              },
            );
          },
        );
      },
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const Spacer(),
            Text("Habits", style: AppTypography.headlineLg),
            const Spacer(),
            const SizedBox(width: AppMargins.md),
          ],
        ),
        if (widget.expand) Flexible(child: list) else list,
      ],
    );
  }
}
