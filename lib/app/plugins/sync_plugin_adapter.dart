import 'package:lifegraph_plugin/lifegraph_plugin.dart' show PulsePanelSlots;
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:sync_plugin/sync_logic.dart';
import 'package:life_os/features/sync/presentation/sync_completion_notice.dart';
import 'package:life_os/features/sync/presentation/sync_quick_action.dart';
import 'package:life_os/features/sync/presentation/sync_settings_panel.dart';

AppPlugin registerSyncUi(
  AppPlugin plugin,
  LocalSyncControl control,
  PluginUiRegistry ui,
) {
  var openPanels = 0;
  void changeVisibility(bool open) => openPanels += open ? 1 : -1;
  return UiPluginRegistration(
    plugin: plugin,
    registry: ui,
    panels: [
      PluginPanelContribution(
        id: 'sync.local.quick',
        slot: PulsePanelSlots.toolbar,
        builder: (_, _) => SyncQuickAction(
          control: control,
          onVisibilityChanged: changeVisibility,
        ),
      ),
      PluginPanelContribution(
        id: 'sync.local.completion',
        slot: 'app.overlays',
        builder: (_, _) => SyncCompletionNotice(
          control: control,
          isPanelOpen: () => openPanels > 0,
        ),
      ),
    ],
    settings: [
      PluginSettingsContribution(
        id: 'sync.local.settings',
        title: 'Локальная синхронизация',
        builder: (_) => SyncSettingsPanel(
          control: control,
          onVisibilityChanged: changeVisibility,
        ),
      ),
    ],
  );
}
