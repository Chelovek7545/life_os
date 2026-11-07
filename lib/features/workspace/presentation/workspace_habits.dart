import 'package:flutter/material.dart';
import 'package:habits_plugin/habits_logic.dart';
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';
import 'package:life_os/features/habits/presentation/habits_sheet.dart';
import 'package:life_os/features/habits/presentation/habits_calendar_panel.dart';

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
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * .8,
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Закрыть карту привычек',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
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
