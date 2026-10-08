import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _blurKey = 'has_blur_enabled';
  static const String _obsidianPathKey = 'obsidian_vault_path';
  static const String _tgTokenKey = 'tg_token';
  
  static final ValueNotifier<bool> hasBlur = ValueNotifier<bool>(true);
  static final ValueNotifier<String> obsidianVaultPath = ValueNotifier<String>('');
  static final ValueNotifier<String> tgToken = ValueNotifier<String>('');

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    hasBlur.value = prefs.getBool(_blurKey) ?? true;
    obsidianVaultPath.value = prefs.getString(_obsidianPathKey) ?? '';
    tgToken.value = prefs.getString(_tgTokenKey) ?? '';
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

  static Future<void> setTgToken(String token) async {
    tgToken.value = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tgTokenKey, token);
  }

  
}