import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:tasks_api/tasks_api.dart';

class TaskDrag {
  TaskDrag(this.task, {this.sourceDay, this.sourceTimeline});

  final Task task;
  final DateTime? sourceDay;
  final Object? sourceTimeline;
  late Offset _anchor;
  late Offset startPosition;

  // Flutter reports the feedback's top-left corner in DragTargetDetails.
  Offset pointerAt(Offset feedbackPosition) => feedbackPosition + _anchor;
}

class TaskDraggable extends StatelessWidget {
  const TaskDraggable({
    super.key,
    required this.task,
    required this.child,
    this.sourceDay,
    this.sourceTimeline,
    this.feedback,
    this.feedbackVisible,
    this.enabled = true,
    this.onDragStarted,
    this.onDragEnd,
  });

  final Task task;
  final Widget child;
  final DateTime? sourceDay;
  final Object? sourceTimeline;
  final Widget? feedback;
  final ValueListenable<bool>? feedbackVisible;
  final bool enabled;
  final VoidCallback? onDragStarted;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final drag = TaskDrag(
      task,
      sourceDay: sourceDay,
      sourceTimeline: sourceTimeline,
    );
    final dragFeedback =
        feedback ??
        Material(
          color: AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 220,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              task.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
    return LongPressDraggable<TaskDrag>(
      data: drag,
      maxSimultaneousDrags: enabled ? 1 : 0,
      dragAnchorStrategy: (draggable, context, position) {
        drag.startPosition = position;
        return drag._anchor = feedback == null
            ? Offset.zero
            : childDragAnchorStrategy(draggable, context, position);
      },
      onDragStarted: onDragStarted,
      onDragCompleted: onDragEnd,
      onDraggableCanceled: (_, _) => onDragEnd?.call(),
      feedback: switch (feedbackVisible) {
        final visible? => ValueListenableBuilder<bool>(
          valueListenable: visible,
          child: dragFeedback,
          builder: (_, show, child) => show ? child! : const SizedBox.shrink(),
        ),
        null => dragFeedback,
      },
      childWhenDragging: Opacity(opacity: .35, child: child),
      child: child,
    );
  }
}

Color taskDropFill(Color background) =>
    Color.alphaBlend(AppColors.primary.withValues(alpha: .12), background);
