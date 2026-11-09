import 'dart:convert';
import 'package:agent_bridge/agent_bridge.dart' show TaskAgentTools;
import 'package:agent_bridge/local_assistant.dart';
import 'package:flutter/services.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tasks_api/tasks_api.dart';
import 'package:life_os/features/assistant/presentation/assistant_overlay.dart';

class AssistantPlugin implements AppPlugin {
  AssistantPlugin({
    required this.ui,
    required this.tasks,
    required this.completion,
    AssistantBackendFactory? backendFactory,
  }) : backendFactory = backendFactory ?? _defaultBackend;
  final PluginUiRegistry ui;
  final TasksApi tasks;
  final TaskCompletionCommands completion;
  final AssistantBackendFactory backendFactory;
  AssistantController? _controller;
  AssistantController? get controller => _controller;
  static const settingsKey = 'assistant.openvino.v1';
  @override
  String get id => 'assistant.chat';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    if (_controller != null) return;
    final preferences = await SharedPreferences.getInstance();
    var settings = const AssistantSettings();
    final stored = preferences.getString(settingsKey);
    if (stored != null) {
      try {
        settings = AssistantSettings.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    final controller = AssistantController(
      tools: TaskAgentTools(tasks: tasks, completion: completion),
      backendFactory: backendFactory,
      settings: settings,
      saveSettings: (value) async {
        if (!await preferences.setString(
          settingsKey,
          jsonEncode(value.toJson()),
        )) {
          throw StateError('Assistant settings were not saved.');
        }
      },
    );
    _controller = controller;
    ui.register(
      id,
      panels: [
        PluginPanelContribution(
          id: 'assistant.chat.overlay',
          slot: 'app.overlays',
          order: 20,
          builder: (_, panel) => AssistantOverlay(controller: controller),
        ),
      ],
    );
  }

  @override
  Future<void> stop() async {
    ui.unregister(id);
    final controller = _controller;
    _controller = null;
    await controller?.close();
  }
}

Future<AssistantBackend> _defaultBackend(AssistantSettings settings) async =>
    OpenVinoProcessBackend(
      settings: settings,
      workerSource: await rootBundle.loadString('tool/openvino/worker.py'),
    );
