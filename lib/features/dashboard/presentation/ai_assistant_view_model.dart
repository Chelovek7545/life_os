import 'dart:async';
import 'dart:convert';

import 'package:flutter_gemma/core/api/flutter_gemma.dart';
import 'package:flutter_gemma/core/message.dart';
import 'package:flutter_gemma/core/model.dart';
import 'package:life_os/core/ai/ai_service.dart';
import 'package:rxdart/rxdart.dart';

class AiAssistantState {
  final List<Message> messages;
  AiAssistantState({required this.messages});
}

class ModelInstallOptions {
  final ModelType modelType;
  final ModelFileType fileType;
  final String source;
  final bool fromAsset;
  final String? description;

  const ModelInstallOptions({
    required this.modelType,
    required this.fileType,
    required this.source,
    this.fromAsset = true,
    this.description,
  });
}

class ModelInstallState {
  final bool installing;
  final double progress;
  final String status;
  final bool ready;

  const ModelInstallState({
    this.installing = false,
    this.progress = 0.0,
    this.status = 'Tap below to install the model',
    this.ready = false,
  });

  ModelInstallState copyWith({
    bool? installing,
    double? progress,
    String? status,
    bool? ready,
  }) {
    return ModelInstallState(
      installing: installing ?? this.installing,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      ready: ready ?? this.ready,
    );
  }
}

class AIAssistantViewModel {
  final AIService _ai;

  AIAssistantViewModel(this._ai) {}

  final BehaviorSubject<AiAssistantState> _StateController =
      BehaviorSubject<AiAssistantState>.seeded(AiAssistantState(messages: []));
  //StreamSubscription<String?>? _subscription;

  final PublishSubject<String> _messageTextController =
      PublishSubject<String>();
  Stream<String> get messageTextStream => _messageTextController.stream;

  Stream<AiAssistantState> get state => _StateController.stream;

  //VoiceStatus _voiceStatus = VoiceStatus.idle;
  bool _generating = false;
  final List<Message> messages = [];

  // InputMode get mode => _mode;
  //VoiceStatus get voiceStatus => _voiceStatus;
  bool get generating => _generating;

  final BehaviorSubject<ModelInstallState> _installStateController =
      BehaviorSubject<ModelInstallState>.seeded(const ModelInstallState());
  Stream<ModelInstallState> get installState => _installStateController.stream;
  ModelInstallState get installStateSnapshot => _installStateController.value;
  bool get modelInstalling => installStateSnapshot.installing;
  double get installProgress => installStateSnapshot.progress;
  String get installStatus => installStateSnapshot.status;
  bool get modelReady => installStateSnapshot.ready;

  //Установка модели
  Future<void> installModel({required ModelInstallOptions options}) async {
    if (installStateSnapshot.installing) return;

    _installStateController.add(
      const ModelInstallState(
        installing: true,
        progress: 0.0,
        status: 'Installing model…',
        ready: false,
      ),
    );

    try {
      final installer = FlutterGemma.installModel(
        modelType: options.modelType,
        fileType: options.fileType,
      );

      if (options.fromAsset) {
        installer.fromAsset(options.source);
      } else {
        installer.fromFile(options.source);
      }

      installer.withProgress((progress) {
        final percent = progress is num
            ? progress.toDouble()
            : double.tryParse(progress.toString()) ?? 0.0;
        _installStateController.add(
          ModelInstallState(
            installing: true,
            progress: percent / 100.0,
            status: 'Installing… ${percent.toStringAsFixed(0)}%',
            ready: false,
          ),
        );
      });

      await installer.install();

      _installStateController.add(
        const ModelInstallState(
          installing: false,
          progress: 1.0,
          status: 'Ready',
          ready: true,
        ),
      );
      
      
      await _ai.initialize();


    } catch (e) {
      _installStateController.add(
        ModelInstallState(
          installing: false,
          progress: 0.0,
          status: 'Error: $e',
          ready: false,
        ),
      );
      rethrow;
    }
  }

  // ── Текстовый / общий ввод ────────────────────────────────────────────────
  Future<void> sendMessage(String text) async {
    messages.add(Message(text: text, isUser: true));
    _generating = true;
    _StateController.add(AiAssistantState(messages: messages));

    messages.add(Message(text: '', isUser: false));
    _StateController.add(AiAssistantState(messages: messages));

    //На случай если нужна одинаковая минимальная разница во времени между токенами
    // final smoothedStream = _ai.sendMessage(text).asyncExpand(
    //       (token) => Stream.value(token).delay(const Duration(milliseconds: 300)),
    //     );
    await _generateResponse(_ai.sendMessage(text));

    _generating = false;
    _StateController.add(AiAssistantState(messages: messages));
  }

  Future<void> _generateResponse(Stream<String> tokenStream) async {
    final buffer = StringBuffer();

    //Рабочая задержка
    final pending = StringBuffer();
    Timer? flushTimer;

    flushTimer = Timer.periodic(const Duration(milliseconds: 10), (_) {
      if (pending.isNotEmpty) {
        _messageTextController.add(pending.toString());
        pending.clear();
      }
    });

    await for (final token in tokenStream) {
      if (token.startsWith('__FUNCTION_CALL__:')) {
        print(token);
        await _handleFunctionCall(token);
      } else {
        buffer.write(token);
        pending.write(token);
      }
    }

    flushTimer.cancel();

    if (pending.isNotEmpty) {
      _messageTextController.add(pending.toString());
    }

    if (messages.isNotEmpty && !messages.last.isUser) {
      messages[messages.length - 1] = Message(text: buffer.toString(), isUser: false);
    }
  }

  // ── Обработка function calls ──────────────────────────────────────────────
  Future<void> _handleFunctionCall(String raw) async {
    final parts = raw.split(':');
    final name = parts[1];
    final args = jsonDecode(parts.sublist(2).join(':')) as Map<String, dynamic>;

    switch (name) {
      case 'create_task':
        //TO DO: Добавить создание задачи, её эмбединг
        // messages.add(ChatMessage(message: Message(text: raw, isUser: false)));
        // // await _embeddingService
        // //     .embedTask(await _taskRepo.createTask(title: "untitled"));
        // _taskRepo.createTask(title: args['title'] as String? ?? 'Untitled');
        // messages.add(
        //   ChatMessage(text: '✅ Задача  создана', role: MessageRole.system),
        // );
      case 'list_tasks':
        // final filter = args['filter'] as String? ?? 'all';
        // final tasks;
        // switch (filter) {
        //   case 'all':
        //     tasks = await _taskRepo.getAllTasks();
        //   case 'today':
        //     tasks = await _taskRepo.getTasksDueBefore(DateTime.now());
        //   default:
        //     tasks = await _taskRepo.getAllTasks();
        // }

        // messages.add(
        //   ChatMessage(text: tasks.toString(), role: MessageRole.system),
        // );
      case 'complete_task':
        // messages.add(
        //   ChatMessage(text: '✅ Задача выполнена', role: MessageRole.system),
        // );
        print('complete task');
    }
    _StateController.add(AiAssistantState(messages: messages));
  }

  void dispose() {
    _StateController.close();
    _messageTextController.close();
    _installStateController.close();
    _ai.dispose();
  }
}
