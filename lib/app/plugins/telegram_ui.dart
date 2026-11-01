import 'package:flutter/material.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:telegram_plugin/telegram_plugin.dart';
import 'package:life_os/core/ui/telegram_bot_toggle_button.dart';
import 'package:life_os/features/settings/settings_service.dart';

AppPlugin registerTelegramUi(
  LocalBotService service,
  PluginUiRegistry registry,
) {
  final plugin = _TelegramAppPlugin(service, registry);
  return UiPluginRegistration(
    plugin: plugin,
    registry: registry,
    actions: [
      PluginActionContribution(
        id: 'telegram.toggle',
        locations: {
          PluginActionLocation.appBar,
          PluginActionLocation.navigationRail,
        },
        builder: (_, compact) => TelegramBotToggleButton(
          isRunning: service.isRunning,
          compact: compact,
          onPressed: plugin.toggle,
        ),
      ),
    ],
    settings: [
      PluginSettingsContribution(
        id: 'telegram.settings',
        title: 'Telegram',
        builder: (_) => Column(
          children: [
            PluginTextSetting(
              value: SettingsService.tgToken,
              title: 'Ключ Telegram-бота',
              icon: Icons.key_outlined,
              obscure: true,
              save: SettingsService.setTgToken,
            ),
            PluginTextSetting(
              value: SettingsService.tgAllowedUsers,
              title: 'Разрешённые Telegram User ID',
              icon: Icons.lock_outline,
              emptyLabel: 'Не указаны — бот не запустится',
              save: SettingsService.setTgAllowedUsers,
              validate: (text) {
                if (text.isEmpty) return null;
                final values = text.split(RegExp(r'[,;\s]+'));
                if (values.any((value) => (int.tryParse(value) ?? 0) <= 0)) {
                  return 'Введите числовые User ID через запятую.';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    ],
  );
}

class _TelegramAppPlugin extends TelegramPlugin {
  _TelegramAppPlugin(super.service, this.registry);
  final PluginUiRegistry registry;
  bool _switching = false;
  @override
  Future<void> start() async {
    service.onTokenRequested = () async {
      registry.notify(const PluginNotice('Добавьте токен в настройках'));
      return null;
    };
    service.onInvalidToken = (message) =>
        registry.notify(PluginNotice(message, isError: true));
    service.onPollingError = (message) =>
        registry.notify(PluginNotice(message, isError: true));
    await super.start();
  }

  Future<void> toggle() async {
    if (_switching) return;
    _switching = true;
    try {
      if (service.isRunning.value) {
        await service.stopBot();
      } else {
        await service.startBot();
      }
    } catch (error) {
      registry.notify(
        PluginNotice(
          'Не удалось переключить Telegram-бота: ' + error.toString(),
          isError: true,
        ),
      );
    } finally {
      _switching = false;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await super.stop();
    } finally {
      service.onTokenRequested = null;
      service.onInvalidToken = null;
      service.onPollingError = null;
    }
  }
}
