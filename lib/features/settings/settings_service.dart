import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:notes_api/notes_api.dart';
import 'package:lifegraph_plugin/graph_storage_settings.dart';

class SettingsService {
  static const String _blurKey = 'has_blur_enabled';
  static const String _obsidianPathKey = 'obsidian_vault_path';
  static const String _graphFoldersKey = 'graph_storage_folders_v1';
  static const String _graphTargetKey = 'graph_storage_target_v1';
  static final ValueNotifier<GraphStorageTarget> graphStorageTarget =
      ValueNotifier(const GraphStorageTarget());
  static final ValueNotifier<VaultFolders> graphFolders = ValueNotifier(
    const VaultFolders(),
  );
  static const String _tgTokenKey = 'tg_token';
  static const String _tgAllowedUsersKey = 'tg_allowed_users';

  static final ValueNotifier<bool> hasBlur = ValueNotifier<bool>(true);
  static final ValueNotifier<String> obsidianVaultPath = ValueNotifier<String>(
    '',
  );
  static final ValueNotifier<String> tgToken = ValueNotifier<String>('');
  static final ValueNotifier<String> tgAllowedUsers = ValueNotifier<String>('');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hasBlur.value = prefs.getBool(_blurKey) ?? true;
    obsidianVaultPath.value = prefs.getString(_obsidianPathKey) ?? '';
    final folders =
        prefs.getString(_graphFoldersKey) ??
        prefs.getString('obsidian_folders_v1');
    graphFolders.value = folders == null
        ? const VaultFolders()
        : VaultFolders.fromJson(jsonDecode(folders) as Map<String, dynamic>);
    final target = prefs.getString(_graphTargetKey);
    graphStorageTarget.value = target == null
        ? const GraphStorageTarget()
        : GraphStorageTarget.fromJson(
            jsonDecode(target) as Map<String, dynamic>,
          );
    tgToken.value = prefs.getString(_tgTokenKey) ?? '';
    tgAllowedUsers.value = prefs.getString(_tgAllowedUsersKey) ?? '';
  }

  static Future<void> setHasBlur(bool value) async {
    hasBlur.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blurKey, value);
  }

  static Future<void> setObsidianVaultPath(String path) async {
    obsidianVaultPath.value = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_obsidianPathKey, path);
  }

  static Future<void> setGraphFolders(VaultFolders value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_graphFoldersKey, jsonEncode(value.toJson()))) {
      throw StateError('Не удалось сохранить папки графа.');
    }
    graphFolders.value = value;
  }

  static Future<void> setGraphStorageTarget(GraphStorageTarget target) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_graphTargetKey, jsonEncode(target.toJson()))) {
      throw StateError('Не удалось сохранить режим хранения графа.');
    }
    graphStorageTarget.value = target;
  }

  static Future<void> setTgToken(String token) async {
    tgToken.value = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tgTokenKey, token);
  }

  static Future<void> setTgAllowedUsers(String ids) async {
    tgAllowedUsers.value = ids;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tgAllowedUsersKey, ids);
  }
}
