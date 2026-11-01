import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pure packages and Telegram cannot depend on app internals', () {
    const forbidden = {
      'graph_canvas': [
        'dart:io',
        'package:life_os/',
        'package:drift/',
        'package:tasks_api/',
        'package:projects_api/',
        'package:lifegraph_plugin/',
      ],
      'lifegraph_plugin': [
        'dart:io',
        'package:life_os/',
        'package:drift/',
        'package:tasks_plugin/',
        'package:projects_plugin/',
        'package:habits_plugin/',
        'package:obsidian_plugin/',
        'package:resources_plugin/',
      ],
      'resources_plugin': [
        'dart:io',
        'package:life_os/',
        'package:drift/',
        'package:lifegraph_plugin/',
        'package:obsidian_plugin/',
        'package:tasks_plugin/',
        'package:projects_plugin/',
        'package:graph_canvas/',
      ],
      'core_contracts': [
        'dart:io',
        'dart:ui',
        'package:flutter/',
        'package:life_os/',
        'package:drift/',
        'package:tasks_api/',
        'package:projects_api/',
      ],
      'habits_api': [
        'dart:io',
        'dart:ui',
        'package:flutter/',
        'package:life_os/',
        'package:drift/',
        'package:habits_plugin/',
        'package:tasks_api/',
        'package:plugin_ui/',
      ],
      'habits_plugin': [
        'dart:io',
        'package:life_os/',
        'package:drift/',
        'package:projects_plugin/',
        'package:obsidian_plugin/',
        'package:telegram_plugin/',
      ],
      'projects_api': [
        'dart:io',
        'dart:ui',
        'package:flutter/',
        'package:life_os/',
        'package:drift/',
        'package:tasks_api/',
        'package:projects_plugin/',
        'package:graph_api/',
      ],
      'projects_plugin': [
        'dart:io',
        'package:life_os/',
        'package:drift/',
        'package:obsidian_plugin/',
        'package:telegram_plugin/',
      ],
      'spheres_api': [
        'dart:ui',
        'package:flutter/',
        'package:drift/',
        'package:life_os/',
        'package:graph_ui/',
      ],
      'goals_api': [
        'dart:ui',
        'package:flutter/',
        'package:drift/',
        'package:life_os/',
        'package:graph_ui/',
      ],
      'graph_api': [
        'package:lifegraph_plugin/',
        'dart:ui',
        'package:flutter/',
        'package:drift/',
        'package:life_os/',
        'package:tasks_api/',
        'package:spheres_api/',
        'package:goals_api/',
        'package:graph_ui/',
      ],
      'graph_ui': [
        'package:life_os/',
        'package:tasks_api/',
        'package:spheres_api/',
        'package:goals_api/',
      ],
      'notes_api': [
        'package:lifegraph_plugin/',
        'package:graph_canvas/',
        'dart:io',
        'dart:ui',
        'package:flutter/',
        'package:life_os/',
        'package:obsidian_plugin/',
      ],
      'obsidian_plugin': [
        'dart:ui',
        'package:flutter/',
        'package:life_os/',
        'package:drift/',
        'package:plugin_ui/',
      ],
      'plugin_ui': [
        'package:lifegraph_plugin/',
        'package:resources_plugin/',
        'package:tasks_plugin/',
        'package:habits_api/',
        'package:habits_plugin/',
        'package:life_os/',
        'package:tasks_api/',
        'package:notes_api/',
        'package:telegram_plugin/',
        'package:obsidian_plugin/',
      ],
      'tasks_plugin': [
        'dart:io',
        'package:life_os/',
        'package:drift/',
        'package:projects_plugin/',
        'package:habits_plugin/',
        'package:telegram_plugin/',
      ],
      'tasks_api': [
        'package:tasks_plugin/',
        'package:flutter/',
        'dart:ui',
        'package:drift/',
        'package:life_os/',
        'package:telegram_plugin/',
      ],
      'plugin_runtime': [
        'package:flutter/',
        'dart:ui',
        'package:drift/',
        'package:life_os/',
        'package:tasks_api/',
        'package:telegram_plugin/',
      ],
      'telegram_plugin': ['package:life_os/', 'package:drift/'],
    };
    for (final entry in forbidden.entries) {
      for (final file in Directory(
        'packages/' + entry.key + '/lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final source = file.readAsStringSync();
        for (final import in entry.value) {
          expect(
            source.contains(import),
            isFalse,
            reason: file.path + ' must not import ' + import,
          );
        }
      }
    }
  });
  test(
    'shell and note persistence do not depend on concrete plugins or rendering',
    () {
      final shell = File('lib/main_screen.dart').readAsStringSync();
      expect(shell.contains('Telegram'), isFalse);
      expect(shell.contains('localBotService'), isFalse);
      final store = File(
        'lib/features/lifegraph/data/graph_notes_repository.dart',
      ).readAsStringSync();
      expect(store.contains('graph_view.dart'), isFalse);
      expect(store.contains('obsidian_repository.dart'), isFalse);
      expect(store.contains('dart:ui'), isFalse);
    },
  );
  test('graph assembly and feature contributors depend only on contracts', () {
    final builder = File(
      'packages/lifegraph_plugin/lib/src/graph_builder.dart',
    ).readAsStringSync();
    expect(builder.contains('features/tasks'), isFalse);
    expect(builder.contains('features/projects'), isFalse);
    expect(builder.contains('features/goals'), isFalse);
    expect(builder.contains('features/spheres'), isFalse);
    for (final file in [
      'lib/features/spheres/domain/spheres_graph_contributor.dart',
      'lib/features/goals/domain/goals_graph_contributor.dart',
      'lib/features/projects/domain/projects_graph_contributor.dart',
      'lib/features/tasks/domain/tasks_graph_contributor.dart',
      'lib/features/spheres/domain/spheres_graph_commands.dart',
      'lib/features/goals/domain/goals_graph_commands.dart',
      'lib/features/projects/domain/projects_graph_commands.dart',
      'lib/features/tasks/domain/tasks_graph_commands.dart',
      'packages/lifegraph_plugin/lib/src/life_graph_view_model.dart',
      'packages/lifegraph_plugin/lib/src/pulse_screen_view_model.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(
        source.contains('/data/goals_repository.dart'),
        isFalse,
        reason: file,
      );
      expect(
        source.contains('/data/spheres_repository.dart'),
        isFalse,
        reason: file,
      );
      if (file.contains('_graph_contributor') ||
          file.contains('_graph_commands')) {
        expect(source.contains('/data/'), isFalse, reason: file);
      }
    }
  });
  test('graph view model routes mutations through module commands', () {
    final source = File(
      'packages/lifegraph_plugin/lib/src/life_graph_view_model.dart',
    ).readAsStringSync();
    for (final forbidden in [
      'GoalsApi',
      'ProjectsApi',
      'TasksApi',
      'SpheresApi',
      'GraphDeletion',
      'GraphNodeType.',
      'Task.blank(',
      'Goal.create(',
      'Project.create(',
      'spheresRepository.update',
      'tasksRepository.update',
      'TaskQueries',
      'tasksStream',
      'attachExistingTask',
    ]) {
      expect(source.contains(forbidden), isFalse, reason: forbidden);
    }
    expect(source.contains('GraphCommandRegistry'), isTrue);
  });
  test(
    'graph screen obtains node forms from modules without built-in routing',
    () {
      final source = File(
        'lib/features/lifegraph/presentation/life_graph_screen.dart',
      ).readAsStringSync();
      for (final forbidden in [
        'GraphNodeType',
        'NodeEditDialog',
        'AddChildDialog',
        'ExistingTaskPickerDialog',
        'tasksStream',
        'features/tasks/',
        '.isLeaf',
        '_showAddChildDialog',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
      expect(source.contains('GraphNodeDialogs'), isTrue);
      for (final file in [
        'lib/features/spheres/presentation/spheres_graph_ui.dart',
        'lib/features/goals/presentation/goals_graph_ui.dart',
        'lib/features/projects/presentation/projects_graph_ui.dart',
        'lib/features/tasks/presentation/tasks_graph_ui.dart',
      ]) {
        final adapter = File(file).readAsStringSync();
        expect(
          adapter.contains('life_graph_view_model.dart'),
          isFalse,
          reason: file,
        );
        expect(adapter.contains('/data/'), isFalse, reason: file);
      }
    },
  );
  test(
    'features cannot resolve dependencies from the global app container',
    () {
      for (final file in Directory(
        'lib/features',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        expect(
          file.readAsStringSync().contains('core/di.dart'),
          isFalse,
          reason: file.path,
        );
      }
    },
  );
  test('shell screens and Pulse panels are supplied by modules', () {
    final shell = File('lib/main_screen.dart').readAsStringSync();
    for (final forbidden in [
      'package:life_os/features/',
      'PulseScreen(',
      'TasksScreen(',
      'ProjectsScreen(',
      'ResourcesScreen(',
      'openTaskInEditor',
      'itemCount = 4',
      'static const items',
    ]) {
      expect(shell.contains(forbidden), isFalse, reason: forbidden);
    }
    expect(shell.contains('PluginScreenDeck'), isTrue);
    final pulse = File(
      'lib/features/lifegraph/presentation/pulse_screen.dart',
    ).readAsStringSync();
    for (final forbidden in [
      'features/habits/',
      'HabitsViewModel',
      'TodaysHabitsPanel(',
      'HabitsCalendarPanel(',
    ]) {
      expect(pulse.contains(forbidden), isFalse, reason: forbidden);
    }
    expect(pulse.contains('PluginPanelSlot'), isTrue);
  });
  test(
    'tasks plugin owns state, work log lifetimes and graph registrations',
    () {
      final root = File('lib/app/dependency_container.dart').readAsStringSync();
      expect(root.contains('tasksViewModel.initialize()'), isFalse);
      expect(root.contains('tasksViewModel.dispose'), isFalse);
      expect(root.contains('TasksViewModel('), isFalse);
      expect(root.contains('GetTasksWithProjectsUseCase('), isFalse);
      expect(root.contains('...tasksPlugin.plugins'), isTrue);
      final builtinGraph = File(
        'lib/app/plugins/life_graph_modules.dart',
      ).readAsStringSync();
      expect(builtinGraph.contains('tasks.graph'), isFalse);
      final builtinUi = File(
        'lib/app/plugins/application_ui_modules.dart',
      ).readAsStringSync();
      expect(builtinUi.contains('TasksViewModel'), isFalse);
      expect(builtinUi.contains('tasksScreenModule'), isFalse);
      for (final file in Directory(
        'packages/tasks_plugin/lib/src',
      ).listSync().whereType<File>()) {
        if (file.path.endsWith('tasks_plugin.dart') ||
            file.path.endsWith('work_logs_view_model.dart')) {
          continue;
        }
        final source = file.readAsStringSync();
        expect(source.contains('package:flutter/'), isFalse, reason: file.path);
        expect(source.contains('package:life_os/'), isFalse, reason: file.path);
        expect(source.contains('package:drift/'), isFalse, reason: file.path);
      }
    },
  );
  test('habits lifecycle and logic are owned by the plugin package', () {
    final root = File('lib/app/dependency_container.dart').readAsStringSync();
    expect(root.contains('HabitsViewModel(habitsRepository)'), isFalse);
    expect(root.contains('habitsViewModel.initialize()'), isFalse);
    expect(root.contains('habitsViewModel.dispose'), isFalse);
    expect(root.contains('...habitsPlugin.plugins'), isTrue);
    for (final file in [
      'packages/habits_plugin/lib/habits_logic.dart',
      'packages/habits_plugin/lib/src/habits_state.dart',
      'packages/habits_plugin/lib/src/habits_view_model.dart',
    ]) {
      final source = File(file).readAsStringSync();
      expect(source.contains('package:flutter/'), isFalse, reason: file);
      expect(source.contains('/data/'), isFalse, reason: file);
    }
    final adapter = File(
      'lib/features/habits/data/habits_repository.dart',
    ).readAsStringSync();
    expect(adapter.contains('implements HabitsApi'), isTrue);
    final uiComposition = File(
      'lib/app/plugins/application_ui_modules.dart',
    ).readAsStringSync();
    expect(uiComposition.contains('HabitsViewModel'), isFalse);
  });
  test(
    'project consumers use the public API and the plugin owns its model lifetime',
    () {
      for (final file in [
        'packages/tasks_plugin/lib/src/tasks_view_model.dart',
        'packages/tasks_plugin/lib/src/get_tasks_with_projects_use_case.dart',
        'packages/lifegraph_plugin/lib/src/pulse_screen_view_model.dart',
        'lib/core/ui/hierarchy/build_hierarchy_tree.dart',
      ]) {
        final source = File(file).readAsStringSync();
        expect(
          source.contains('features/projects/domain/'),
          isFalse,
          reason: file,
        );
        expect(source.contains('package:projects_api/'), isTrue, reason: file);
      }
      final root = File('lib/app/dependency_container.dart').readAsStringSync();
      expect(root.contains('projectViewModel.initialize()'), isFalse);
      expect(root.contains('projectViewModel.dispose'), isFalse);
      expect(root.contains('...projectsPlugin.plugins'), isTrue);
      for (final file in Directory(
        'packages/projects_plugin/lib/src',
      ).listSync().whereType<File>()) {
        if (file.path.endsWith('projects_plugin.dart')) continue;
        expect(
          file.readAsStringSync().contains('package:flutter/'),
          isFalse,
          reason: file.path,
        );
      }
    },
  );
  test(
    'graph lifecycle and persistence use public ports outside the composition root',
    () {
      final root = File('lib/app/dependency_container.dart').readAsStringSync();
      for (final forbidden in [
        'PulseScreenViewModel(',
        'ResourcesViewModel(',
        'GraphBuilder(',
        'pulseScreenViewModel.initialize()',
        'pulseScreenViewModel.dispose',
        'pulseScreenViewModel.closeGraphs',
        'resourcesViewModel.dispose',
      ]) {
        expect(root.contains(forbidden), isFalse, reason: forbidden);
      }
      expect(root.contains('...lifeGraphPlugin.plugins'), isTrue);
      expect(root.contains('...resourcesPlugin.plugins'), isTrue);
      final positions = File(
        'lib/features/lifegraph/data/graph_positions_repository.dart',
      ).readAsStringSync();
      expect(positions.contains('implements GraphPositionsStore'), isTrue);
      expect(positions.contains('dart:ui'), isFalse);
      expect(positions.contains('Offset'), isFalse);
      for (final file in [
        'packages/lifegraph_plugin/lib/src/graph_builder.dart',
        'packages/lifegraph_plugin/lib/src/graph_node.dart',
        'packages/notes_api/lib/src/canvas_note.dart',
      ]) {
        expect(
          File(file).readAsStringSync().contains('package:flutter/'),
          isFalse,
          reason: file,
        );
      }
    },
  );
  test(
    'resource state has no hierarchy widgets or concrete storage dependency',
    () {
      final source = File(
        'packages/resources_plugin/lib/src/resources_view_model.dart',
      ).readAsStringSync();
      for (final forbidden in [
        'HierarchyNode',
        'buildVaultHierarchy',
        'ObsidianVault',
        'GraphNotesRepository',
        'shared_preferences',
      ]) {
        expect(source.contains(forbidden), isFalse, reason: forbidden);
      }
      final uiComposition = File(
        'lib/app/plugins/application_ui_modules.dart',
      ).readAsStringSync();
      expect(uiComposition.contains('features/'), isFalse);
    },
  );
}
