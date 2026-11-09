import 'assistant_models.dart';

class OpenVinoProcessBackend implements AssistantBackend {
  OpenVinoProcessBackend({
    required AssistantSettings settings,
    required String workerSource,
    Duration startupTimeout = const Duration(minutes: 10),
    Duration replyTimeout = const Duration(minutes: 3),
  });
  @override
  Future<AssistantBackendInfo> start() async => throw const AssistantFailure(
    'Локальная модель доступна в настольной сборке.',
  );
  @override
  Future<String> generate(
    List<Map<String, String>> messages, {
    required int turnStart,
  }) async => throw const AssistantFailure(
    'Локальная модель доступна в настольной сборке.',
  );
  @override
  Future<void> close() async {}
}
