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
import 'glass_panel.dart'; // Из предыдущего шага

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

class TaskCard extends StatelessWidget {
  final String? projectTitle;

  // final String title;
  // final DateTime? dueDate;
  // final List<Tag> tags;
  // final bool isCompleted;
  final bool isSelected;
  final Task task;
  final VoidCallback? onTap;
  final VoidCallback? onCheckChanged;
  final VoidCallback? onSelected;
  final VoidCallback? onLongPress;
  final bool isOverdue;
  final Color? leftBorderColor; // Для задач со статус-линией слева

  const TaskCard({
    super.key,
    // required this.title,
    // required this.dueDate,
    this.projectTitle,
    required this.task,
    // required this.tags,
    // required this.isCompleted,
    this.isSelected = true,
    this.onTap,
    this.onLongPress,
    this.onCheckChanged,
    this.onSelected,
    this.isOverdue = false,
    this.leftBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      onDoubleTap: onSelected,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: task.isCompleted ? 0.5 : 1.0,
        child: Container(
          // Настройка свечения overdue-glow или стандартных рамок
          decoration: BoxDecoration(
            color: isSelected ? Color(0xFFB8FF63).withValues(alpha: 0.1) : null,

            borderRadius: BorderRadius.circular(12),
            boxShadow: isOverdue
                ? [
                    const BoxShadow(
                      color: AppColors.overdueGlow,
                      blurRadius: 15,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: GlassPanel(
            borderRadius: 12,
            padding: EdgeInsets
                .zero, // Срезы контролируем через внутренний контейнер
            borderColor:   isSelected
                    ? Color(0xFFB8FF63).withValues(alpha: 0.4)
                    : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: leftBorderColor != null
                    ? Border(
                        left: BorderSide(color: leftBorderColor!, width: 4),
                        //right: BorderSide(color: leftBorderColor!, width: 2)
                      )
                    : isSelected
                    ? Border.all(color: Color(0xFFB8FF63).withValues(alpha: 0.4), width: 1)
                    :  
                    isOverdue
                    ? Border.all(color: AppColors.primaryContainer, width: 1)
                    : null,
              ),
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Кастомный круглый Чекбокс
                  GestureDetector(
                    onTap: onCheckChanged,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: task.isCompleted
                            ? AppColors.primaryContainer
                            : Colors.transparent,
                        border: Border.all(
                          color: task.isCompleted
                              ? AppColors.primaryContainer
                              : (isSelected
                                    ? Color(0xFFB8FF63).withValues(alpha: 0.4)
                                    : isOverdue
                                    ? AppColors.primaryContainer
                                    : AppColors.borderGlass),
                          width: 2,
                        ),
                      ),
                      child: task.isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Контентная часть
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: AppTypography.bodyMd.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isOverdue
                                ? AppColors.primaryContainer
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (projectTitle != null)
                          Text(
                            projectTitle!,
                            style: AppTypography.bodySm.copyWith(
                              color: AppColors.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Метаданные (Время / Теги)
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 12,
                              color: isOverdue
                                  ? AppColors.primaryContainer
                                  : AppColors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            if (task.dueDate != null)
                              Text(
                                formatDate(task.dueDate!),
                                style: AppTypography.codeLabel.copyWith(
                                  color: isOverdue
                                      ? AppColors.primaryContainer
                                      : AppColors.onSurfaceVariant,
                                ),
                              ),
                            if (task.tags.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? AppColors.primaryContainer.withValues(
                                          alpha: 0.2,
                                        )
                                      : AppColors.surfaceGlass,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 8,
                                  children: task.tags
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
                  // Иконка перетаскивания (показывается условно)
                  Icon(
                    Icons.drag_indicator,
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
