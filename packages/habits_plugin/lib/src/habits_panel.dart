import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:habits_api/habits_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'habits_view_model.dart';
import 'habits_state.dart';
import 'habit_visuals.dart';

class HabitsPanel extends StatefulWidget {
  const HabitsPanel({super.key, required this.viewModel});
  final HabitsViewModel viewModel;
  @override
  State<HabitsPanel> createState() => _HabitsPanelState();
}

class _HabitsPanelState extends State<HabitsPanel> {
  final _pending = <String>{};
  Future<void> _change(Habit habit, {bool skip = false}) async {
    if (!_pending.add(habit.id)) return;
    setState(() {});
    final date = widget.viewModel.selectedDate;
    try {
      if (skip) {
        await widget.viewModel.skipHabit(habit, date);
      } else {
        await widget.viewModel.toggleHabit(habit, date);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить отметку. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      _pending.remove(habit.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<HabitsScreenState>(
    stream: widget.viewModel.state,
    initialData: const HabitsLoading(),
    builder: (context, snapshot) {
      final state = snapshot.data;
      final items = state is HabitsLoaded
          ? state.habits
                .where((item) => item.isScheduled && !item.isExpired)
                .toList()
          : <HabitWithEntry>[];
      Widget body;
      if (state is HabitsError) {
        body = const Text('Не удалось загрузить привычки.');
      } else if (state is! HabitsLoaded) {
        body = const Center(child: CircularProgressIndicator());
      } else if (items.isEmpty) {
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('На выбранный день привычек нет'),
        );
      } else {
        body = SizedBox(
          height: math.min(360, items.length * 88).toDouble(),
          child: ListView.builder(
            key: PageStorageKey(this),
            primary: false,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final habit = item.habit;
              final busy = _pending.contains(habit.id);
              final label = item.isSkipped
                  ? 'Пропущено'
                  : item.isCompleted
                  ? 'Выполнено'
                  : switch (habit.type.kind) {
                      HabitTypeKind.morning => 'Утро',
                      HabitTypeKind.lunch => 'День',
                      HabitTypeKind.evening => 'Вечер',
                      HabitTypeKind.time => habit.type.timeLabel ?? '',
                    };
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  key: ValueKey('habit-toggle-${habit.id}'),
                  value: item.isCompleted,
                  onChanged: busy ? null : (_) => _change(habit),
                ),
                title: Text(
                  habit.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      habitIconFor(habit.icon),
                      size: 14,
                      color: habitColorFor(habit.colorHex),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
                trailing: IconButton(
                  key: ValueKey('habit-skip-${habit.id}'),
                  tooltip: item.isSkipped ? 'Отменить пропуск' : 'Пропустить',
                  isSelected: item.isSkipped,
                  onPressed: busy ? null : () => _change(habit, skip: true),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
              );
            },
          ),
        );
      }
      return PluginPanelSurface(
        title: 'Привычки',
        subtitle: state is HabitsLoaded
            ? 'Выполнено ${items.where((item) => item.isCompleted).length} из ${items.length}'
            : null,
        child: body,
      );
    },
  );
}

class HabitsPanelModule implements AppPlugin {
  HabitsPanelModule({
    required this.id,
    required String slot,
    required PluginUiRegistry ui,
    required this._habits,
    required this._date,
    Set<String> dependencies = const {},
  }) {
    _registration = UiPluginRegistration(
      plugin: _HabitsPanelLifecycle(this, Set.unmodifiable(dependencies)),
      registry: ui,
      panels: [
        PluginPanelContribution(
          id: id,
          slot: slot,
          builder: (_, _) => HabitsPanel(viewModel: viewModel),
        ),
      ],
    );
  }
  @override
  final String id;
  final HabitsApi _habits;
  final ValueListenable<DateTime> Function() _date;
  ValueListenable<DateTime>? _dates;
  HabitsViewModel? _model;
  HabitsViewModel get viewModel =>
      _model ?? (throw StateError('Habits panel is not active.'));
  late final UiPluginRegistration _registration;
  void _onDate() => _model?.selectDate(_dates!.value);
  @override
  Set<String> get dependencies => _registration.dependencies;
  @override
  Future<void> start() => _registration.start();
  @override
  Future<void> stop() => _registration.stop();
}

class _HabitsPanelLifecycle implements AppPlugin {
  _HabitsPanelLifecycle(this.module, this.dependencies);
  final HabitsPanelModule module;
  @override
  String get id => module.id;
  @override
  final Set<String> dependencies;
  @override
  Future<void> start() async {
    if (module._model != null) return;
    module._dates = module._date();
    final model = HabitsViewModel(module._habits);
    module._model = model;
    model.selectDate(module._dates!.value);
    model.initialize();
    module._dates!.addListener(module._onDate);
  }

  @override
  Future<void> stop() async {
    module._dates?.removeListener(module._onDate);
    module._dates = null;
    final model = module._model;
    module._model = null;
    await model?.dispose();
  }
}
