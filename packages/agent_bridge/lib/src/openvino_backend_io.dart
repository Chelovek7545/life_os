import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../task_tools.dart';
import 'assistant_models.dart';

class OpenVinoProcessBackend implements AssistantBackend {
  OpenVinoProcessBackend({
    required this.settings,
    required this.workerSource,
    this.startupTimeout = const Duration(minutes: 10),
    this.replyTimeout = const Duration(minutes: 3),
  }) {
    unawaited(
      _ready.future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }
  final AssistantSettings settings;
  final String workerSource;
  final Duration startupTimeout;
  final Duration replyTimeout;
  Process? _process;
  Directory? _temporary;
  final _ready = Completer<AssistantBackendInfo>();
  final _pending = <int, Completer<String>>{};
  final _subscriptions = <StreamSubscription<Object?>>[];
  Future<AssistantBackendInfo>? _starting;
  Future<void>? _closing;
  bool _closed = false;
  bool _exited = false;
  int _serial = 0;
  @override
  Future<AssistantBackendInfo> start() => _starting ??= _start();
  Future<AssistantBackendInfo> _start() async {
    // Install a handler before spawning: cancellation can arrive during startup.
    final ready = _ready.future;
    unawaited(ready.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    try {
      if (_closed) throw const AssistantFailure('Модель остановлена.');
      if (!settings.isValid) {
        throw const AssistantFailure(
          'Проверьте настройки Python, модели и устройства.',
        );
      }
      final model = Directory(p.absolute(settings.modelDirectory));
      if (!await File(p.join(model.path, 'openvino_model.xml')).exists()) {
        throw const AssistantFailure(
          'Модель не найдена: укажите папку с openvino_model.xml в настройках чата.',
        );
      }
      if (_closed) throw const AssistantFailure('Модель остановлена.');
      final temporary = await Directory.systemTemp.createTemp(
        'life_os_openvino_',
      );
      _temporary = temporary;
      final script = File(p.join(temporary.path, 'worker.py'));
      await script.writeAsString(workerSource, flush: true);
      if (_closed) throw const AssistantFailure('Модель остановлена.');
      final configuredPython = settings.pythonExecutable.trim();
      final executable = p.split(configuredPython).length > 1
          ? p.absolute(configuredPython)
          : configuredPython;
      final process = await Process.start(
        executable,
        ['-u', script.path, '--model', model.path, '--device', settings.device],
        runInShell: false,
        environment: {
          'PYTHONIOENCODING': 'utf-8',
          'HF_HUB_OFFLINE': '1',
          'TRANSFORMERS_OFFLINE': '1',
        },
      );
      _process = process;
      if (_closed) {
        await _terminate(process);
        throw const AssistantFailure('Модель остановлена.');
      }
      var bytes = 0;
      final output = process.stdout
          .map((chunk) {
            bytes += chunk.length;
            if (bytes > 262144) {
              throw const AssistantFailure(
                'Ответ модели превысил допустимый размер.',
              );
            }
            return chunk;
          })
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      _subscriptions.add(
        output.listen(
          (line) {
            bytes = 0;
            _receive(line);
          },
          onError: (Object _) => _fail(
            const AssistantFailure('Ошибка протокола локальной модели.'),
          ),
        ),
      );
      // Drain diagnostics without copying prompts or tracebacks into the chat.
      _subscriptions.add(process.stderr.listen((_) {}));
      unawaited(
        process.exitCode.then((_) {
          _exited = true;
          _fail(
            const AssistantFailure(
              'Процесс модели завершился. Проверьте Python, OpenVINO и драйвер устройства.',
            ),
          );
        }),
      );
      return await ready.timeout(
        startupTimeout,
        onTimeout: () => throw const AssistantFailure(
          'Загрузка модели заняла слишком много времени. Проверьте драйвер NPU или выберите CPU.',
        ),
      );
    } on AssistantFailure {
      rethrow;
    } on ProcessException {
      throw const AssistantFailure(
        'Не удалось запустить Python. Укажите полный путь к python.exe из окружения OpenVINO.',
      );
    } catch (_) {
      throw const AssistantFailure(
        'Не удалось загрузить локальную модель. Проверьте папку модели и права доступа.',
      );
    }
  }

  void _receive(String line) {
    if (_closed) return;
    try {
      final decoded = jsonDecode(line);
      if (decoded is! Map<String, dynamic>) return;
      if (decoded['type'] == 'ready' && !_ready.isCompleted) {
        _ready.complete(
          AssistantBackendInfo(
            device: decoded['device'] as String,
            model: decoded['model'] as String,
          ),
        );
      } else if (decoded['type'] == 'startup_error') {
        _fail(AssistantFailure(_failure(decoded['code'])));
      } else {
        final completion = _pending.remove(decoded['id']);
        if (completion == null) return;
        if (decoded['text'] is String) {
          completion.complete(decoded['text'] as String);
        } else {
          completion.completeError(AssistantFailure(_failure(decoded['code'])));
        }
      }
    } catch (_) {
      _fail(const AssistantFailure('Ошибка протокола локальной модели.'));
    }
  }

  void _fail(AssistantFailure error) {
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final completion in _pending.values) {
      completion.completeError(error);
    }
    _pending.clear();
  }

  @override
  Future<String> generate(
    List<Map<String, String>> messages, {
    required int turnStart,
  }) async {
    await start();
    if (_closed) throw const AssistantFailure('Модель остановлена.');
    final id = ++_serial;
    final completion = Completer<String>();
    _pending[id] = completion;
    final response = completion.future;
    unawaited(
      response.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      _process!.stdin.writeln(
        jsonEncode({
          'id': id,
          'messages': messages,
          'turn_start': turnStart,
          'tools': TaskAgentTools.definitions
              .map(
                (tool) => {
                  'type': 'function',
                  'function': {
                    'name': tool['name'],
                    'description': tool['description'],
                    'parameters': tool['inputSchema'],
                  },
                },
              )
              .toList(),
        }),
      );
      await _process!.stdin.flush();
      return await response.timeout(
        replyTimeout,
        onTimeout: () => throw const AssistantFailure(
          'Модель не ответила вовремя. Сократите запрос или выберите другое устройство.',
        ),
      );
    } finally {
      _pending.remove(id);
    }
  }

  @override
  Future<void> close() => _closing ??= () async {
    _closed = true;
    _fail(const AssistantFailure('Модель остановлена.'));
    var process = _process;
    if (process != null) {
      await _terminate(process);
    }
    try {
      await _starting;
    } catch (_) {}
    // A spawn may have finished after close began.
    process = _process;
    if (process != null && !_exited) {
      await _terminate(process);
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    final temporary = _temporary;
    if (temporary != null && await temporary.exists()) {
      await temporary.delete(recursive: true);
    }
  }();

  Future<void> _terminate(Process process) async {
    if (!_exited && Platform.isWindows) {
      // A Windows venv launcher creates a child interpreter. Stop the owned tree.
      try {
        await Process.run('taskkill.exe', [
          '/PID',
          '${process.pid}',
          '/T',
          '/F',
        ]);
      } on ProcessException {
        process.kill();
      }
    } else if (!_exited) {
      process.kill();
    }
    await process.exitCode;
    _exited = true;
  }
}

String _failure(Object? code) => switch (code) {
  'missing_dependencies' =>
    'В выбранном Python нет OpenVINO GenAI. Выполните установку по инструкции.',
  'device_unavailable' =>
    'Выбранное устройство недоступно. Проверьте драйвер NPU или выберите CPU/GPU в настройках.',
  'model_missing' =>
    'Не найдены файлы OpenVINO-модели. Проверьте выбранную папку.',
  'context_too_long' =>
    'Запрос не помещается в контекст модели. Сократите его или начните новый диалог.',
  'invalid_request' => 'Некорректный запрос к локальной модели.',
  _ =>
    'Ошибка OpenVINO. Проверьте совместимость модели и устройства; можно выбрать CPU в настройках.',
};
