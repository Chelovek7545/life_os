import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/tasks/domain/tag_model.dart';

@Preview()
Widget newPreview() => MaterialApp(
      theme: ThemeData.light(),
      home: TaskCard(
        title: "Sample Task",
        dueDate: DateTime.now(),
        tags: [Tag(id: 1, name: "new", colorHex: 91823918)],
      ),
    );

@Preview()
Widget completedPreview() => MaterialApp(
      theme: ThemeData.light(),
      home: TaskCard(
        title: "Sample Task",
        dueDate: DateTime.now(),
        completed: true,
        tags: [Tag(id: 1, name: "new", colorHex: 91823918)],
      ),
    );

@Preview()
Widget completedSelectedPreview() => MaterialApp(
      theme: ThemeData.light(),
      home: TaskCard(
        title: "Sample Task",
        dueDate: DateTime.now(),
        isSelected: true,
        completed: true,
        tags: [Tag(id: 1, name: "new", colorHex: 91823918)],
      ),
    );

class TaskCard extends StatelessWidget {
  final String title;
  final DateTime? dueDate;
  final String? projectTitle;
  final List<Tag> tags;
  final bool completed;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onCheckChanged;
  final VoidCallback? onSelected;
  final VoidCallback? onLongPress;


  
  const TaskCard({
    super.key,
    required this.title,
    required this.dueDate,
    this.projectTitle,
    required this.tags,
    this.completed = false,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
    this.onCheckChanged,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(      
      onLongPress: onLongPress,
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 16,
            sigmaY: 16,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: isSelected ? Color(0xFFB8FF63).withValues(alpha: 0.4) : Colors.white.withOpacity(0.12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _CompletionButton(
                  completed: completed,
                  onTap: onCheckChanged,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Row(
                          
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            
                                color: Colors.white,
                                fontWeight:
                                    FontWeight.w700,
                              
                              )
                            ),
                    
                            const SizedBox(width: 10),
                    
                            if (dueDate != null) Text(
                              formatDate(dueDate!),
                              style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                color: Colors.white
                                    .withOpacity(0.7),
                                
                                fontWeight:
                                    FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    
                        if (projectTitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            projectTitle!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withOpacity(0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                    
                        if (tags.isNotEmpty) ...[
                          const SizedBox(height: 4),
                    
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: tags
                                .map(
                                  (link) => _LinkChip(
                                    title: link.name,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                

                GestureDetector(
                  onTap: onSelected,
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 200,
                    ),
                    width: 21,
                    height: 21,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(6),
                      color: isSelected
                          ? const Color(0xFFB8FF63)
                          : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFB8FF63)
                            : Colors.white
                                .withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 11,
                            color: Colors.black,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


}

class _CompletionButton extends StatelessWidget {
  final bool completed;
  final VoidCallback? onTap;

  const _CompletionButton({
    required this.completed,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: completed
              ? const Color(0xFFE7FFD0)
              : Colors.white.withOpacity(0.12),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
          ),
          boxShadow: completed
              ? [
                  BoxShadow(
                    color: const Color(
                      0xFFB8FF63,
                    ).withValues(alpha: 0.35),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.check,
          size: 19,
          color: completed
              ? Colors.green.shade700
              : Colors.transparent,
        ),
      ),
    );
  }
}

class _LinkChip extends StatelessWidget {
  final String title;

  const _LinkChip({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.tag_rounded,
            size: 18,
            color: Color(0xFFB8FF63),
          ),

          const SizedBox(width: 8),

          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}