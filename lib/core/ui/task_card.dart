import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/semantic_tag.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'glass_panel.dart';

final testTask = Task.blank().copyWith(
  title: 'jisd jkjfkljdfk;ljkdlf j;akljdkaljkl fj;aklsjfklajafljs',
  dueDate: Wrapped(DateTime.now()),
  tags: ['work', 'gym'].map((e) => Tag(id: 1, name: e, colorHex: 183024)).toList()
);

@Preview()
Widget Preview0() => MaterialApp(
  theme: ThemeData.light(),
  home: TaskCard(
    projectTitle: '5m reel',
    task: testTask,
    isSelected: false,
    leftBorderColor: Colors.green,
  ),
);

@Preview()
Widget newPreview() => MaterialApp(
  theme: ThemeData.light(),
  home: TaskCard(
    projectTitle: '5m reel',
    task: testTask,
    isSelected: true,
    leftBorderColor: Colors.green,
  ),
);

@Preview()
Widget Preview1() => MaterialApp(
  theme: ThemeData.light(),
  home: TaskCard(
    projectTitle: '5m reel',
    task: testTask.copyWith(status: TaskStatus.done),
    isSelected: false,
    leftBorderColor: Colors.green,
    isOverdue: true,
  ),
);

@Preview()
Widget Preview2() => MaterialApp(
  theme: ThemeData.light(),
  home: TaskCard(
    projectTitle: '5m reel',
    task: testTask.copyWith(status: TaskStatus.done),
    isSelected: true,
    leftBorderColor: Colors.green,
    isOverdue: true,
  ),
);

class TaskCard extends StatefulWidget {
  final String? projectTitle;
  final bool isSelected;
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onCheckChanged;
  final VoidCallback? onSelected;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool isOverdue;
  final Color? leftBorderColor;

  const TaskCard({
    super.key,
    this.projectTitle,
    required this.task,
    this.isSelected = true,
    this.onTap,
    this.onLongPress,
    this.onCheckChanged,
    this.onSelected,
    this.onDelete,
    this.isOverdue = false,
    this.leftBorderColor,
  });

  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  static const double _deleteWidth = 76;
  static const double _dragThreshold = 72;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _controller.value += -details.delta.dx / _dragThreshold;
    _controller.value = _controller.value.clamp(0.0, 1.0);
  }

  void _onDragEnd(DragEndDetails details) {
    if (_controller.value > 0.4) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _close() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final cardContent = GestureDetector(
      onHorizontalDragUpdate: widget.onDelete != null ? _onDragUpdate : null,
      onHorizontalDragEnd: widget.onDelete != null ? _onDragEnd : null,
      onLongPress: widget.onLongPress,
      onTap: widget.onTap,
      onDoubleTap: widget.onSelected,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.task.isCompleted ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isSelected
                ? const Color(0xFFB8FF63).withValues(alpha: 0.1)
                : null,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: widget.isOverdue
                ? [
                    const BoxShadow(
                      color: AppColors.overdueGlow,
                      blurRadius: 15,
                      spreadRadius: -8,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                left: 10,
                top: 40,
                bottom: 40,
                right: 100,
                child: Container(
                  decoration: widget.leftBorderColor != null
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md + 1),
                          color: widget.leftBorderColor!.withValues(alpha: 0.3),
                        )
                      : null,
                ),
              ),
              GlassPanel(
                borderRadius: AppRadius.lg,
                padding: EdgeInsets.zero,
                borderColor: widget.isSelected
                    ? const Color(0xFFB8FF63).withValues(alpha: 0.4)
                    : widget.isOverdue
                    ? AppColors.primaryContainer
                    : null,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: widget.onCheckChanged,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: widget.task.isCompleted
                                      ? AppColors.primaryContainer
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: widget.task.isCompleted
                                        ? AppColors.primaryContainer
                                        : (widget.isSelected
                                              ? const Color(
                                                  0xFFB8FF63,
                                                ).withValues(alpha: 0.4)
                                              : widget.isOverdue
                                              ? AppColors.primaryContainer
                                              : AppColors.borderGlass),
                                    width: 2,
                                  ),
                                ),
                                child: widget.task.isCompleted
                                    ? const Icon(
                                        Icons.check,
                                        size: 14,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.task.title,
                                    style: AppTypography.bodyMd.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: widget.isOverdue
                                          ? AppColors.primaryContainer
                                          : Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (widget.projectTitle != null)
                                    Text(
                                      widget.projectTitle!,
                                      style: AppTypography.bodySm.copyWith(
                                        color: AppColors.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule,
                                        size: 12,
                                        color: widget.isOverdue
                                            ? AppColors.primaryContainer
                                            : AppColors.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 4),
                                      if (widget.task.dueDate != null)
                                        Text(
                                          formatDate(widget.task.dueDate!),
                                          style: AppTypography.codeLabel
                                              .copyWith(
                                                color: widget.isOverdue
                                                    ? AppColors.primaryContainer
                                                    : AppColors
                                                          .onSurfaceVariant,
                                              ),
                                        ),
                                      if (widget.task.tags.isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: widget.isOverdue
                                                ? AppColors.primaryContainer
                                                      .withValues(alpha: 0.2)
                                                : AppColors.surfaceGlass,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Wrap(
                                            spacing: 12,
                                            runSpacing: 8,
                                            children: widget.task.tags
                                                .map(
                                                  (link) => SemanticTag(
                                                    label: link.name,
                                                    accentColor: Colors.black,
                                                  ),
                                                )
                                                .toList(),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.drag_indicator,
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                _deleteWidth * (1 - _controller.value),
                                0,
                              ),
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            onTap: () {
                              _close();
                              widget.onDelete?.call();
                            },
                            child: Container(
                              width: _deleteWidth,
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryContainer,
                                    blurRadius: 40,
                                  ),
                                ],
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.delete_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return cardContent;
  }
}
