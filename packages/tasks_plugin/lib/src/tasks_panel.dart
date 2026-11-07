import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'get_tasks_with_projects_use_case.dart';
import 'task_filter_config.dart';
import 'task_state.dart';
import 'tasks_view_model.dart';

class TasksPanel extends StatefulWidget {
  const TasksPanel({
    super.key,
    required this.viewModel,
    this.onOpenTask,
    this.taskBuilder,
  });
  final TasksViewModel viewModel;
  final void Function(Task)? onOpenTask;
  final Widget Function(
    BuildContext context,
    TaskWithProject item,
    VoidCallback? onToggle,
    VoidCallback? onOpen,
  )?
  taskBuilder;
  @override
  State<TasksPanel> createState() => _TasksPanelState();
}

class _TasksPanelState extends State<TasksPanel> {
  final _pending = <String>{};
  Future<void> _toggle(Task task) async {
    if (!_pending.add(task.id)) return;
    setState(() {});
    try {
      await widget.viewModel.toggleTask(task);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось обновить задачу. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      _pending.remove(task.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<TaskFilterConfig>(
    stream: widget.viewModel.currentFilter,
    initialData: widget.viewModel.currentFilterValue,
    builder: (context, filterSnapshot) {
      final filter = filterSnapshot.data!;
      return PluginPanelSurface(
        title: 'Задачи',
        controls: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final option in [
              (false, 'Невыполненные'),
              (null, 'Все'),
              (true, 'Выполненные'),
            ])
              ChoiceChip(
                label: Text(option.$2),
                selected: filter.showCompleted == option.$1,
                onSelected: (_) => widget.viewModel.updateFilter(
                  (old) => old.copyWith(showCompleted: () => option.$1),
                ),
              ),
          ],
        ),
        child: StreamBuilder<TaskScreenState>(
          stream: widget.viewModel.state,
          initialData: const TasksLoading(),
          builder: (context, snapshot) {
            final state = snapshot.data;
            if (state is TasksError) {
              return const Text('Не удалось загрузить задачи.');
            }
            if (state is TasksEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('На выбранный день задач нет'),
              );
            }
            if (state is! TasksLoaded) {
              return const Center(child: CircularProgressIndicator());
            }
            final items = [...state.tasks, ...state.unscheduledTasks];
            if (items.isEmpty) return const Text('На выбранный день задач нет');
            return SizedBox(
              height: math.min(360, items.length * 88).toDouble(),
              child: ListView.builder(
                key: PageStorageKey(this),
                primary: false,
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final task = item.task;
                  final builder = widget.taskBuilder;
                  if (builder != null) {
                    return builder(
                      context,
                      item,
                      _pending.contains(task.id) ? null : () => _toggle(task),
                      widget.onOpenTask == null
                          ? null
                          : () => widget.onOpenTask!(task),
                    );
                  }
                  final when = task.startsAt;
                  final time = when == null
                      ? 'Без расписания'
                      : '${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}';
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Checkbox(
                      key: ValueKey('task-toggle-${task.id}'),
                      value: task.isCompleted,
                      onChanged: _pending.contains(task.id)
                          ? null
                          : (_) => _toggle(task),
                    ),
                    title: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      item.project == null
                          ? time
                          : '$time · ${item.project!.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: widget.onOpenTask == null
                        ? null
                        : () => widget.onOpenTask!(task),
                  );
                },
              ),
            );
          },
        ),
      );
    },
  );
}

/// A reusable panel instance with its own filter, model and subscriptions.
class TasksPanelModule implements AppPlugin {
  TasksPanelModule({
    required this.id,
    required String slot,
    required PluginUiRegistry ui,
    required this._tasks,
    required this._projects,
    required this._date,
    Set<String> dependencies = const {},
  }) {
    _registration = UiPluginRegistration(
      plugin: _TasksPanelLifecycle(this, Set.unmodifiable(dependencies)),
      registry: ui,
      panels: [
        PluginPanelContribution(
          id: id,
          slot: slot,
          builder: (_, panel) => TasksPanel(
            viewModel: viewModel,
            onOpenTask: (task) {
              if (panel.isActive) {
                panel.screen?.openScreen('tasks', argument: task);
              }
            },
          ),
        ),
      ],
    );
  }
  @override
  final String id;
  final TasksApi _tasks;
  final ProjectsQueries _projects;
  final ValueListenable<DateTime> Function() _date;
  ValueListenable<DateTime>? _dates;
  TasksViewModel? _model;
  late final UiPluginRegistration _registration;
  TasksViewModel get viewModel =>
      _model ?? (throw StateError('Task panel is not active.'));
  void _onDate() => _model?.updateFilter(
    (old) => old.copyWith(anchorDate: _dates!.value, period: DatePeriod.day),
  );
  @override
  Set<String> get dependencies => _registration.dependencies;
  @override
  Future<void> start() => _registration.start();
  @override
  Future<void> stop() => _registration.stop();
}

class _TasksPanelLifecycle implements AppPlugin {
  _TasksPanelLifecycle(this.module, this.dependencies);
  final TasksPanelModule module;
  @override
  String get id => module.id;
  @override
  final Set<String> dependencies;
  @override
  Future<void> start() async {
    if (module._model != null) return;
    module._dates = module._date();
    final model = TasksViewModel(
      module._tasks,
      GetTasksWithProjectsUseCase(module._tasks, module._projects),
      module._projects,
    );
    module._model = model;
    model.updateFilter(
      (old) => old.copyWith(
        anchorDate: module._dates!.value,
        showCompleted: () => false,
      ),
    );
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
