import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_calendar_map.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_panel_style.dart';

class HabitsCalendarPanel extends StatelessWidget {
  const HabitsCalendarPanel({
    super.key,
    required this.viewModel,
    required this.progress,
  });

  final HabitsViewModel viewModel;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < 64) return const SizedBox.shrink();

        return SizedBox(
          height: constraints.hasBoundedHeight ? constraints.maxHeight : 440,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Material(
              type: MaterialType.transparency,
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
                            style: TextStyle(color: habitPanelLabel),
                          ),
                        );
                      }

                      return DefaultTabController(
                        length: items.length,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (constraints.maxHeight >= 112) ...[
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxHeight: 56,
                                ),
                                child: const Text(
                                  'Тап по дню — отметить или снять выполнение',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: habitPanelLabel,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],
                            DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(color: habitPanelBorder),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: TabBar(
                                isScrollable: true,
                                tabAlignment: TabAlignment.start,
                                dividerHeight: 0,
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                labelColor: const Color(0xFFFFBEA1),
                                unselectedLabelColor: habitPanelLabel,
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                unselectedLabelStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                indicator: const BoxDecoration(
                                  color: Color(0x29FFB59C),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(18),
                                  ),
                                ),
                                tabs: [
                                  for (
                                    var index = 0;
                                    index < items.length;
                                    index++
                                  )
                                    _HabitTab(
                                      index: index,
                                      title: items[index].habit.title,
                                    ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  for (final item in items)
                                    _HabitMapPage(
                                      key: ValueKey(item.habit.id),
                                      viewModel: viewModel,
                                      habit: item.habit,
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
          ),
        );
      },
    );
  }
}

class _HabitMapPage extends StatelessWidget {
  const _HabitMapPage({
    super.key,
    required this.viewModel,
    required this.habit,
  });

  final HabitsViewModel viewModel;
  final Habit habit;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    key: PageStorageKey(habit.id),
    padding: const EdgeInsets.only(top: 10, bottom: 16),
    child: HabitCalendarMap(
      habit: habit,
      completedDateKeys: viewModel.completedDateKeysOf(habit.id),
      onToggleDay: (date) => viewModel.toggleHabit(habit, date),
    ),
  );
}

class _HabitTab extends StatelessWidget {
  const _HabitTab({required this.index, required this.title});

  final int index;
  final String title;
  static const _height = 40.0;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    return Tab(
      height: _height,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: SizedBox(
                height: _height,
                child: Align(
                  widthFactor: 1,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            if (controller.index == index)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFFFBEA1),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: SizedBox(height: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class HabitsMapHeader extends StatelessWidget {
  const HabitsMapHeader({super.key, required this.onClose});

  static const height = 52.0;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Закрыть карту привычек',
              onPressed: onClose,
              color: habitPanelLabel,
              icon: const Icon(Icons.close_rounded, size: 22),
            ),
            const SizedBox(width: 4),
            const Expanded(
              child: Text(
                'HABIT MAP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFFFFC5AF),
                  fontSize: 14,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.drag_handle_rounded,
              color: Colors.white38,
              size: 20,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

class HabitsMapOverlay extends StatelessWidget {
  const HabitsMapOverlay({
    super.key,
    required this.viewModel,
    required this.visible,
    required this.onClose,
  });

  static const maxWidth = 520.0;
  static const transitionDuration = Duration(milliseconds: 280);

  static double heightFor(double viewportHeight) =>
      (viewportHeight * .76).clamp(HabitsMapHeader.height, 520.0).toDouble();

  final HabitsViewModel viewModel;
  final bool visible;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : transitionDuration;

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = heightFor(constraints.maxHeight);
        const headerHeight = HabitsMapHeader.height;
        return ClipRect(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              width: maxWidth,
              height: height,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: visible ? 1 : 0),
                duration: duration,
                curve: Curves.easeInOutCubic,
                builder: (context, value, child) {
                  if (value == 0) return const SizedBox.shrink();
                  return IgnorePointer(
                    ignoring: !visible,
                    child: ExcludeFocus(
                      excluding: !visible,
                      child: FractionalTranslation(
                        translation: Offset(0, 1 - value),
                        child: child,
                      ),
                    ),
                  );
                },
                child: CollapsibleSheet(
                  snapPoints: [headerHeight, if (height > 164) 164, height],
                  initialHeight: height,
                  backgroundColor: habitPanelBackground,
                  scrollableBody: false,
                  header: HabitsMapHeader(onClose: onClose),
                  bodyBuilder: (progress, _) => HabitsCalendarPanel(
                    viewModel: viewModel,
                    progress: progress,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
