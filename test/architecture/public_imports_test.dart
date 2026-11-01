import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

String sourcePath(String nativePath) =>
    p.posix.joinAll(p.split(p.relative(nativePath)));

String? resolveImport(String source, String uri) {
  final parsed = Uri.parse(uri);
  if (parsed.scheme == 'dart') return null;
  if (parsed.scheme == 'package') {
    final segments = p.posix.split(parsed.path);
    if (segments.first == 'life_os') {
      return p.posix.normalize(p.posix.joinAll(['lib', ...segments.skip(1)]));
    }
    return p.posix.normalize(
      p.posix.joinAll(['packages', segments.first, 'lib', ...segments.skip(1)]),
    );
  }
  if (parsed.hasScheme) return null;
  return p.posix.normalize(p.posix.join(p.posix.dirname(source), parsed.path));
}

Iterable<String> directives(String source) sync* {
  final declarations = RegExp(
    r'^\s*(?:import|export)\s+([^;]+);',
    multiLine: true,
  );
  final strings = RegExp('''['"]([^'"]+)['"]''');
  for (final declaration in declarations.allMatches(source)) {
    for (final uri in strings.allMatches(declaration[1]!)) {
      yield uri[1]!;
    }
  }
}

Iterable<File> sources() sync* {
  for (final folder in [
    'lib',
    'test',
    'packages',
    'tool',
    'bin',
    'integration_test',
  ]) {
    final directory = Directory(folder);
    if (!directory.existsSync()) continue;
    yield* directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => p.extension(file.path) == '.dart');
  }
}

void main() {
  final retired =
      (jsonDecode(
                File(
                  p.join('test', 'architecture', 'retired_paths.json'),
                ).readAsStringSync(),
              )
              as Map<String, dynamic>)
          .keys
          .toSet();

  test(
    'retired compatibility files cannot return through direct or relative imports',
    () {
      final failures = <String>[];
      for (final old in retired) {
        if (File(p.joinAll(p.posix.split(old))).existsSync()) {
          failures.add('Compatibility file restored: $old');
        }
      }
      for (final file in sources()) {
        final source = sourcePath(file.path);
        for (final uri in directives(file.readAsStringSync())) {
          if (retired.contains(resolveImport(source, uri))) {
            failures.add('$source imports retired $uri');
          }
        }
      }
      expect(failures, isEmpty);
    },
  );

  test(
    'handwritten consumers use public entries rather than another package src directory',
    () {
      final failures = <String>[];
      for (final file in sources()) {
        if (['.g.dart', '.mocks.dart'].contains(p.extension(file.path, 2))) {
          continue;
        }
        final source = sourcePath(file.path);
        final segments = p.posix.split(source);
        final owner = segments.length > 1 && segments.first == 'packages'
            ? segments[1]
            : 'life_os';
        for (final uri in directives(file.readAsStringSync())) {
          final target = resolveImport(source, uri);
          if (target == null) continue;
          final parts = p.posix.split(target);
          if (parts.length > 3 &&
              parts[0] == 'packages' &&
              parts[2] == 'lib' &&
              parts[3] == 'src' &&
              parts[1] != owner) {
            failures.add('$source bypasses public API: $uri');
          }
        }
      }
      expect(failures, isEmpty);
    },
  );

  test(
    'import checks normalize aliases, parent segments and conditional alternatives',
    () {
      const source = 'lib/features/tasks/presentation/tasks_screen.dart';
      expect(
        resolveImport(source, 'package:life_os/core/di.dart'),
        'lib/core/di.dart',
      );
      expect(
        resolveImport(source, '../../../core/./di.dart'),
        'lib/core/di.dart',
      );
      expect(
        resolveImport(source, 'package:tasks_plugin/src/tasks_view_model.dart'),
        'packages/tasks_plugin/lib/src/tasks_view_model.dart',
      );
      expect(
        resolveImport(
          source,
          '../../../../packages/tasks_plugin/lib/src/tasks_view_model.dart',
        ),
        'packages/tasks_plugin/lib/src/tasks_view_model.dart',
      );
      final code =
          "import 'first.dart' if (dart.library.io) 'second.dart' as sample;";
      expect(directives(code), ['first.dart', 'second.dart']);
    },
  );
}
