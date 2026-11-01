import 'package:flutter/material.dart';
import 'package:notes_api/notes_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'resources_view_model.dart';

class ResourcesPlugin {
  ResourcesPlugin({
    required this._notes,
    required PluginUiRegistry ui,
    required Widget Function(BuildContext, ResourcesViewModel) screen,
    this._vault,
    Set<String> dependencies = const {},
  }) {
    plugins = List.unmodifiable([
      UiPluginRegistration(
        plugin: _ResourcesLifecycle(this, Set.unmodifiable(dependencies)),
        registry: ui,
        screens: [
          PluginScreenContribution(
            id: 'resources',
            label: 'LIBRARY',
            icon: Icons.menu_book_rounded,
            order: 30,
            builder: (context, _) => screen(context, viewModel),
          ),
        ],
      ),
    ]);
  }
  final NotesCatalog _notes;
  final VaultNotesApi? _vault;
  late final List<AppPlugin> plugins;
  ResourcesViewModel? _model;
  ResourcesViewModel get viewModel =>
      _model ?? (throw StateError('Resources module is not active.'));
}

class _ResourcesLifecycle implements AppPlugin {
  _ResourcesLifecycle(this.module, this.dependencies);
  final ResourcesPlugin module;
  @override
  String get id => 'resources.screen';
  @override
  final Set<String> dependencies;
  @override
  Future<void> start() async {
    if (module._model != null) return;
    final model = ResourcesViewModel(
      notes: module._notes,
      vault: module._vault,
      autoInitialize: false,
    );
    module._model = model;
    model.initialize();
  }

  @override
  Future<void> stop() async {
    final model = module._model;
    module._model = null;
    await model?.close();
  }
}
