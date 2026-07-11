import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/ui/date_pick_button.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/features/projects/domain/project_model.dart';

class EditProjectCard extends StatefulWidget {
  final Function(
    String name,
    String description,
    String color,
    DateTime? dueDate,
  )
  onSave;
  final VoidCallback onCancel;
  final Project? project;

  const EditProjectCard({super.key, 
    required this.onSave,
    required this.onCancel,
    this.project,
  });

  @override
  State<EditProjectCard> createState() => EditProjectCardState();
}


class EditProjectCardState extends State<EditProjectCard> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String _selectedColor = '#4A90D9';
  DateTime? _dueDate;

  // A quick palette of preset hex colors for your Life OS style
  final List<String> _colorPalette = [
    '#4A90D9', // Default Blue
    '#E74C3C', // Red
    '#2ECC71', // Green
    '#F1C40F', // Yellow
    '#9B59B6', // Purple
    '#E67E22', // Orange
    '#34495E', // Dark Slate
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descController = TextEditingController(
      text: widget.project?.description ?? '',
    );
    _selectedColor = widget.project?.color ?? '#4A90D9';
    _dueDate = widget.project?.dueDate;
  }

  @override
  void didUpdateWidget(covariant EditProjectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.project != widget.project) {
      _nameController.text = widget.project?.name ?? '';
      _descController.text = widget.project?.description ?? '';
      _selectedColor = widget.project?.color ?? '#4A90D9';
      _dueDate = widget.project?.dueDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),

      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderGlass),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (widget.project == null
                        ? 'CONFIGURE NEW PROJECT'
                        : 'EDIT PROJECT')
                    .toUpperCase(),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryContainer,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'OBJECT TITLE',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withValues(alpha: 0.04),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                ),
                style: theme.textTheme.bodyMedium,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Введите название' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'DESCRIPTION MODULE',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceVariant.withValues(alpha: 0.02),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                maxLines: 3,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              // Horizontal Color Selection List
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _colorPalette.length,
                  itemBuilder: (context, index) {
                    final hexColor = _colorPalette[index];
                    final isSelected = _selectedColor == hexColor;
                    final color = parseHexColor(hexColor);

                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = hexColor),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6.0),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.black, width: 3.0)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: 200,
                child: datePickButton(
                  context,
                  label: _dueDate == null ? "Due date" : formatDate(_dueDate!),
                  onDateChange: (d) => setState(() {
                    _dueDate = d;
                  }),
                ),
              ),
              SizedBox(height: AppSpacing.lg),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: widget.onCancel,
                    child: Text(
                      'CANCEL',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  ElevatedButton(
                    style: AppButtonStyles.saveButton,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onSave(
                          _nameController.text,
                          _descController.text,
                          _selectedColor,
                          _dueDate,
                        );
                      }
                    },
                    child: Text(
                      widget.project == null
                          ? 'INITIALIZE PROJECT'
                          : 'SAVE CHANGES',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
