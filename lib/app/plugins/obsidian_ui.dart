import 'package:flutter/material.dart';
import 'package:notes_api/notes_api.dart';
import 'package:obsidian_plugin/obsidian_plugin.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:life_os/features/settings/settings_service.dart';

AppPlugin registerObsidianUi(
  ObsidianVault vault,
  VaultSettings settings,
  PluginUiRegistry registry,
) => UiPluginRegistration(
  plugin: ObsidianPlugin(vault: vault, settings: settings),
  registry: registry,
  settings: [
    PluginSettingsContribution(
      id: 'obsidian.settings',
      title: 'Obsidian Integration',
      builder: (_) => PluginTextSetting(
        value: SettingsService.obsidianVaultPath,
        title: 'Путь к хранилищу Obsidian (Vault)',
        icon: Icons.folder_open_outlined,
        save: SettingsService.setObsidianVaultPath,
      ),
    ),
  ],
);
