import 'package:habits_api/habits_api.dart';
import 'package:habits_plugin/habits_plugin.dart';
import 'package:plugin_ui/plugin_ui.dart';
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
    showToolbar: false,
    today: (context, model, expand, openCalendar) => TodaysHabitsPanel(
      viewModel: model,
      expand: expand,
      onOpenCalendar: openCalendar,
      onEditHabits: () {
        if (model.isActive) {
          showAllHabitsSheet(context: context, viewModel: model);
        }
      },
    ),
    showAll: (context, model) =>
        showAllHabitsSheet(context: context, viewModel: model),
    calendar: (_, model, visible, close) =>
        HabitsMapOverlay(viewModel: model, visible: visible, onClose: close),
  ),
);
