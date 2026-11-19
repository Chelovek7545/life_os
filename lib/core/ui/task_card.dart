import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/theme/app_text_styles.dart';
import 'package:life_os/core/ui/semantic_tag.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:core_contracts/core_contracts.dart' show Wrapped;
import 'package:tasks_api/tasks_api.dart'
    show Tag, Task, TaskStatus, WorkLogsApi;
import 'task_work_logs.dart';
import 'glass_panel.dart';

final testTask = Task.blank().copyWith(
  title: 'jisd jkjfkljdfk;ljkdlf j;akljdkaljkl fj;aklsjfklajafljs',
  dueDate: Wrapped(DateTime.now()),
  tags: [
    'work',
    'gym',
  ].map((e) => Tag(id: 1, name: e, colorHex: 183024)).toList(),
);

@Preview()
Widget preview0() => MaterialApp(
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
Widget preview1() => MaterialApp(
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
Widget preview2() => MaterialApp(
  theme: ThemeData.light(),
  home: TaskCard(
    projectTitle: '5m reel',
    task: testTask.copyWith(status: TaskStatus.done),
    isSelected: true,
    leftBorderColor: Colors.green,
    isOverdue: true,
  ),
);

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
  final Widget? indicator;
  final WorkLogsApi? workLogs;
  final Widget? footer;
  final bool compact;

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
    this.indicator,
    this.workLogs,
    this.footer,
    this.compact = false,
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
    if (widget.workLogs != null) {
      return TaskWorkLogsBuilder(
        taskId: widget.task.id,
        repository: widget.workLogs,
        compact: widget.compact,
        builder: _buildCard,
      );
    }
    return _buildCard(widget.footer);
  }

  Widget _buildCompactHeader() {
    final dueDate = widget.task.dueDate;
    final projectTitle = widget.projectTitle;
    final indicator = widget.indicator;
    final metadataColor = widget.isOverdue
        ? AppColors.primaryContainer
        : AppColors.onSurfaceVariant;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: widget.onSelected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CheckDot(
                isCompleted: widget.task.isCompleted,
                isOverdue: widget.isOverdue,
                isSelected: widget.isSelected,
                onCheckChanged: () => widget.onCheckChanged?.call(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodyMd.copyWith(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: widget.isOverdue
                        ? AppColors.primaryContainer
                        : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.drag_indicator,
                size: 16,
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
          if (indicator != null || dueDate != null || projectTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                children: [
                  if (indicator != null) ...[
                    indicator,
                    const SizedBox(width: 4),
                  ],
                  if (dueDate != null) ...[
                    Icon(Icons.schedule, size: 12, color: metadataColor),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          if (dueDate != null)
                            TextSpan(
                              text: formatDate(dueDate),
                              style: AppTypography.codeLabel.copyWith(
                                fontSize: 10,
                                color: metadataColor,
                              ),
                            ),
                          if (dueDate != null && projectTitle != null)
                            const TextSpan(text: ' · '),
                          if (projectTitle != null)
                            TextSpan(text: projectTitle),
                        ],
                      ),
                      style: AppTypography.bodySm.copyWith(
                        fontSize: 11,
                        height: 1.25,
                        color: AppColors.onSurfaceVariant.withValues(alpha: .8),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget? footer) {
    final cardContent = GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: widget.onDelete != null ? _onDragUpdate : null,
      onHorizontalDragEnd: widget.onDelete != null ? _onDragEnd : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: widget.task.isCompleted ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: widget.isSelected ? _selectedBg : null,
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
                GlassPanel(
                  hasBlur: false,
                  borderRadius: AppRadius.lg,
                  padding: EdgeInsets.zero,
                  borderColor: widget.isSelected
                      ? _selectedBorder
                      : widget.isOverdue
                      ? AppColors.primaryContainer
                      : null,
                  child: Container(
                    padding: widget.compact
                        ? const EdgeInsets.fromLTRB(11, 10, 8, 10)
                        : EdgeInsets.all(footer == null ? 22 : 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.compact)
                          _buildCompactHeader()
                        else
                          Padding(
                            padding: EdgeInsets.all(footer == null ? 0 : 8),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onTap,
                              onDoubleTap: widget.onSelected,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CheckDot(
                                    isCompleted: widget.task.isCompleted,
                                    isOverdue: widget.isOverdue,
                                    isSelected: widget.isSelected,
                                    onCheckChanged: () =>
                                        widget.onCheckChanged?.call(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            style: AppTypography.bodySm
                                                .copyWith(
                                                  color: AppColors
                                                      .onSurfaceVariant
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
                                                    : AppColors
                                                          .onSurfaceVariant,
                                              ),
                                              const SizedBox(width: 4),

                                              Text(
                                                formatDate(
                                                  widget.task.dueDate!,
                                                ),
                                                style: AppTypography.codeLabel
                                                    .copyWith(
                                                      color: widget.isOverdue
                                                          ? AppColors
                                                                .primaryContainer
                                                          : AppColors
                                                                .onSurfaceVariant,
                                                    ),
                                              ),
                                              if (widget
                                                  .task
                                                  .tags
                                                  .isNotEmpty) ...[
                                                const SizedBox(width: 12),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: widget.isOverdue
                                                        ? AppColors
                                                              .primaryContainer
                                                              .withValues(
                                                                alpha: 0.2,
                                                              )
                                                        : AppColors
                                                              .surfaceGlass,
                                                    borderRadius:
                                                        BorderRadius.circular(
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
                                                            accentColor:
                                                                Colors.black,
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
                                  if (widget.indicator != null) ...[
                                    widget.indicator!,
                                    const SizedBox(width: 8),
                                  ],
                                  GestureDetector(
                                    onTap: widget.onTap,
                                    child: Icon(
                                      Icons.drag_indicator,
                                      color: AppColors.onSurfaceVariant
                                          .withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ?footer,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: widget.compact ? 3 : 4,
                  top: widget.compact ? 8 : 14,
                  bottom: widget.compact ? 8 : 14,
                  child: Container(
                    width: widget.compact ? 3 : 7,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color:
                              widget.leftBorderColor ??
                              AppColors.onSurfaceVariant,
                          blurRadius: widget.compact ? 8 : 13,
                          spreadRadius: -2,
                          offset: Offset(3, 0),
                        ),
                      ],
                      color:
                          widget.leftBorderColor ?? AppColors.onSurfaceVariant,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: RepaintBoundary(
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
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryContainer,
                                    blurRadius: _controller.value * 40,
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
