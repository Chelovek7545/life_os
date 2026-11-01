import 'dart:async';
import 'package:notes_api/notes_api.dart';
import 'settings_service.dart';

class AppVaultSettings implements VaultSettings {
  @override
  String get vaultPath => SettingsService.obsidianVaultPath.value;
  @override
  Stream<String> watchVaultPath() => Stream.multi((listener) {
    void changed() => listener.add(vaultPath);
    SettingsService.obsidianVaultPath.addListener(changed);
    listener.onCancel = () =>
        SettingsService.obsidianVaultPath.removeListener(changed);
  }, isBroadcast: true);
}
