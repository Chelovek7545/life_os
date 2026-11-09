class AssistantSettings {
  const AssistantSettings({
    this.pythonExecutable = '.venv-openvino/Scripts/python.exe',
    this.modelDirectory = 'models/Qwen2.5-1.5B-Instruct-int4-ov',
    this.device = 'NPU',
  });
  final String pythonExecutable;
  final String modelDirectory;
  final String device;
  Map<String, Object?> toJson() => {
    'python': pythonExecutable,
    'model': modelDirectory,
    'device': device,
  };
  factory AssistantSettings.fromJson(Map<String, dynamic> value) =>
      AssistantSettings(
        pythonExecutable: value['python'] is String
            ? value['python'] as String
            : const AssistantSettings().pythonExecutable,
        modelDirectory: value['model'] is String
            ? value['model'] as String
            : const AssistantSettings().modelDirectory,
        device: const ['NPU', 'GPU', 'CPU'].contains(value['device'])
            ? value['device'] as String
            : 'NPU',
      );
  bool get isValid =>
      pythonExecutable.trim().isNotEmpty &&
      modelDirectory.trim().isNotEmpty &&
      const ['NPU', 'GPU', 'CPU'].contains(device);
}

class AssistantFailure implements Exception {
  const AssistantFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

class AssistantBackendInfo {
  const AssistantBackendInfo({required this.device, required this.model});
  final String device;
  final String model;
}

abstract interface class AssistantBackend {
  Future<AssistantBackendInfo> start();
  Future<String> generate(
    List<Map<String, String>> messages, {
    required int turnStart,
  });
  Future<void> close();
}

typedef AssistantBackendFactory =
    Future<AssistantBackend> Function(AssistantSettings settings);
typedef AssistantSettingsWriter =
    Future<void> Function(AssistantSettings settings);

enum AssistantMessageKind { user, assistant, action, error }

class AssistantMessage {
  const AssistantMessage(this.kind, this.text);
  final AssistantMessageKind kind;
  final String text;
}

enum AssistantPhase { idle, loading, thinking, acting, configuring }

class AssistantState {
  AssistantState({
    required this.settings,
    required List<AssistantMessage> messages,
    this.phase = AssistantPhase.idle,
    this.backendInfo,
  }) : messages = List.unmodifiable(messages);
  final AssistantSettings settings;
  final List<AssistantMessage> messages;
  final AssistantPhase phase;
  final AssistantBackendInfo? backendInfo;
  bool get busy => phase != AssistantPhase.idle;
}
