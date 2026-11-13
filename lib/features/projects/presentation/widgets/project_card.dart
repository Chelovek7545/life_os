import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:projects_api/projects_api.dart';
import 'package:projects_plugin/projects_logic.dart';
import 'package:tasks_api/tasks_api.dart' show Task, TaskStatus;

class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.title,
    required this.description,
    required this.color,
    required this.project,
    required this.viewModel,
    required this.onEditRequested,
    this.dueDate,
    this.tasks,
  });

  final String title;
  final String description;
  final Color color;
  final Project project;
  final ProjectsViewModel viewModel;
  final VoidCallback onEditRequested;
  final DateTime? dueDate;
  final List<Task>? tasks;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _hovered = false;
  bool _expanded = false;
  Stream<List<Task>>? _tasks;

  @override
  void initState() {
    super.initState();
    _connectTasks();
  }

  void _connectTasks() {
    _tasks = widget.tasks == null
        ? widget.viewModel.watchTaskByProject(widget.project.id)
        : null;
  }

  @override
  void didUpdateWidget(covariant ProjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project.id != widget.project.id ||
        oldWidget.viewModel != widget.viewModel ||
        (oldWidget.tasks == null) != (widget.tasks == null)) {
      _connectTasks();
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить изменения. Повторите попытку.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks != null) return _buildCard(widget.tasks!);
    return StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Не удалось загрузить задачи проекта.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildCard(snapshot.data!);
      },
    );
  }

  Widget _buildCard(List<Task> tasks) {
    final theme = Theme.of(context);
    final done = tasks.where((task) => task.isCompleted).length;
    final progress = tasks.isEmpty ? 0.0 : done / tasks.length;
    final archived = widget.project.isArchived;
    final completed = tasks.isNotEmpty && done == tasks.length;
    final status = archived
        ? 'В архиве'
        : completed
        ? 'Завершён'
        : 'Активный';
    final statusColor = archived
        ? const Color(0xFFB6AFAC)
        : completed
        ? const Color(0xFF9FC4F4)
        : const Color(0xFF8DD1B4);
    final highlighted = _hovered || _expanded;
    final tags = tasks
        .expand((task) => task.tags)
        .map((tag) => tag.name)
        .toSet()
        .take(3);
    const secondary = Color(0xFFBDB9B7);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Container(
        constraints: const BoxConstraints(minHeight: 278),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: highlighted
                ? const [Color(0xFF372820), Color(0xFF201C1A)]
                : const [Color(0xFF29292B), Color(0xFF1C1C1E)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: highlighted
                ? AppColors.primaryContainer
                : const Color(0xFF414043),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: highlighted
                  ? AppColors.primaryContainer.withValues(alpha: 0.10)
                  : Colors.black.withValues(alpha: 0.12),
              blurRadius: highlighted ? 20 : 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Icon(
                      Icons.folder_outlined,
                      color: Color.lerp(widget.color, Colors.white, 0.35),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF3F0EE),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: PopupMenuButton<String>(
                      tooltip: 'Действия с проектом',
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: secondary,
                        size: 23,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          widget.onEditRequested();
                        } else if (value == 'archive') {
                          _perform(
                            () => widget.viewModel.updateProject(
                              widget.project.copyWith(isArchived: !archived),
                            ),
                          );
                        } else if (value == 'delete') {
                          _perform(
                            () => widget.viewModel.deleteProject(
                              widget.project.id,
                            ),
                          );
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Редактировать'),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(
                            archived ? 'Вернуть из архива' : 'В архив',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Удалить'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.description.isEmpty
                    ? 'Добавьте описание проекта'
                    : widget.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: secondary,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Text(
                    '${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFF3F0EE),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: InkWell(
                        onTap: tasks.isEmpty
                            ? null
                            : () => setState(() => _expanded = !_expanded),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  tasks.isEmpty
                                      ? 'Нет задач'
                                      : '$done / ${tasks.length} задач',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: secondary,
                                  ),
                                ),
                              ),
                              if (tasks.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  _expanded
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  size: 18,
                                  color: secondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  color: const Color(0xFFFF7A3D),
                  backgroundColor: Colors.white.withValues(alpha: 0.09),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.dueDate == null
                          ? 'Без срока'
                          : 'До ${formatDate(widget.dueDate!)}',
                      style: const TextStyle(fontSize: 12, color: secondary),
                    ),
                  ),
                ],
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: tags
                      .map(
                        (tag) => Container(
                          constraints: const BoxConstraints(maxWidth: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                          child: Text(
                            tag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: secondary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (_expanded) ...[
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF414043)),
                for (final task in tasks)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: AppColors.primaryContainer,
                    value: task.isCompleted,
                    onChanged: (_) => _perform(
                      () => widget.viewModel.updateTask(
                        task.copyWith(
                          status: task.isCompleted
                              ? TaskStatus.open
                              : TaskStatus.done,
                        ),
                      ),
                    ),
                    title: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 13,
                        color: secondary,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
