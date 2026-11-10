import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';
import 'package:life_os/core/ui/task_work_logs.dart';
import 'package:life_os/core/utils/color_format.dart';
import '../task_status_visuals.dart';

class TaskKanbanBoard extends StatelessWidget {
  const TaskKanbanBoard({
    super.key,
    required this.items,
    required this.topPadding,
    required this.onOpen,
    required this.onToggle,
    required this.onMove,
    this.workLogs,
  });
  final List<TaskWithProject> items;
  final double topPadding;
  final ValueChanged<TaskWithProject> onOpen;
  final ValueChanged<Task> onToggle;
  final void Function(Task task, TaskStatus status) onMove;
  final WorkLogsApi? workLogs;

  static const columns = {
    TaskStatus.open: 'Входящие',
    TaskStatus.notStarted: 'К выполнению',
    TaskStatus.inProgress: 'В работе',
    TaskStatus.done: 'Готово',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topPadding + AppSpacing.md, bottom: 8),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = math.max(260.0, (constraints.maxWidth - 36) / 4);
        return SingleChildScrollView(
          key: const ValueKey('tasks.kanban'),
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in columns.entries) ...[
                if (entry.key != columns.keys.first) const SizedBox(width: 12),
                SizedBox(
                  width: width,
                  child: DragTarget<Task>(
                    key: ValueKey(('kanban.column', entry.key)),
                    onWillAcceptWithDetails: (details) =>
                        details.data.status != entry.key,
                    onAcceptWithDetails: (details) =>
                        onMove(details.data, entry.key),
                    builder: (context, candidates, _) {
                      final tasks = items
                          .where((item) => item.task.status == entry.key)
                          .toList();
                      final columnColor = candidates.isEmpty
                          ? AppColors.surfaceContainerLow
                          : Color.alphaBlend(
                              entry.key.color.withValues(alpha: .12),
                              AppColors.surfaceContainerLow,
                            );
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: columnColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: candidates.isEmpty
                                ? AppColors.borderGlass
                                : entry.key.color,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Column(
                            children: [
                              Padding(
                                key: ValueKey(('kanban.header', entry.key)),
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Icon(
                                      entry.key.icon,
                                      color: entry.key.color,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(entry.value)),
                                    Text('${tasks.length}'),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ClipRect(
                                  child: ScrollConfiguration(
                                    behavior: AppScrollBehavior(
                                      fadeColor: columnColor,
                                    ),
                                    child: ListView.builder(
                                      key: ValueKey(('kanban.list', entry.key)),
                                      padding: const EdgeInsets.all(8),
                                      itemCount: tasks.length,
                                      itemBuilder: (context, index) {
                                        final item = tasks[index];
                                        Widget card([Widget? footer]) =>
                                            TaskCard(
                                              footer: footer,
                                              isSelected: false,
                                              task: item.task,
                                              projectTitle: item.project?.name,
                                              leftBorderColor:
                                                  item.project == null
                                                  ? entry.key.color
                                                  : parseHexColor(
                                                      item.project!.color,
                                                    ),
                                              onTap: () => onOpen(item),
                                              onCheckChanged: () =>
                                                  onToggle(item.task),
                                            );
                                        Widget highlightedCard([
                                          Widget? footer,
                                        ]) => DecoratedBox(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.lg,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: AppColors.primary
                                                    .withValues(alpha: .18),
                                                blurRadius: 14,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                          ),
                                          child: DecoratedBox(
                                            position:
                                                DecorationPosition.foreground,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppRadius.lg,
                                                  ),
                                              border: Border.all(
                                                color: AppColors.primary
                                                    .withValues(alpha: .85),
                                                width: 1.2,
                                              ),
                                            ),
                                            child: card(footer),
                                          ),
                                        );
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: TaskWorkLogsBuilder(
                                            taskId: item.task.id,
                                            repository: workLogs,
                                            builder: (footer) =>
                                                LongPressDraggable<Task>(
                                                  key: ValueKey((
                                                    'kanban.task',
                                                    item.task.id,
                                                  )),
                                                  data: item.task,
                                                  feedback: Material(
                                                    key: ValueKey((
                                                      'kanban.feedback',
                                                      item.task.id,
                                                    )),
                                                    color: Colors.transparent,
                                                    child: SizedBox(
                                                      width: width - 16,
                                                      child: highlightedCard(
                                                        footer,
                                                      ),
                                                    ),
                                                  ),
                                                  childWhenDragging: Opacity(
                                                    opacity: .45,
                                                    child: highlightedCard(
                                                      footer,
                                                    ),
                                                  ),
                                                  child: card(footer),
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
