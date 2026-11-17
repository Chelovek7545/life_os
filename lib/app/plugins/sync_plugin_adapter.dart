import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:life_os/features/sync/presentation/sync_settings_panel.dart';

AppPlugin registerSyncUi(
  AppPlugin plugin,
  LocalSyncControl control,
  PluginUiRegistry ui,
) => UiPluginRegistration(
  plugin: plugin,
  registry: ui,
  settings: [
    PluginSettingsContribution(
      id: 'sync.local.settings',
      title: 'Локальная синхронизация',
      builder: (_) => SyncSettingsPanel(control: control),
    ),
  ],
);
