import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';

class ProjectCard extends StatefulWidget {
  final String title;
  final String description;
  final Color color;
  final Project project;
  final ProjectsViewModel viewModel;
  final VoidCallback onEditRequested;

  final DateTime? dueDate;

  const ProjectCard({
    super.key,
    required this.title,
    required this.description,
    required this.color,
    required this.project,
    required this.viewModel,
    required this.onEditRequested,
    this.dueDate,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Stream tasks once and compute progress dynamically
    return StreamBuilder<List<Task>>(
      stream: widget.viewModel.watchTaskByProject(widget.project.id),
      builder: (context, snap) {
        final tasks = snap.data ?? [];
        final int total = tasks.isEmpty ? 0 : tasks.length;
        final int doneCount = tasks.where((t) => t.isCompleted).length;
        final double progress = total == 0 ? 0.0 : (doneCount / total);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              width: 1.5,
              color: widget.color.withValues(alpha: 0.2),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest
                                  .withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "Due date${widget.dueDate != null ? ': ${formatDate(widget.dueDate!)}' : ''}",
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.primaryContainer,
                              ),
                            ),
                          ),
                          SizedBox(height: AppMargins.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // color indicator circle
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: widget.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.onSurface,
                                        ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(progress * 100).round()}%',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 8),
                        Material(
                          type: MaterialType.transparency,
                          child: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'edit') {
                                widget.onEditRequested();
                              } else if (v == 'delete') {
                                await widget.viewModel.deleteProject(
                                  widget.project.id,
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            child: const Icon(
                              Icons.more_vert,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),

                          const SizedBox(height: 6),
                          Text(
                            widget.description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              color: AppColors.primaryContainer,
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'TASKS:',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (tasks.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                'No tasks yet',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          else
                            Column(
                              children: tasks.take(4).map((task) {
                                final done = task.isCompleted;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InkWell(
                                    onTap: () async {
                                      final updated = task.copyWith(
                                        status: done
                                            ? TaskStatus.open
                                            : TaskStatus.done,
                                      );
                                      await widget.viewModel.updateTask(
                                        updated,
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.surface
                                            .withValues(alpha: 0.02),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: done
                                                  ? AppColors.primaryContainer
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: theme
                                                    .colorScheme
                                                    .onSurfaceVariant
                                                    .withValues(alpha: 0.2),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: done
                                                ? const Icon(
                                                    Icons.check,
                                                    size: 16,
                                                    color: Colors.white,
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              task.title,
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: done
                                                        ? theme
                                                              .colorScheme
                                                              .onSurface
                                                              .withValues(
                                                                alpha: 0.7,
                                                              )
                                                        : theme
                                                              .colorScheme
                                                              .onSurface,
                                                    decoration: done
                                                        ? TextDecoration
                                                              .lineThrough
                                                        : TextDecoration.none,
                                                  ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            done ? 'DONE' : 'PENDING',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
