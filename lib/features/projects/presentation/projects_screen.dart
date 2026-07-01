import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/ui/date_pick_button.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/tasks/domain/task_model.dart';
import 'package:life_os/features/projects/presentation/projects_state.dart';
import 'package:life_os/features/projects/presentation/projects_view_model.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.viewModel});

  final ProjectsViewModel viewModel;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _isCreating = false;
  Project? _editingProject;

  void _startEditingProject({Project? project}) {
    setState(() {
      _isCreating = true;
      _editingProject = project;
    });
  }

  void _closeProjectForm() {
    setState(() {
      _isCreating = false;
      _editingProject = null;
    });
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'No projects available yet.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateProjectForm() {
    // Center and constrain the create form so it doesn't expand to full height
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: _EditProjectCard(
          project: _editingProject,
          onSave: (name, description, color, dueDate) async {
            if (_editingProject != null) {
              await widget.viewModel.updateProject(
                _editingProject!.copyWith(
                  name: name,
                  description: description,
                  color: color,
                  dueDate: Wrapped(dueDate),
                ),
              );
            } else {
              await widget.viewModel.addProjects(
                Project.create(
                  name: name,
                  description: description,
                  color: color,
                ).copyWith(dueDate: Wrapped(dueDate)),
              );
            }
            _closeProjectForm();
          },
          onCancel: _closeProjectForm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceDim,
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Projects',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: StreamBuilder<ProjectsScreenState>(
                stream: widget.viewModel.state,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData) return const SizedBox.shrink();

                  return snapshot.data!.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e) => Center(child: Text(e)),
                    loaded: (projects, _, _) {
                      final itemCount =
                          (projects.isEmpty && _isCreating == false)
                          ? 2
                          : projects.length + 1;

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: itemCount,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return AnimatedSwitcher(
                              duration: const Duration(milliseconds: 400),
                              reverseDuration: const Duration(
                                milliseconds: 300,
                              ),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: SizeTransition(
                                    sizeFactor: animation,
                                    //axisAlignment: -1.0,
                                    child: child,
                                  ),
                                );
                              },
                              child: _isCreating
                                  ? SizedBox(
                                      key: const ValueKey('project_form'),
                                      width: double.infinity,
                                      child: _buildCreateProjectForm(),
                                    )
                                  : SizedBox(
                                      key: const ValueKey('project_button'),
                                      width: double.infinity,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: ElevatedButton(
                                          onPressed: () {
                                            _startEditingProject();
                                          },
                                          style: AppButtonStyles.saveButton
                                              .copyWith(
                                                padding:
                                                    const WidgetStatePropertyAll(
                                                      EdgeInsets.all(
                                                        AppSpacing.xl,
                                                      ),
                                                    ),
                                              ),
                                          child: const Text(
                                            'New project',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            );
                          }
                          if (projects.isEmpty && index == 1) {
                            return _buildEmptyState();
                          }
                          final projectIndex = index - 1;
                          final project = projects[projectIndex];

                          return _ProjectCard(
                            title: project.name,
                            description: project.description,
                            color: parseHexColor(project.color),
                            dueDate: project.dueDate,
                            project: project,
                            viewModel: widget.viewModel,
                            onEditRequested: () =>
                                _startEditingProject(project: project),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Карточка с полями ввода параметров проекта
class _EditProjectCard extends StatefulWidget {
  final Function(
    String name,
    String description,
    String color,
    DateTime? dueDate,
  )
  onSave;
  final VoidCallback onCancel;
  final Project? project;

  const _EditProjectCard({
    required this.onSave,
    required this.onCancel,
    this.project,
  });

  @override
  State<_EditProjectCard> createState() => _EditProjectCardState();
}

class _EditProjectCardState extends State<_EditProjectCard> {
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
  void didUpdateWidget(covariant _EditProjectCard oldWidget) {
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
                  onStartsAtChange: (d) => setState(() {
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

class _ProjectCard extends StatefulWidget {
  final String title;
  final String description;
  final Color color;
  final Project project;
  final ProjectsViewModel viewModel;
  final VoidCallback onEditRequested;

  final DateTime? dueDate;

  const _ProjectCard({
    required this.title,
    required this.description,
    required this.color,
    required this.project,
    required this.viewModel,
    required this.onEditRequested,
    this.dueDate,
  });

  @override
  State<_ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<_ProjectCard> {
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

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          color: Theme.of(
            context,
          ).colorScheme.surface, // neutral dark background like screenshot
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withValues(
                              alpha: 0.06,
                            ),
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
                                      .surfaceVariant
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              widget.title,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
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
                        PopupMenuButton<String>(
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
