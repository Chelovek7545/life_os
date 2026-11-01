import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pure packages and Telegram cannot depend on app internals', () {
    const forbidden = {
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
