import 'package:lifegraph_plugin/graph_storage_settings.dart';
import 'package:notes_api/notes_api.dart';
import 'package:life_os/features/settings/settings_service.dart';

class AppGraphStorageSettings implements GraphStorageSettings {
  @override
  VaultFolders get folders => SettingsService.graphFolders.value;
  @override
  Stream<VaultFolders> watchFolders() => Stream.multi((listener) {
    void changed() => listener.add(folders);
    SettingsService.graphFolders.addListener(changed);
    listener.onCancel = () =>
        SettingsService.graphFolders.removeListener(changed);
  }, isBroadcast: true);
}
