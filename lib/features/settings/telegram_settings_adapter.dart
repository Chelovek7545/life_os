import 'package:telegram_plugin/telegram_plugin.dart';
import 'settings_service.dart';

class AppTelegramSettings implements TelegramSettings {
  @override
  String get token => SettingsService.tgToken.value;
  @override
  String get allowedUsers => SettingsService.tgAllowedUsers.value;
  @override
  Future<void> saveToken(String token) => SettingsService.setTgToken(token);
}
