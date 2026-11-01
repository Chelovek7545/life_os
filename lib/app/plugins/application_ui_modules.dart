import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';

AppPlugin registerUiModule(UiModuleSpec module, PluginUiRegistry registry) =>
    UiPluginRegistration(
      plugin: UiModule(id: module.id, dependencies: module.dependencies),
      registry: registry,
      screens: module.screens,
      panels: module.panels,
      actions: module.actions,
      settings: module.settings,
    );
