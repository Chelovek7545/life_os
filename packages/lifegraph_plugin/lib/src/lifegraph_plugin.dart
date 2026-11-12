import 'package:flutter/material.dart';
import 'package:graph_api/graph_api.dart';
import 'package:graph_ui/graph_ui.dart';
import 'package:notes_api/notes_api.dart';
import 'package:spheres_api/spheres_api.dart';
import 'package:goals_api/goals_api.dart';
import 'package:projects_api/projects_api.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'graph_builder.dart';
import 'pulse_screen_view_model.dart';
import '../graph_storage_settings.dart';
import 'dart:async';

abstract final class PulsePanelSlots {
  static const center = 'pulse.center';
  static const toolbar = 'pulse.toolbar';
  static const overlay = 'pulse.overlay';
}

typedef PulseScreenBuilder =
    Widget Function(
      BuildContext context,
      PulseScreenViewModel model,
      PluginUiRegistry registry,
      void Function(Task) openTask,
      Future<void> Function(Task) completeTask,
    );

typedef GraphStorageSettingsBuilder =
    Widget Function(BuildContext context, bool Function() isActive);

class LifeGraphPlugin {
  LifeGraphPlugin({
    required this._spheres,
    required this._goals,
    required this._projects,
    required this._tasks,
    required this._positions,
    required this._notes,
    required this._contributors,
    required this._presentations,
    required this._editors,
    required this._commands,
    required PluginUiRegistry ui,
    required PulseScreenBuilder screen,
    required Future<void> Function(Task) completeTask,
    this._vault,
    this.rootKind = 'sphere',
    Set<String> dependencies = const {},
    this.storageSettings,
    GraphStorageSettingsBuilder? storageSettingsBuilder,
  }) : _ui = ui {
    plugins = List.unmodifiable([
      UiPluginRegistration(
        plugin: _LifeGraphLifecycle(this, Set.unmodifiable(dependencies)),
        registry: ui,
        settings: [
          if (storageSettingsBuilder != null)
            PluginSettingsContribution(
              id: 'lifegraph.storage.settings',
              title: 'Граф',
              builder: (context) {
                final model = _model;
                return storageSettingsBuilder(
                  context,
                  () => model != null && identical(model, _model),
                );
              },
            ),
        ],
        screens: [
          PluginScreenContribution(
            id: 'pulse',
            label: 'PULSE',
            icon: Icons.bolt_rounded,
            ownsAppBar: true,
            builder: (context, controls) => screen(
              context,
              viewModel,
              ui,
              (task) {
                if (!controls.isActive) return;
                if (!controls.openScreen(
                  'tasks',
                  argument: task,
                  select: false,
                )) {
                  ui.notify(const PluginNotice('Экран задач недоступен.'));
                }
              },
              (task) async {
                if (!controls.isActive) return;
                try {
                  await completeTask(task);
                } catch (_) {
                  if (controls.isActive) {
                    ui.notify(
                      const PluginNotice(
                        'Не удалось обновить задачу.',
                        isError: true,
                      ),
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    ]);
  }
  final SpheresApi _spheres;
  final GoalsQueries _goals;
  final ProjectsQueries _projects;
  final TaskQueries _tasks;
  final GraphPositionsStore _positions;
  final CanvasNotesStore _notes;
  final GraphContributorRegistry _contributors;
  final GraphNodePresentationRegistry _presentations;
  final GraphEditorRegistry _editors;
  final GraphCommandRegistry _commands;
  final VaultNotesApi? _vault;
  final String rootKind;
  final GraphStorageSettings? storageSettings;
  final PluginUiRegistry _ui;
  late final List<AppPlugin> plugins;
  PulseScreenViewModel? _model;
  GraphBuilder? _builder;
  PulseScreenViewModel get viewModel =>
      _model ?? (throw StateError('LifeGraph module is not active.'));
  GraphBuilder get graphBuilder =>
      _builder ?? (throw StateError('LifeGraph module is not active.'));
}

class _LifeGraphLifecycle implements AppPlugin {
  _LifeGraphLifecycle(this.module, this.dependencies);
  final LifeGraphPlugin module;
  StreamSubscription<VaultFolders>? _folderSubscription;
  int _settingsGeneration = 0;
  @override
  String get id => 'lifegraph.screen';
  @override
  final Set<String> dependencies;
  @override
  Future<void> start() async {
    if (module._model != null) return;
    final generation = ++_settingsGeneration;
    final settings = module.storageSettings;
    final storage = module._vault;
    if (settings != null && storage is CanvasStorageFoldersApi) {
      final folders = storage as CanvasStorageFoldersApi;
      await folders.configureFolders(settings.folders, copyBoards: false);
      _folderSubscription = settings.watchFolders().listen((value) {
        unawaited(
          Future<void>.sync(() async {
            if (generation != _settingsGeneration) return;
            await folders.configureFolders(value);
          }).catchError((Object error) {
            if (generation == _settingsGeneration) {
              module._ui.notify(
                PluginNotice(
                  'Не удалось применить папки графа: $error',
                  isError: true,
                ),
              );
            }
          }),
        );
      });
    }
    final builder = GraphBuilder(
      registry: module._contributors,
      rootKind: module.rootKind,
    );
    module._builder = builder;
    final model = PulseScreenViewModel(
      spheresRepository: module._spheres,
      goalsRepository: module._goals,
      projectsRepository: module._projects,
      tasksRepository: module._tasks,
      positionsRepository: module._positions,
      notesRepository: module._notes,
      graphBuilder: builder,
      nodePresentations: module._presentations,
      nodeEditors: module._editors,
      commands: module._commands,
      obsidianRepository: module._vault,
    );
    module._model = model;
    await model.initialize();
  }

  @override
  Future<void> stop() async {
    _settingsGeneration++;
    await _folderSubscription?.cancel();
    _folderSubscription = null;
    final model = module._model;
    final builder = module._builder;
    module._model = null;
    module._builder = null;
    try {
      await model?.dispose();
    } finally {
      await builder?.dispose();
    }
  }
}
