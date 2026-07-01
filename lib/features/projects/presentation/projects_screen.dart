import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_button_styles.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/theme/app_spacing.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/wrapped.dart';
import 'package:life_os/features/projects/domain/project_model.dart';
import 'package:life_os/features/projects/presentation/widgets/project_card.dart';
import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';
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
        child: EditProjectCard(
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
        padding: const EdgeInsets.all(AppSpacing.md),
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

            const SizedBox(height: AppMargins.sm),

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

                          return ProjectCard(
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
