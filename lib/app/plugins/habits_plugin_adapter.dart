import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_plugin.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:life_os/core/ui/collapsible_sheet.dart';
import 'package:life_os/features/habits/presentation/habits_calendar_panel.dart';
import 'package:life_os/features/habits/presentation/habits_sheet.dart';
import 'package:life_os/features/habits/presentation/todays_habits_panel.dart';
import 'package:lifegraph_plugin/lifegraph_plugin.dart' show PulsePanelSlots;

HabitsPlugin createHabitsPlugin({
  required HabitsApi habits,
  required PluginUiRegistry ui,
}) => HabitsPlugin(
  habits: habits,
  ui: ui,
  dependencies: {'lifegraph.screen'},
  slots: const HabitsUiSlots(
    today: PulsePanelSlots.center,
    toolbar: PulsePanelSlots.toolbar,
    calendar: PulsePanelSlots.overlay,
  ),
  visuals: HabitsUiBindings(
    today: (_, model, expand, openCalendar) => TodaysHabitsPanel(
      viewModel: model,
      expand: expand,
      onOpenCalendar: openCalendar,
    ),
    showAll: (context, model) =>
        showAllHabitsSheet(context: context, viewModel: model),
    calendar: (context, model, close) {
      final height = MediaQuery.sizeOf(context).height * .85;
      return CollapsibleSheet(
        snapPoints: [60, 190, height],
        initialHeight: height,
        header: HabitsMapHeader(onClose: close),
        bodyBuilder: (progress, _) =>
            HabitsCalendarPanel(viewModel: model, progress: progress),
      );
    },
  ),
);
