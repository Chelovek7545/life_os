import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pure packages and Telegram cannot depend on app internals', () {
    const forbidden = {
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
