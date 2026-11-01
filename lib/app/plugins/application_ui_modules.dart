import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/resources/presentation/resources_screen_module.dart';
import 'package:life_os/features/resources/presentation/resources_view_model.dart';
import 'package:life_os/features/lifegraph/presentation/pulse_screen_module.dart';
import 'package:life_os/features/lifegraph/presentation/pulse_screen_view_model.dart';

AppPlugin registerUiModule(UiModuleSpec module, PluginUiRegistry registry) =>
    UiPluginRegistration(
      plugin: UiModule(id: module.id, dependencies: module.dependencies),
      registry: registry,
      screens: module.screens,
      panels: module.panels,
      actions: module.actions,
      settings: module.settings,
    );

List<AppPlugin> applicationUiModules({
  required PluginUiRegistry registry,
  required PulseScreenViewModel pulse,
  required Future<void> Function(Task) completeTask,
  required ResourcesViewModel resources,
}) => [
  for (final module in [
    pulseScreenModule(pulse, registry, completeTask),
    resourcesScreenModule(resources),
  ])
    registerUiModule(module, registry),
];
