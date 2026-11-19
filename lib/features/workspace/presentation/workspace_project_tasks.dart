import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:tasks_plugin/tasks_logic.dart';
import 'package:life_os/core/theme/app_colors.dart';
import 'package:life_os/core/ui/app_scroll_behavior.dart';
import 'package:life_os/core/ui/task_card.dart';
import 'package:life_os/core/ui/task_drag.dart';
import 'package:life_os/core/utils/color_format.dart';
import 'package:life_os/core/utils/date_format.dart';
import '../workspace_layout.dart';

class WorkspaceProjectTasks extends StatefulWidget {
  const WorkspaceProjectTasks({
    super.key,
    required this.model,
    required this.pane,
    required this.onSelectionChanged,
    required this.onOpenTask,
    required this.onDatesChanged,
    required this.isActive,
    this.workLogs,
  });

  final TasksViewModel model;
  final WorkspacePane pane;
  final void Function(List<String>?, bool) onSelectionChanged;
  final ValueChanged<Task> onOpenTask;
  final void Function(DateTime?, DateTime?) onDatesChanged;
  final bool Function() isActive;
  final WorkLogsApi? workLogs;

  @override
  State<WorkspaceProjectTasks> createState() => _WorkspaceProjectTasksState();
}

class _WorkspaceProjectTasksState extends State<WorkspaceProjectTasks> {
  late final _tasks = widget.model.watchAllTasks();
  late final _projects = widget.model.watchProjects();
  final _pending = <String>{};

  Future<void> _toggle(Task task) async {
    if (!widget.isActive() || !_pending.add(task.id)) return;
    setState(() {});
    try {
      await widget.model.toggleTask(task);
    } catch (_) {
      if (mounted && widget.isActive()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось обновить задачу')),
        );
      }
    } finally {
      _pending.remove(task.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _chooseProjects(List<Project> projects) async {
    if (!widget.isActive()) return;
    final result = await showDialog<({List<String>? ids, bool unassigned})>(
      context: context,
      builder: (_) => _ProjectPicker(projects: projects, pane: widget.pane),
    );
    if (result != null && mounted && widget.isActive()) {
      widget.onSelectionChanged(result.ids, result.unassigned);
    }
  }

  Future<void> _chooseDates() async {
    if (!widget.isActive()) return;
    final from = widget.pane.dateFrom;
    final to = widget.pane.dateTo;
    final result = await showDateRangePicker(
      context: context,
      firstDate: from != null && from.year < 2000 ? from : DateTime(2000),
      lastDate: to != null && to.year > 2140 ? to : DateTime(2140, 12, 31),
      initialDateRange: from == null
          ? null
          : DateTimeRange(start: from, end: to!),
      helpText: 'Период задач',
      saveText: 'Применить',
      confirmText: 'Применить',
      cancelText: 'Отмена',
      fieldStartLabelText: 'Начало периода',
      fieldEndLabelText: 'Конец периода',
    );
    if (result != null && mounted && widget.isActive()) {
      widget.onDatesChanged(result.start, result.end);
    }
  }

  bool _matchesDates(Task task) {
    final from = widget.pane.dateFrom;
    final to = widget.pane.dateTo;
    if (from == null || to == null) return true;
    final start = task.startsAt;
    if (start == null) return false;
    final end = task.endsAt;
    final last = end != null && !end.isBefore(start) ? end : start;
    final until = DateTime(to.year, to.month, to.day + 1);
    return start.isBefore(until) &&
        !DateTime(last.year, last.month, last.day).isBefore(from);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Project>>(
    stream: _projects,
    builder: (context, projectsSnapshot) => StreamBuilder<List<Task>>(
      stream: _tasks,
      builder: (context, tasksSnapshot) {
        if (projectsSnapshot.hasError || tasksSnapshot.hasError) {
          return const Center(
            child: Text('Не удалось загрузить задачи проектов'),
          );
        }
        if (!projectsSnapshot.hasData || !tasksSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final projects = [
          ...projectsSnapshot.data!,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final selected = widget.pane.projectIds?.toSet();
        final columns = <Project?>[
          for (final project in projects)
            if (selected == null || selected.contains(project.id)) project,
          if (widget.pane.showUnassigned) null,
        ];
        final byProject = <String?, List<Task>>{};
        for (final task in tasksSnapshot.data!) {
          if (!_matchesDates(task)) continue;
          (byProject[task.projectId] ??= []).add(task);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _chooseProjects(projects),
                  icon: const Icon(Icons.filter_list, size: 18),
                  label: Text('Выбрать проекты (${columns.length})'),
                ),
                TextButton.icon(
                  key: const ValueKey('project-tasks.dates'),
                  onPressed: _chooseDates,
                  icon: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(
                    widget.pane.dateFrom == null
                        ? 'Все даты'
                        : '${formatDate(widget.pane.dateFrom!)} — ${formatDate(widget.pane.dateTo!)}',
                  ),
                ),
                TextButton(
                  key: const ValueKey('project-tasks.today'),
                  onPressed: () {
                    if (!widget.isActive()) return;
                    final today = DateUtils.dateOnly(DateTime.now());
                    widget.onDatesChanged(today, today);
                  },
                  child: const Text('Сегодня'),
                ),
                if (widget.pane.dateFrom != null)
                  IconButton(
                    tooltip: 'Сбросить период',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      if (widget.isActive()) widget.onDatesChanged(null, null);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: columns.isEmpty
                  ? const Center(
                      child: Text('Выберите проекты для отображения'),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final width = math.max(
                          300.0,
                          (constraints.maxWidth - (columns.length - 1) * 12) /
                              columns.length,
                        );
                        return SingleChildScrollView(
                          key: const ValueKey('project-tasks.board'),
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = 0; i < columns.length; i++) ...[
                                if (i > 0) const SizedBox(width: 12),
                                SizedBox(
                                  width: width,
                                  child: _column(
                                    columns[i],
                                    byProject[columns[i]?.id] ?? const [],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    ),
  );

  Widget _column(Project? project, List<Task> tasks) {
    final color = project == null
        ? AppColors.onSurfaceVariant
        : parseHexColor(project.color);
    final title = project?.name ?? 'Без проекта';
    return Container(
      key: ValueKey('project-tasks.column:${project?.id ?? 'unassigned'}'),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGlass),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.folder_outlined, color: color, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${tasks.length}'),
              ],
            ),
          ),
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text('Нет задач'))
                : ScrollConfiguration(
                    behavior: const AppScrollBehavior(
                      fadeColor: AppColors.surfaceContainerLow,
                    ),
                    child: ListView.builder(
                      key: PageStorageKey('project-tasks.list:${project?.id}'),
                      primary: false,
                      padding: const EdgeInsets.all(8),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TaskDraggable(
                            task: task,
                            enabled: widget.isActive(),
                            child: TaskCard(
                              key: ValueKey('project-task:${task.id}'),
                              task: task,
                              isSelected: false,
                              projectTitle: project?.name,
                              leftBorderColor: color,
                              workLogs: widget.workLogs,
                              isOverdue:
                                  !task.isCompleted &&
                                  (task.dueDate?.isBefore(
                                        DateUtils.dateOnly(DateTime.now()),
                                      ) ??
                                      false),
                              onTap: () {
                                if (widget.isActive()) widget.onOpenTask(task);
                              },
                              onCheckChanged: _pending.contains(task.id)
                                  ? null
                                  : () => _toggle(task),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProjectPicker extends StatefulWidget {
  const _ProjectPicker({required this.projects, required this.pane});
  final List<Project> projects;
  final WorkspacePane pane;

  @override
  State<_ProjectPicker> createState() => _ProjectPickerState();
}

class _ProjectPickerState extends State<_ProjectPicker> {
  late bool _all = widget.pane.projectIds == null;
  late final _selected = {
    ...?widget.pane.projectIds,
    if (_all) ...widget.projects.map((p) => p.id),
  };
  late bool _unassigned = widget.pane.showUnassigned;
  String _query = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Проекты в панели'),
    content: SizedBox(
      width: 420,
      height: 400,
      child: Column(
        children: [
          TextField(
            decoration: const InputDecoration(
              hintText: 'Поиск проектов',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value.toLowerCase()),
          ),
          CheckboxListTile(
            title: const Text('Все проекты'),
            subtitle: const Text('Включая новые проекты'),
            value: _all,
            onChanged: (value) => setState(() {
              _all = value!;
              _selected.clear();
              if (_all) _selected.addAll(widget.projects.map((p) => p.id));
            }),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final project in widget.projects)
                  if (project.name.toLowerCase().contains(_query))
                    CheckboxListTile(
                      key: ValueKey('project-picker:${project.id}'),
                      title: Text(project.name),
                      secondary: Icon(
                        Icons.folder_outlined,
                        color: parseHexColor(project.color),
                      ),
                      value: _selected.contains(project.id),
                      onChanged: (value) => setState(() {
                        _all = false;
                        value!
                            ? _selected.add(project.id)
                            : _selected.remove(project.id);
                      }),
                    ),
                if (widget.projects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Проектов пока нет'),
                  ),
              ],
            ),
          ),
          CheckboxListTile(
            title: const Text('Без проекта'),
            value: _unassigned,
            onChanged: (value) => setState(() => _unassigned = value!),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, (
          ids: _all ? null : _selected.toList(),
          unassigned: _unassigned,
        )),
        child: const Text('Применить'),
      ),
    ],
  );
}
