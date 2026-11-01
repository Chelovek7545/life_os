import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'projects_panel_model.dart';

class ProjectsPanel extends StatefulWidget {
  const ProjectsPanel({super.key, required this.viewModel, this.onOpenProject});
  final ProjectsPanelModel viewModel;
  final void Function(Project)? onOpenProject;
  @override
  State<ProjectsPanel> createState() => _ProjectsPanelState();
}

class _ProjectsPanelState extends State<ProjectsPanel> {
  @override
  Widget build(BuildContext context) => StreamBuilder<ProjectsPanelState>(
    stream: widget.viewModel.state,
    initialData: widget.viewModel.currentState,
    builder: (context, snapshot) {
      final state = snapshot.data!;
      Widget body;
      if (state.error != null) {
        body = const Text('Не удалось загрузить проекты.');
      } else if (state.isLoading) {
        body = const Center(child: CircularProgressIndicator());
      } else if (state.projects.isEmpty) {
        body = const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Text('Подходящих проектов нет'),
        );
      } else {
        body = SizedBox(
          height: math.min(360, state.projects.length * 104).toDouble(),
          child: ListView.builder(
            key: PageStorageKey(this),
            primary: false,
            itemCount: state.projects.length,
            itemBuilder: (context, index) {
              final item = state.projects[index];
              final project = item.project;
              final hex = project.color.replaceFirst('#', '');
              final color = (hex.length == 6 || hex.length == 8)
                  ? int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16)
                  : null;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.folder_outlined,
                        color: color == null
                            ? Theme.of(context).colorScheme.primary
                            : Color(color),
                      ),
                      title: Text(
                        project.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'Выполнено ${item.completedTasks} из ${item.totalTasks} задач',
                      ),
                      onTap: widget.onOpenProject == null
                          ? null
                          : () => widget.onOpenProject!(project),
                    ),
                    LinearProgressIndicator(
                      value: item.progress,
                      semanticsLabel: 'Прогресс проекта ${project.name}',
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
      return PluginPanelSurface(
        title: 'Проекты',
        controls: Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Все активные'),
              selected: !widget.viewModel.onlyForDate,
              onSelected: (_) => widget.viewModel.setOnlyForDate(false),
            ),
            ChoiceChip(
              label: const Text('На этот день'),
              selected: widget.viewModel.onlyForDate,
              onSelected: (_) => widget.viewModel.setOnlyForDate(true),
            ),
          ],
        ),
        child: body,
      );
    },
  );
}

class ProjectsPanelModule implements AppPlugin {
  ProjectsPanelModule({
    required this.id,
    required String slot,
    required PluginUiRegistry ui,
    required this._projects,
    required this._tasks,
    required this._date,
    Set<String> dependencies = const {},
  }) {
    _registration = UiPluginRegistration(
      plugin: _ProjectsPanelLifecycle(this, Set.unmodifiable(dependencies)),
      registry: ui,
      panels: [
        PluginPanelContribution(
          id: id,
          slot: slot,
          builder: (_, panel) => ProjectsPanel(
            viewModel: viewModel,
            onOpenProject: (_) {
              if (panel.isActive) panel.screen?.openScreen('projects');
            },
          ),
        ),
      ],
    );
  }
  @override
  final String id;
  final ProjectsQueries _projects;
  final TaskQueries _tasks;
  final ValueListenable<DateTime> Function() _date;
  ValueListenable<DateTime>? _dates;
  ProjectsPanelModel? _model;
  ProjectsPanelModel get viewModel =>
      _model ?? (throw StateError('Projects panel is not active.'));
  late final UiPluginRegistration _registration;
  void _onDate() => _model?.selectDate(_dates!.value);
  @override
  Set<String> get dependencies => _registration.dependencies;
  @override
  Future<void> start() => _registration.start();
  @override
  Future<void> stop() => _registration.stop();
}

class _ProjectsPanelLifecycle implements AppPlugin {
  _ProjectsPanelLifecycle(this.module, this.dependencies);
  final ProjectsPanelModule module;
  @override
  String get id => module.id;
  @override
  final Set<String> dependencies;
  @override
  Future<void> start() async {
    if (module._model != null) return;
    module._dates = module._date();
    final model = ProjectsPanelModel(
      projects: module._projects,
      tasks: module._tasks,
      date: module._dates!.value,
    );
    module._model = model;
    model.initialize();
    module._dates!.addListener(module._onDate);
  }

  @override
  Future<void> stop() async {
    module._dates?.removeListener(module._onDate);
    module._dates = null;
    final model = module._model;
    module._model = null;
    await model?.dispose();
  }
}
