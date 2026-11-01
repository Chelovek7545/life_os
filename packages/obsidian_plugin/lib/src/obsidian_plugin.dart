import 'dart:async';
import 'package:notes_api/notes_api.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'obsidian_vault.dart';

class ObsidianPlugin implements AppPlugin {
  ObsidianPlugin({required this.vault, required this.settings});
  final ObsidianVault vault;
  final VaultSettings settings;
  StreamSubscription<String>? _settingsSubscription;
  @override
  String get id => 'obsidian';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    _settingsSubscription ??= settings.watchVaultPath().distinct().listen((
      path,
    ) {
      // Scan failures are published through VaultState.error.
      unawaited(vault.openVault(path));
    });
    await vault.openVault(settings.vaultPath);
  }

  @override
  Future<void> stop() async {
    await _settingsSubscription?.cancel();
    _settingsSubscription = null;
    await vault.stop();
  }
}
