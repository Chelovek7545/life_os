import 'package:flutter/material.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';
import 'package:life_os/core/ui/segmented_pill_controller.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/features/projects/presentation/widgets/project_card.dart';
import 'package:life_os/features/projects/presentation/widgets/project_editing_card.dart';
import 'package:projects_api/projects_api.dart';
import 'package:projects_plugin/projects_logic.dart';
import 'package:tasks_api/tasks_api.dart';

enum _ProjectFilter {
  all('Все'),
  active('Активные'),
  completed('Завершённые'),
  archived('Архив');

  const _ProjectFilter(this.label);
  final String label;
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key, required this.viewModel});

  final ProjectsViewModel viewModel;

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  bool _isCreating = false;
  Project? _editingProject;
  _ProjectFilter _filter = _ProjectFilter.all;
  bool _grid = true;
  late Stream<List<Task>> _tasks;

  @override
  void initState() {
    super.initState();
    _tasks = widget.viewModel.watchAllTasks();
  }

  @override
  void didUpdateWidget(covariant ProjectsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _tasks = widget.viewModel.watchAllTasks();
    }
  }

  void _startEditingProject({Project? project}) {
    setState(() {
      _isCreating = true;
      _editingProject = project;
    });
  }

  void _closeProjectForm() {
    if (!mounted) return;
    setState(() {
      _isCreating = false;
      _editingProject = null;
    });
  }

  Widget _buildCreateProjectForm() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: EditProjectCard(
          key: ValueKey(_editingProject?.id),
          project: _editingProject,
          onSave: (name, description, color, dueDate) async {
            final project = _editingProject;
            if (project != null) {
              await widget.viewModel.updateProject(
                project.copyWith(
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

  Widget _buildToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final filters = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: 640,
            child: SegmentedPillControl(
              tabs: _ProjectFilter.values
                  .map((filter) => filter.label)
                  .toList(),
              currentIdx: _filter.index,
              onTabChanged: (index) =>
                  setState(() => _filter = _ProjectFilter.values[index]),
            ),
          ),
        );
        final views = Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.borderGlass),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _viewButton(Icons.grid_view_rounded, 'Сетка', true),
              _viewButton(Icons.view_list_rounded, 'Список', false),
            ],
          ),
        );
        if (constraints.maxWidth < 660) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [filters, const SizedBox(height: 12), views],
          );
        }
        return Row(
          children: [
            Expanded(child: filters),
            const SizedBox(width: 20),
            views,
          ],
        );
      },
    );
  }

  Widget _viewButton(IconData icon, String label, bool grid) {
    final selected = _grid == grid;
    return IconButton(
      tooltip: label,
      isSelected: selected,
      onPressed: () => setState(() => _grid = grid),
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? AppColors.primaryContainer.withValues(alpha: 0.18)
            : Colors.transparent,
        foregroundColor: selected ? AppColors.primary : const Color(0xFFBDB9B7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.all(14),
      ),
      icon: Icon(icon, size: 23),
    );
  }

  Widget _buildProjects(List<Project> projects) {
    return StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Не удалось загрузить задачи проектов.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final byProject = <String, List<Task>>{};
        for (final task in snapshot.data!) {
          final id = task.projectId;
          if (id != null) (byProject[id] ??= []).add(task);
        }
        final visible = projects.where((project) {
          final tasks = byProject[project.id] ?? const <Task>[];
          final completed =
              tasks.isNotEmpty && tasks.every((task) => task.isCompleted);
          return switch (_filter) {
            _ProjectFilter.all => true,
            _ProjectFilter.active => !project.isArchived && !completed,
            _ProjectFilter.completed => !project.isArchived && completed,
            _ProjectFilter.archived => project.isArchived,
          };
        }).toList();

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxColumns = !_grid || constraints.maxWidth < 720
                ? 1
                : constraints.maxWidth < 1120
                ? 2
                : 3;
            // Alternate two feature cards, three compact cards and a wide card.
            final rows = <List<Project>>[];
            var offset = 0;
            while (offset < visible.length) {
              final count = maxColumns == 3
                  ? const [2, 3, 1][rows.length % 3]
                  : maxColumns;
              final end = (offset + count).clamp(0, visible.length);
              rows.add(visible.sublist(offset, end));
              offset = end;
            }
            return ScrollConfiguration(
              behavior: const AppScrollBehavior(fadeExtent: 56),
              child: ListView.builder(
                key: const PageStorageKey('projects.gallery'),
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: rows.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    if (_isCreating) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: _buildCreateProjectForm(),
                      );
                    }
                    if (visible.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 64,
                          horizontal: 16,
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.folder_open_rounded,
                              size: 48,
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              projects.isEmpty
                                  ? 'Здесь будут ваши проекты'
                                  : 'В этой категории пока нет проектов',
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              projects.isEmpty
                                  ? 'Создайте первый проект и соберите в нём задачи.'
                                  : 'Выберите другую категорию или создайте новый проект.',
                              style: const TextStyle(color: Color(0xFFAAA5A2)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == rows.length ? 0 : 18,
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < rows[index - 1].length; i++) ...[
                            if (i > 0) const SizedBox(width: 18),
                            Expanded(
                              child: _projectCard(
                                rows[index - 1][i],
                                byProject,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _projectCard(Project project, Map<String, List<Task>> tasks) {
    return ProjectCard(
      key: ValueKey(project.id),
      title: project.name,
      description: project.description,
      color: parseHexColor(project.color),
      dueDate: project.dueDate,
      project: project,
      viewModel: widget.viewModel,
      tasks: tasks[project.id] ?? const [],
      onEditRequested: () => _startEditingProject(project: project),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Проекты',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _isCreating ? null : () => _startEditingProject(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Новый проект'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildToolbar(),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<ProjectsScreenState>(
              stream: widget.viewModel.state,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return snapshot.data!.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error) => Center(child: Text(error)),
                  loaded: (projects, _, _) => _buildProjects(projects),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
