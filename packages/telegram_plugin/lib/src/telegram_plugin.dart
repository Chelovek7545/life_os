import 'package:plugin_runtime/plugin_runtime.dart';
import 'local_bot_service.dart';

class TelegramPlugin implements AppPlugin {
  TelegramPlugin(this.service);
  final LocalBotService service;
  @override
  String get id => 'telegram';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    // Polling remains an explicit user action.
  }
  @override
  Future<void> stop() => service.stopBot();
}
