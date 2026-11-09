import 'dart:async';
import 'package:agent_bridge/local_assistant.dart';

class FakeAssistantBackend implements AssistantBackend {
  FakeAssistantBackend({this.reply, this.onClose});
  final FutureOr<String> Function(List<Map<String, String>>, int)? reply;
  final FutureOr<void> Function()? onClose;
  final prompts = <List<Map<String, String>>>[];
  int starts = 0;
  int closes = 0;
  @override
  Future<AssistantBackendInfo> start() async {
    starts++;
    return const AssistantBackendInfo(device: 'NPU', model: 'test-model');
  }

  @override
  Future<String> generate(
    List<Map<String, String>> messages, {
    required int turnStart,
  }) async {
    prompts.add(messages.map(Map<String, String>.of).toList());
    return await reply?.call(messages, turnStart) ??
        '{"type":"message","text":"Локальный ответ"}';
  }

  @override
  Future<void> close() async {
    closes++;
    await onClose?.call();
  }
}
