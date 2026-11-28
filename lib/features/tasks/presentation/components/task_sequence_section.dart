import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:tasks_api/tasks_api.dart';
import '../widgets/existing_task_picker_dialog.dart';

typedef OnTaskSequenceChange =
    Future<void> Function(
      String id,
      TaskSequenceDirection direction, {
      required String? oldTaskId,
      required String? newTaskId,
    });

class TaskSequenceSection extends StatefulWidget {
  const TaskSequenceSection({
    super.key,
    required this.taskId,
    required this.watchTasks,
    this.onSequenceChange,
  });

  final String taskId;
  final Stream<List<Task>> Function() watchTasks;
  final OnTaskSequenceChange? onSequenceChange;

  @override
  State<TaskSequenceSection> createState() => _TaskSequenceSectionState();
}

class _TaskSequenceSectionState extends State<TaskSequenceSection> {
  late Stream<List<Task>> _tasks = widget.watchTasks();
  bool _removingSequenceLink = false;

  @override
  void didUpdateWidget(covariant TaskSequenceSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.watchTasks != widget.watchTasks) {
      _tasks = widget.watchTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, snapshot) {
        final tasks = {
          for (final task in snapshot.data ?? const <Task>[]) task.id: task,
        };
        final task = tasks[widget.taskId];
        if (task == null) return const SizedBox.shrink();
        final successors = tasks.values
            .where(
              (candidate) => candidate.predecessorTaskIds.contains(task.id),
            )
            .toList();
        final predecessors = task.predecessorTaskIds;
        final canChange =
            widget.onSequenceChange != null && !_removingSequenceLink;

        Widget step(TaskSequenceDirection direction, String? linkedId) {
          final previous = direction == TaskSequenceDirection.previous;
          return _sequenceStep(
            icon: previous ? Icons.arrow_upward : Icons.arrow_downward,
            child: _sequenceField(
              previous ? 'Предыдущая задача' : 'Следующая задача',
              tasks[linkedId]?.title,
              onPick: canChange
                  ? () => _pickSequenceTask(tasks, task, direction, linkedId)
                  : null,
              onRemove: canChange && linkedId != null
                  ? () => _removeSequenceLink(task.id, direction, linkedId)
                  : null,
            ),
          );
        }

        return _sequenceCard(
          key: const ValueKey('task-editor.sequence'),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.link_rounded, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Связанные задачи', style: _sectionTitle),
                        Text(
                          'Последовательность выполнения',
                          style: _secondaryText,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Stack(
                children: [
                  PositionedDirectional(
                    start: 11,
                    top: 24,
                    bottom: 24,
                    child: Container(
                      width: 1,
                      color: AppColors.primary.withValues(alpha: .44),
                    ),
                  ),
                  Column(
                    children: [
                      if (predecessors.isEmpty)
                        step(TaskSequenceDirection.previous, null)
                      else ...[
                        for (final (index, predecessor) in predecessors.indexed)
                          Padding(
                            padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
                            child: step(
                              TaskSequenceDirection.previous,
                              predecessor,
                            ),
                          ),
                        if (widget.onSequenceChange != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 32,
                            ),
                            child: Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: _removingSequenceLink
                                    ? null
                                    : () => _pickSequenceTask(
                                        tasks,
                                        task,
                                        TaskSequenceDirection.previous,
                                        null,
                                      ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Добавить предыдущую задачу'),
                              ),
                            ),
                          ),
                      ],
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _sequenceStep(
                          icon: Icons.circle,
                          current: true,
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: .11),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                child: Text(
                                  'Текущая задача',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (successors.isEmpty)
                        step(TaskSequenceDirection.next, null)
                      else
                        for (final (index, successor) in successors.indexed)
                          Padding(
                            padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
                            child: step(
                              TaskSequenceDirection.next,
                              successor.id,
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sequenceStep({
    required IconData icon,
    required Widget child,
    bool current = false,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: current
              ? AppColors.primary
              : const Color(0xFF503B33),
          child: Icon(
            icon,
            size: current ? 8 : 15,
            color: current ? AppColors.surface : AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }

  Widget _sequenceField(
    String label,
    String? title, {
    required VoidCallback? onPick,
    required VoidCallback? onRemove,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: AppColors.borderGlass),
    );
    return Material(
      color: AppColors.surfaceBright,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onPick,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            title ?? 'Без связи',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _secondaryText,
                          ),
                        ],
                      ),
                    ),
                    if (widget.onSequenceChange != null)
                      Icon(
                        title == null
                            ? Icons.add_rounded
                            : Icons.swap_horiz_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Убрать связь',
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  Future<void> _removeSequenceLink(
    String id,
    TaskSequenceDirection direction,
    String linkedId,
  ) async {
    if (_removingSequenceLink) return;
    setState(() => _removingSequenceLink = true);
    try {
      await widget.onSequenceChange!(
        id,
        direction,
        oldTaskId: linkedId,
        newTaskId: null,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось убрать связь.')),
        );
      }
    } finally {
      if (mounted) setState(() => _removingSequenceLink = false);
    }
  }

  void _pickSequenceTask(
    Map<String, Task> tasks,
    Task task,
    TaskSequenceDirection direction,
    String? oldTaskId,
  ) {
    final change = widget.onSequenceChange!;
    final previous = direction == TaskSequenceDirection.previous;
    final candidates =
        tasks.values.where((candidate) {
          if (candidate.id == task.id || candidate.id == oldTaskId) {
            return false;
          }
          final source = previous ? candidate : task;
          final target = previous ? task : candidate;
          return !target.predecessorTaskIds.contains(source.id) &&
              !wouldCreateSequenceCycle(
                source.id,
                target.id,
                (id) => tasks[id]?.predecessorTaskIds ?? const [],
              );
        }).toList()..sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );

    Future<void> apply(String? newTaskId) async {
      if (!mounted ||
          widget.taskId != task.id ||
          widget.onSequenceChange != change) {
        throw StateError('Редактор задачи закрыт.');
      }
      await change(
        task.id,
        direction,
        oldTaskId: oldTaskId,
        newTaskId: newTaskId,
      );
    }

    showDialog<void>(
      context: context,
      builder: (context) => ExistingTaskPickerDialog(
        title: previous ? 'Предыдущая задача' : 'Следующая задача',
        tasks: candidates,
        emptyText: 'Нет доступных задач',
        errorText: 'Не удалось изменить связь. Откройте список задач заново.',
        onSelect: apply,
        onRemove: oldTaskId == null ? null : () => apply(null),
      ),
    );
  }

  TextStyle? get _sectionTitle => Theme.of(context).textTheme.titleMedium
      ?.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w700);

  TextStyle? get _secondaryText => Theme.of(context).textTheme.bodySmall
      ?.copyWith(color: AppColors.onSurface.withValues(alpha: .72));

  Widget _sequenceCard({required Key key, required Widget child}) => Container(
    key: key,
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.surfaceBright, AppColors.surfaceContainerLow],
      ),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      border: Border.all(color: AppColors.borderGlass),
    ),
    child: child,
  );
}
