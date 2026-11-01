import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pure packages and Telegram cannot depend on app internals', () {
    const forbidden = {
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
        'package:life_os/',
        'package:tasks_api/',
        'package:notes_api/',
        'package:telegram_plugin/',
        'package:obsidian_plugin/',
      ],
      'tasks_api': [
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
      'lib/features/lifegraph/domain/graph_builder.dart',
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
      'lib/features/lifegraph/presentation/life_graph_view_model.dart',
      'lib/features/lifegraph/presentation/pulse_screen_view_model.dart',
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
      'lib/features/lifegraph/presentation/life_graph_view_model.dart',
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
}
