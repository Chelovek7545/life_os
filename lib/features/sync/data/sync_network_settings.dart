import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sync_plugin/sync_logic.dart';

class AppSyncNetworkSettings implements SyncNetworkSettings {
  const AppSyncNetworkSettings();

  static const _key = 'sync.local.network';

  @override
  Future<SyncNetworkPreference> read() async {
    final preferences = await SharedPreferences.getInstance();
    final text = preferences.getString(_key);
    if (text == null) return (address: null, listening: false);
    final data = jsonDecode(text) as Map<String, dynamic>;
    return (
      address: data['address'] as String?,
      listening: data['listening'] == true,
    );
  }

  @override
  Future<void> write(SyncNetworkPreference preference) async {
    final preferences = await SharedPreferences.getInstance();
    if (!await preferences.setString(
      _key,
      jsonEncode({
        'address': preference.address,
        'listening': preference.listening,
      }),
    )) {
      throw const LocalSyncException('Не удалось сохранить настройки приёма.');
    }
  }
}
