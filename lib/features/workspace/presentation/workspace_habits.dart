import 'package:flutter/material.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';
import 'package:life_os/features/habits/presentation/habits_sheet.dart';
import 'package:life_os/features/habits/presentation/habits_calendar_panel.dart';
import 'package:life_os/features/habits/presentation/widgets/habit_panel_style.dart';

class WorkspaceHabits extends StatelessWidget {
  const WorkspaceHabits({
    super.key,
    required this.model,
    required this.isActive,
  });
  final HabitsViewModel model;
  final bool Function() isActive;

  @override
  Widget build(BuildContext context) => TodaysHabitsPanel(
    viewModel: model,
    backgroundColor: AppColors.surfaceContainerLow,
    onEditHabits: () {
      if (isActive() && model.isActive) {
        showAllHabitsSheet(context: context, viewModel: model);
      }
    },
    onOpenCalendar: () {
      if (!isActive() || !model.isActive) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: false,
        backgroundColor: habitPanelBackground,
        constraints: const BoxConstraints(maxWidth: HabitsMapOverlay.maxWidth),
        sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: HabitsMapOverlay.transitionDuration,
                reverseDuration: HabitsMapOverlay.transitionDuration,
              ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(habitPanelRadius),
          ),
          side: BorderSide(color: habitPanelBorder),
        ),
        builder: (context) => SafeArea(
          top: false,
          child: SizedBox(
            height: HabitsMapOverlay.heightFor(
              MediaQuery.sizeOf(context).height,
            ),
            child: Column(
              children: [
                HabitsMapHeader(onClose: () => Navigator.of(context).pop()),
                Expanded(
                  child: HabitsCalendarPanel(viewModel: model, progress: 1),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
