import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'today_screen.dart';

abstract final class TodayPanelSlots {
  static const tasks = 'today.tasks';
  static const habits = 'today.habits';
  static const projects = 'today.projects';
}

typedef TodayPanelsFactory =
    Iterable<AppPlugin> Function(ValueListenable<DateTime> Function() date);

/// Composes registered panels without knowing their business APIs or models.
class TodayPlugin {
  TodayPlugin({
    required PluginUiRegistry ui,
    required TodayPanelsFactory panels,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    final parts = panels(() => dates).toList(growable: false);
    plugins = List.unmodifiable([
      _TodayDateLifecycle(this),
      for (final part in parts) _RequiresDate(part),
      UiPluginRegistration(
        plugin: UiModule(
          id: 'today.screen',
          dependencies: {'today.core', ...parts.map((part) => part.id)},
        ),
        registry: ui,
        screens: [
          PluginScreenContribution(
            id: 'today',
            label: 'СЕГОДНЯ',
            icon: Icons.today_outlined,
            order: 5,
            builder: (_, screen) => TodayScreen(
              registry: ui,
              date: dates,
              now: _now,
              onSelectDate: (date) {
                if (screen.isActive) selectDate(date);
              },
            ),
          ),
        ],
      ),
    ]);
  }
  final DateTime Function() _now;
  ValueNotifier<DateTime>? _dates;
  ValueListenable<DateTime> get dates =>
      _dates ?? (throw StateError('Today module is not active.'));
  DateTime get selectedDate => dates.value;
  void selectDate(DateTime date) {
    final current = _dates;
    if (current == null) throw StateError('Today module is not active.');
    current.value = DateTime(date.year, date.month, date.day);
  }

  late final List<AppPlugin> plugins;
}

class _TodayDateLifecycle implements AppPlugin {
  _TodayDateLifecycle(this.module);
  final TodayPlugin module;
  @override
  String get id => 'today.core';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    final now = module._now();
    module._dates ??= ValueNotifier(DateTime(now.year, now.month, now.day));
  }

  @override
  Future<void> stop() async {
    module._dates?.dispose();
    module._dates = null;
  }
}

class _RequiresDate implements AppPlugin {
  _RequiresDate(this.panel);
  final AppPlugin panel;
  @override
  String get id => panel.id;
  @override
  Set<String> get dependencies => {'today.core', ...panel.dependencies};
  @override
  Future<void> start() => panel.start();
  @override
  Future<void> stop() => panel.stop();
}
