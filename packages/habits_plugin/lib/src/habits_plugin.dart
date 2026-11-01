import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'habits_view_model.dart';

class HabitsUiSlots {
  const HabitsUiSlots({
    required this.today,
    required this.toolbar,
    required this.calendar,
  });
  final String today;
  final String toolbar;
  final String calendar;
}

class HabitsUiBindings {
  const HabitsUiBindings({
    required this.today,
    required this.calendar,
    required this.showAll,
  });
  final Widget Function(
    BuildContext context,
    HabitsViewModel model,
    bool expand,
    VoidCallback openCalendar,
  )
  today;
  final Widget Function(
    BuildContext context,
    HabitsViewModel model,
    VoidCallback closeCalendar,
  )
  calendar;
  final Future<void> Function(BuildContext context, HabitsViewModel model)
  showAll;
}

/// Owns habits state, subscriptions and UI registrations. Storage and views
/// are supplied by the application; no database or Pulse implementation leaks
/// into the module.
class HabitsPlugin {
  HabitsPlugin({
    required this._habits,
    required PluginUiRegistry ui,
    required HabitsUiSlots slots,
    required HabitsUiBindings visuals,
    Set<String> dependencies = const {},
  }) {
    plugins = List.unmodifiable([
      UiPluginRegistration(
        plugin: _HabitsLifecycle(this, Set.unmodifiable(dependencies)),
        registry: ui,
        panels: [
          PluginPanelContribution(
            id: 'habits.today',
            slot: slots.today,
            builder: (context, panel) =>
                visuals.today(context, viewModel, panel.expand, () {
                  if (panel.isActive) _calendar?.value = true;
                }),
          ),
          PluginPanelContribution(
            id: 'habits.toolbar',
            slot: slots.toolbar,
            builder: (context, panel) {
              final model = viewModel;
              return IconButton(
                tooltip: 'Habits',
                icon: const Icon(Icons.repeat_rounded),
                onPressed: () {
                  if (panel.isActive) visuals.showAll(context, model);
                },
              );
            },
          ),
          PluginPanelContribution(
            id: 'habits.calendar',
            slot: slots.calendar,
            builder: (context, panel) {
              final model = viewModel;
              return ValueListenableBuilder<bool>(
                valueListenable: _calendar!,
                builder: (context, visible, _) => visible
                    ? visuals.calendar(context, model, () {
                        if (panel.isActive) _calendar?.value = false;
                      })
                    : const SizedBox.shrink(),
              );
            },
          ),
        ],
      ),
    ]);
  }

  final HabitsApi _habits;
  late final List<AppPlugin> plugins;
  HabitsViewModel? _viewModel;
  ValueNotifier<bool>? _calendar;
  HabitsViewModel get viewModel =>
      _viewModel ?? (throw StateError('Habits module is not active.'));
}

class _HabitsLifecycle implements AppPlugin {
  _HabitsLifecycle(this.module, this.dependencies);
  final HabitsPlugin module;
  @override
  String get id => 'habits.ui';
  @override
  final Set<String> dependencies;
  @override
  Future<void> start() async {
    if (module._viewModel != null) return;
    module._calendar = ValueNotifier(false);
    final model = HabitsViewModel(module._habits);
    module._viewModel = model;
    model.initialize();
  }

  @override
  Future<void> stop() async {
    final model = module._viewModel;
    final calendar = module._calendar;
    module._viewModel = null;
    module._calendar = null;
    try {
      await model?.dispose();
    } finally {
      calendar?.dispose();
    }
  }
}
