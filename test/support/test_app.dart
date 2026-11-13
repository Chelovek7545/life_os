import 'package:graph_ui/graph_ui.dart';
import 'package:agent_bridge/agent_bridge.dart';
import 'package:agent_bridge/local_assistant.dart';
import 'package:plugin_ui/plugin_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:life_os/core/database/database.dart';
import 'package:life_os/app/dependency_container.dart';
import 'package:plugin_runtime/plugin_runtime.dart';
import 'package:life_os/app/plugins/today_plugin_adapter.dart';
import 'package:life_os/app/plugins/planner_plugin_adapter.dart';

Future<DependencyContainer> createTestApp({
  bool enableTelegram = false,
  bool enableObsidian = true,
  bool enableMcp = false,
  bool enableAssistant = false,
  bool includePlanningScreens = false,
  AssistantBackendFactory? assistantBackendFactory,
  McpServerOptions? mcpOptions,
  Iterable<GraphModule> graphModules = const [],
  Iterable<UiModuleSpec> uiModules = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  late final DependencyContainer container;
  container = DependencyContainer(
    database: AppDatabase(NativeDatabase.memory()),
    enableTelegram: enableTelegram,
    enableObsidian: enableObsidian,
    enableMcp: enableMcp,
    enableAssistant: enableAssistant,
    assistantBackendFactory: assistantBackendFactory,
    mcpOptions: mcpOptions,
    graphModules: graphModules,
    uiModules: uiModules,
    additionalPlugins: [
      if (includePlanningScreens) _PlanningScreens(() => container),
    ],
  );
  await container.init();
  return container;
}

// Historical composition fixtures are explicitly installed for their tests;
// the production container does not register or start these screens.
class _PlanningScreens implements AppPlugin {
  _PlanningScreens(this.container);
  final DependencyContainer Function() container;
  PluginHost? _host;
  @override
  String get id => 'test.planning-screens';
  @override
  Set<String> get dependencies => const {};
  @override
  Future<void> start() async {
    final app = container();
    _host = PluginHost([
      ...createTodayPlugin(
        ui: app.ui,
        tasks: app.tasksRepository,
        habits: app.habitsRepository,
        projects: app.projectsRepository,
      ).plugins,
      createPlannerPlugin(
        ui: app.ui,
        tasks: app.tasksRepository,
        projects: app.projectsRepository,
        habits: app.habitsRepository,
      ),
    ]);
    await _host!.start();
  }

  @override
  Future<void> stop() async {
    final host = _host;
    _host = null;
    await host?.stop();
  }
}

Future<void> disposeTestApp(
  WidgetTester tester,
  DependencyContainer container,
) async {
  await tester.pumpWidget(const SizedBox());
  var closed = false;
  final closing = container.dispose().then((_) {
    closed = true;
  });
  for (var i = 0; i < 100 && !closed; i++) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(closed, isTrue, reason: 'All app resources must finish closing.');
  await closing;
}
