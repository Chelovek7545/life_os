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

  Future<void> _openProjectDialog({
    Project? project,
    bool isCompleted = false,
  }) async {
    final viewModel = widget.viewModel;
    await showGeneralDialog<void>(
      context: context,
      barrierColor: AppColors.surfaceDim.withValues(alpha: 0.65),
      transitionDuration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      transitionBuilder: (_, _, _, child) => child,
      pageBuilder: (dialogContext, animation, _) {
        final entrance = animation.drive(
          CurveTween(curve: Curves.easeOutCubic),
        );
        return SafeArea(
          child: Dialog(
            alignment: Alignment.topCenter,
            insetPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            constraints: const BoxConstraints(maxWidth: 760),
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(),
            elevation: 0,
            child: SlideTransition(
              position: entrance.drive(
                Tween(begin: const Offset(0, -1), end: Offset.zero),
              ),
              child: FadeTransition(
                opacity: entrance,
                child: SingleChildScrollView(
                  child: EditProjectCard(
                    project: project,
                    isCompleted: isCompleted,
                    onSave: (draft) async {
                      if (!mounted || !identical(widget.viewModel, viewModel)) {
                        throw StateError('Projects screen has changed');
                      }
                      if (project == null) {
                        await viewModel.addProjects(draft);
                      } else {
                        await viewModel.updateProject(draft);
                      }
                      if (dialogContext.mounted &&
                          ModalRoute.of(dialogContext)?.isCurrent == true) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    onCancel: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  Widget _buildProjects(List<Project> projects, double width) {
    return StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Не удалось загрузить задачи проектов.')),
          );
        }
        if (!snapshot.hasData) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          );
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

        final maxColumns = !_grid || width < 720
            ? 1
            : width < 1120
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
        return SliverPadding(
          padding: const EdgeInsets.only(bottom: 8),
          sliver: SliverList.builder(
            itemCount: rows.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
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
                padding: EdgeInsets.only(bottom: index == rows.length ? 0 : 18),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows[index - 1].length; i++) ...[
                        if (i > 0) const SizedBox(width: 18),
                        Expanded(
                          child: _projectCard(rows[index - 1][i], byProject),
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
      onEditRequested: () {
        final projectTasks = tasks[project.id] ?? const <Task>[];
        _openProjectDialog(
          project: project,
          isCompleted:
              projectTasks.isNotEmpty &&
              projectTasks.every((task) => task.isCompleted),
        );
      },
    );
  }

  Widget _buildGallery() {
    return LayoutBuilder(
      builder: (context, constraints) => CustomScrollView(
        key: const PageStorageKey('projects.gallery'),
        primary: false,
        scrollBehavior: const AppScrollBehavior(
          fadeExtent: 56,
          fadeStart: false,
        ),
        slivers: [
          PinnedHeaderSliver(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surfaceDim,
                    AppColors.surfaceDim.withValues(alpha: 0.8),
                    AppColors.surfaceDim.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
              child: _buildHeader(),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          StreamBuilder<ProjectsScreenState>(
            stream: widget.viewModel.state,
            builder: (context, snapshot) {
              const loading = SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              );
              final state = snapshot.data;
              if (state == null) return loading;
              return state.when(
                loading: () => loading,
                error: (error) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(error)),
                ),
                loaded: (projects, _, _) =>
                    _buildProjects(projects, constraints.maxWidth),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                onPressed: _openProjectDialog,
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildGallery(),
    );
  }
}
