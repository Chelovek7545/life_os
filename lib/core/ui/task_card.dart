import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/semantic_tag.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'glass_panel.dart';

const _selectedBg = Color(0x1AB8FF63);
const _selectedBorder = Color(0x66B8FF63);

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
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          decoration: BoxDecoration(
          color: widget.isSelected
              ? _selectedBg
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
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  left: 4,
                  top: 14,
                  bottom: 14,
                  child: Container(
                    width: 7,
                    decoration: BoxDecoration(
                      color:
                          widget.leftBorderColor ?? AppColors.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                GlassPanel(
                  borderRadius: AppRadius.lg,
                  padding: EdgeInsets.zero,
                  borderColor: widget.isSelected
                      ? _selectedBorder
                      : widget.isOverdue
                      ? AppColors.primaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckDot(
                          isCompleted: widget.task.isCompleted,
                          isOverdue: widget.isOverdue,
                          isSelected: widget.isSelected,
                          onCheckChanged: () => widget.onCheckChanged?.call(),
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
                              if (widget.task.dueDate != null)
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

                                    Text(
                                      formatDate(widget.task.dueDate!),
                                      style: AppTypography.codeLabel.copyWith(
                                        color: widget.isOverdue
                                            ? AppColors.primaryContainer
                                            : AppColors.onSurfaceVariant,
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
                ),
                RepaintBoundary(
                  child: Positioned(
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
                          child: GestureDetector(
                            onTap: () {
                              _close();
                              widget.onDelete?.call();
                            },
                            child: Container(
                              width: _deleteWidth,
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.delete_outlined,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return cardContent;
  }
}

class CheckDot extends StatelessWidget {
  const CheckDot({
    super.key,
    required this.isCompleted,
    required this.onCheckChanged,
    required this.isSelected,
    required this.isOverdue,
  });

  final bool isCompleted;
  final bool isSelected;
  final bool isOverdue;
  final VoidCallback onCheckChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCheckChanged,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isCompleted ? AppColors.primaryContainer : Colors.transparent,
          border: Border.all(
                  color: isCompleted
                      ? AppColors.primaryContainer
                      : (isSelected
                            ? _selectedBorder
                      : isOverdue
                      ? AppColors.primaryContainer
                      : AppColors.borderGlass),
            width: 2,
          ),
        ),
        child: isCompleted
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}
