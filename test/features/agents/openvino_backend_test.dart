import 'dart:io';
import 'package:agent_bridge/local_assistant.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final python = Platform.environment['ASSISTANT_TEST_PYTHON'];
  group(
    'real stdio worker',
    () {
      late Directory temporary;
      late AssistantSettings settings;
      setUp(() async {
        temporary = await Directory.systemTemp.createTemp('assistant_test_');
        await File(
          p.join(temporary.path, 'openvino_model.xml'),
        ).writeAsString('test only');
        settings = AssistantSettings(
          pythonExecutable: python!,
          modelDirectory: temporary.path,
        );
      });
      tearDown(() => temporary.delete(recursive: true));
      test('starts, preserves Unicode and terminates the child', () async {
        final backend = OpenVinoProcessBackend(
          settings: settings,
          workerSource: '''
import json, sys
print(json.dumps({"type":"ready","device":"NPU","model":"fake"}),flush=True)
for line in sys.stdin:
    value=json.loads(line)
    print(json.dumps({"id":value["id"],"text":value["messages"][-1]["content"]},ensure_ascii=False),flush=True)
''',
        );
        addTearDown(backend.close);
        expect((await backend.start()).device, 'NPU');
        expect(
          await backend.generate([
            {'role': 'system', 'content': 'System'},
            {'role': 'user', 'content': 'Привет'},
          ], turnStart: 1),
          'Привет',
        );
        await backend.close();
        await expectLater(
          backend.generate([], turnStart: 1),
          throwsA(isA<AssistantFailure>()),
        );
      });
      test(
        'reports startup errors and never falls back to another device',
        () async {
          final backend = OpenVinoProcessBackend(
            settings: settings,
            workerSource:
                'import json; print(json.dumps({"type":"startup_error","code":"device_unavailable"}),flush=True)',
          );
          addTearDown(backend.close);
          await expectLater(
            backend.start(),
            throwsA(
              isA<AssistantFailure>().having(
                (e) => e.message,
                'message',
                contains('устройство'),
              ),
            ),
          );
        },
      );
      test('cancellation interrupts a blocked generation', () async {
        final backend = OpenVinoProcessBackend(
          settings: settings,
          workerSource: '''
import json, sys, time
print(json.dumps({"type":"ready","device":"NPU","model":"fake"}),flush=True)
for line in sys.stdin:
    time.sleep(60)
''',
        );
        addTearDown(backend.close);
        await backend.start();
        final generation = backend.generate([
          {'role': 'system', 'content': 's'},
          {'role': 'user', 'content': 'u'},
        ], turnStart: 1);
        final failure = expectLater(
          generation,
          throwsA(isA<AssistantFailure>()),
        );
        await backend.close();
        await failure;
      });
      test(
        'close terminates the interpreter behind the Windows venv launcher',
        () async {
          final backend = OpenVinoProcessBackend(
            settings: settings,
            workerSource: '''
import json, os, sys
from pathlib import Path
Path(sys.argv[sys.argv.index('--model')+1], 'worker.pid').write_text(str(os.getpid()))
print(json.dumps({"type":"ready","device":"NPU","model":"fake"}),flush=True)
for line in sys.stdin:
    pass
''',
          );
          addTearDown(backend.close);
          await backend.start();
          final pid = (await File(
            p.join(temporary.path, 'worker.pid'),
          ).readAsString()).trim();
          await backend.close();
          final processes = await Process.run('tasklist.exe', [
            '/FI',
            'PID eq $pid',
            '/FO',
            'CSV',
            '/NH',
          ]);
          expect(processes.stdout.toString(), isNot(contains('"$pid"')));
        },
        skip: !Platform.isWindows,
      );
      test(
        'startup timeout and malformed protocol clean up correctly',
        () async {
          for (final source in [
            'import time; time.sleep(60)',
            'print("not json",flush=True)',
          ]) {
            final backend = OpenVinoProcessBackend(
              settings: settings,
              workerSource: source,
              startupTimeout: const Duration(milliseconds: 250),
            );
            await expectLater(
              backend.start(),
              throwsA(isA<AssistantFailure>()),
            );
            await backend.close();
          }
        },
      );
    },
    skip: python == null
        ? 'Set ASSISTANT_TEST_PYTHON to enable process integration tests'
        : false,
  );

  test('missing model is actionable and close is safe before start', () async {
    final backend = OpenVinoProcessBackend(
      settings: const AssistantSettings(
        modelDirectory: 'missing-model-for-test',
      ),
      workerSource: 'unused',
    );
    await expectLater(
      backend.start(),
      throwsA(
        isA<AssistantFailure>().having(
          (e) => e.message,
          'message',
          contains('Модель не найдена'),
        ),
      ),
    );
    await backend.close();
    await backend.close();
    final unused = OpenVinoProcessBackend(
      settings: const AssistantSettings(),
      workerSource: 'unused',
    );
    await unused.close();
  });
}
